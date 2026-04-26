//
//  ClaudeService.swift
//  SwipeClean
//
//  Client for the SwipeClean backend proxy. Handles thumbnail downsampling,
//  face blurring, EXIF stripping, retry, and offline fallback.
//
//  Never contacts api.anthropic.com directly. The proxy holds the API key.
//

import Foundation
import UIKit
import os.log

protocol ClaudeServicing: AnyObject {
    func analyze(
        thumbnail: UIImage,
        metadata: AnalyzeMetadata,
        existingAlbums: [String],
        suggestAlbum: Bool
    ) async throws -> ClaudeAnalysis

    func suggestAlbum(
        summary: String,
        category: AssetCategory,
        existingAlbums: [String]
    ) async throws -> AlbumSuggestionResult
}

struct AnalyzeMetadata: Codable {
    let assetType: AssetType
    let capturedAt: Date?
    let durationSeconds: Double?
    let byteSize: Int64
    let visionLabels: [String]
    let ocrText: String?
    let isScreenshot: Bool
    let hasFaces: Bool

    enum CodingKeys: String, CodingKey {
        case assetType = "asset_type"
        case capturedAt = "captured_at"
        case durationSeconds = "duration_seconds"
        case byteSize = "byte_size"
        case visionLabels = "vision_labels"
        case ocrText = "ocr_text"
        case isScreenshot = "is_screenshot"
        case hasFaces = "has_faces"
    }
}

enum ClaudeServiceError: Error {
    case rateLimited(retryAfter: TimeInterval)
    case payloadTooLarge
    case offline
    case invalidResponse
    case server(status: Int, message: String?)
    case preprocessingFailed
}

final class ClaudeService: ClaudeServicing {

    static let productionBaseURL = URL(string: "https://swipeclean-proxy.tgqhg6kf4g.workers.dev")!

    private let baseURL: URL
    private let session: URLSession
    private let tokenStore: TokenStoring
    private let networkMonitor: NetworkMonitoring
    private let preprocessor: ImagePreprocessing
    private let faceDetector: FaceDetecting
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let logger = Logger(subsystem: "app.swipeclean", category: "ClaudeService")

    private let maxAttempts: Int
    private let baseBackoffSeconds: Double
    private let maxThumbnailBytes: Int

    init(
        baseURL: URL = ClaudeService.productionBaseURL,
        tokenStore: TokenStoring = TokenStore(),
        networkMonitor: NetworkMonitoring = NetworkMonitor(),
        preprocessor: ImagePreprocessing = ImagePreprocessor(),
        faceDetector: FaceDetecting = FaceDetector(),
        session: URLSession = ClaudeService.makeDefaultSession(),
        maxAttempts: Int = 3,
        baseBackoffSeconds: Double = 0.5,
        maxThumbnailBytes: Int = 512 * 1024
    ) {
        self.baseURL = baseURL
        self.tokenStore = tokenStore
        self.networkMonitor = networkMonitor
        self.preprocessor = preprocessor
        self.faceDetector = faceDetector
        self.session = session
        self.maxAttempts = maxAttempts
        self.baseBackoffSeconds = baseBackoffSeconds
        self.maxThumbnailBytes = maxThumbnailBytes

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    private static func makeDefaultSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = false
        config.httpAdditionalHeaders = [
            "User-Agent": "SwipeClean/0.1 (iOS; CFNetwork)"
        ]
        return URLSession(configuration: config)
    }

    func analyze(
        thumbnail: UIImage,
        metadata: AnalyzeMetadata,
        existingAlbums: [String],
        suggestAlbum: Bool
    ) async throws -> ClaudeAnalysis {
        guard networkMonitor.isReachable else { throw ClaudeServiceError.offline }

        let faceResult = await faceDetector.detect(thumbnail)
        guard let jpegData = preprocessor.prepareForUpload(
            thumbnail,
            faceRegions: faceResult.regions,
            blurFaces: true
        ) else {
            throw ClaudeServiceError.preprocessingFailed
        }
        guard jpegData.count <= maxThumbnailBytes else {
            throw ClaudeServiceError.payloadTooLarge
        }

        let body = AnalyzeRequest(
            thumbnailB64: jpegData.base64EncodedString(),
            metadata: metadata.withFaceFlag(hasFaces: faceResult.count > 0),
            existingAlbums: Array(existingAlbums.prefix(50)),
            options: AnalyzeRequest.Options(
                suggestAlbum: suggestAlbum,
                includeRationale: false
            )
        )

        let request = try makeRequest(path: "/v1/analyze", body: body)
        return try await performWithRetry(request, decode: ClaudeAnalysis.self)
    }

    func suggestAlbum(
        summary: String,
        category: AssetCategory,
        existingAlbums: [String]
    ) async throws -> AlbumSuggestionResult {
        guard networkMonitor.isReachable else { throw ClaudeServiceError.offline }

        let body = AlbumSuggestRequest(
            assetSummary: summary,
            assetCategory: category,
            existingAlbums: Array(existingAlbums.prefix(50))
        )
        let request = try makeRequest(path: "/v1/album_suggest", body: body)
        let response = try await performWithRetry(request, decode: AlbumSuggestResponse.self)
        return AlbumSuggestionResult(
            name: response.suggestedAlbum.name,
            isExisting: response.suggestedAlbum.isExisting,
            confidence: 1.0
        )
    }

    private func makeRequest<Body: Encodable>(path: String, body: Body) throws -> URLRequest {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw ClaudeServiceError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(tokenStore.currentToken())", forHTTPHeaderField: "Authorization")
        request.httpBody = try encoder.encode(body)
        return request
    }

    private func performWithRetry<T: Decodable>(
        _ request: URLRequest,
        decode type: T.Type
    ) async throws -> T {
        var attempt = 0
        var lastError: Error = ClaudeServiceError.invalidResponse

        while attempt < maxAttempts {
            attempt += 1
            do {
                return try await sendOnce(request, decode: type)
            } catch let error as ClaudeServiceError {
                if let retryable = retryableServerError(error) {
                    lastError = retryable
                } else {
                    throw error
                }
            } catch let urlError as URLError {
                if urlError.code == .notConnectedToInternet {
                    throw ClaudeServiceError.offline
                }
                if Self.retryableURLErrorCodes.contains(urlError.code) {
                    lastError = urlError
                } else {
                    throw urlError
                }
            } catch {
                throw error
            }

            if attempt < maxAttempts {
                let backoff = baseBackoffSeconds * pow(2.0, Double(attempt - 1))
                try? await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
            }
        }
        throw lastError
    }

    private func retryableServerError(_ error: ClaudeServiceError) -> ClaudeServiceError? {
        if case .server(let status, _) = error, (500..<600).contains(status) {
            return error
        }
        return nil
    }

    private static let retryableURLErrorCodes: Set<URLError.Code> = [
        .timedOut,
        .networkConnectionLost,
        .cannotConnectToHost,
        .cannotFindHost,
        .dnsLookupFailed,
        .resourceUnavailable
    ]

    private func sendOnce<T: Decodable>(
        _ request: URLRequest,
        decode type: T.Type
    ) async throws -> T {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ClaudeServiceError.invalidResponse
        }

        switch http.statusCode {
        case 200..<300:
            do {
                return try decoder.decode(type, from: data)
            } catch {
                logger.error("Decoding failed for \(request.url?.path ?? "?", privacy: .public): \(error.localizedDescription, privacy: .public)")
                throw ClaudeServiceError.invalidResponse
            }
        case 413:
            throw ClaudeServiceError.payloadTooLarge
        case 429:
            let retryAfter = parseRetryAfter(data: data, headers: http) ?? 60
            throw ClaudeServiceError.rateLimited(retryAfter: retryAfter)
        default:
            let message = String(data: data, encoding: .utf8)
            logger.error("HTTP \(http.statusCode, privacy: .public) from \(request.url?.path ?? "?", privacy: .public)")
            throw ClaudeServiceError.server(status: http.statusCode, message: message)
        }
    }

    private func parseRetryAfter(data: Data, headers: HTTPURLResponse) -> TimeInterval? {
        if let header = headers.value(forHTTPHeaderField: "Retry-After"),
           let seconds = TimeInterval(header) {
            return seconds
        }
        if let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let seconds = body["retry_after_seconds"] as? Double {
            return seconds
        }
        return nil
    }
}

private extension AnalyzeMetadata {
    func withFaceFlag(hasFaces: Bool) -> AnalyzeMetadata {
        AnalyzeMetadata(
            assetType: assetType,
            capturedAt: capturedAt,
            durationSeconds: durationSeconds,
            byteSize: byteSize,
            visionLabels: visionLabels,
            ocrText: ocrText,
            isScreenshot: isScreenshot,
            hasFaces: hasFaces
        )
    }
}

// MARK: - Wire types

private struct AnalyzeRequest: Encodable {
    let thumbnailB64: String
    let metadata: AnalyzeMetadata
    let existingAlbums: [String]
    let options: Options

    struct Options: Encodable {
        let suggestAlbum: Bool
        let includeRationale: Bool

        enum CodingKeys: String, CodingKey {
            case suggestAlbum = "suggest_album"
            case includeRationale = "include_rationale"
        }
    }

    enum CodingKeys: String, CodingKey {
        case thumbnailB64 = "thumbnail_b64"
        case metadata
        case existingAlbums = "existing_albums"
        case options
    }
}

private struct AlbumSuggestRequest: Encodable {
    let assetSummary: String
    let assetCategory: AssetCategory
    let existingAlbums: [String]

    enum CodingKeys: String, CodingKey {
        case assetSummary = "asset_summary"
        case assetCategory = "asset_category"
        case existingAlbums = "existing_albums"
    }
}

private struct AlbumSuggestResponse: Decodable {
    let suggestedAlbum: SuggestedAlbum

    struct SuggestedAlbum: Decodable {
        let name: String
        let isExisting: Bool
        let rationale: String?

        enum CodingKeys: String, CodingKey {
            case name
            case isExisting = "is_existing"
            case rationale
        }
    }

    enum CodingKeys: String, CodingKey {
        case suggestedAlbum = "suggested_album"
    }
}
