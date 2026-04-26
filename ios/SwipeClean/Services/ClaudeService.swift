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
}

final class ClaudeService: ClaudeServicing {

    private let baseURL: URL
    private let session: URLSession
    private let tokenProvider: () -> String
    private let logger = Logger(subsystem: "app.swipeclean", category: "ClaudeService")

    init(baseURL: URL, tokenProvider: @escaping () -> String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
        self.session = session
    }

    func analyze(
        thumbnail: UIImage,
        metadata: AnalyzeMetadata,
        existingAlbums: [String],
        suggestAlbum: Bool
    ) async throws -> ClaudeAnalysis {
        // TODO(phase4):
        //   1. Downsample thumbnail to max 512px long edge, JPEG q=0.7.
        //   2. If metadata.hasFaces, run face blur via Vision + CIFilter.
        //   3. Strip EXIF.
        //   4. Build request body, POST to /v1/analyze.
        //   5. Decode and return.
        throw ClaudeServiceError.offline
    }

    func suggestAlbum(
        summary: String,
        category: AssetCategory,
        existingAlbums: [String]
    ) async throws -> AlbumSuggestionResult {
        // TODO(phase4): POST /v1/album_suggest.
        throw ClaudeServiceError.offline
    }
}
