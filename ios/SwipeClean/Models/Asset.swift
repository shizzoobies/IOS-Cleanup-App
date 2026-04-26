//
//  Asset.swift
//  SwipeClean
//
//  In-memory domain model that wraps a PHAsset or a file URL.
//  Asset is intentionally a value type. Persistent state lives in SwiftData models.
//

import Foundation
import Photos

enum AssetSource: Hashable {
    case photoLibrary(localIdentifier: String)
    case file(url: URL)
}

enum AssetType: String, Codable {
    case photo
    case video
    case screenshot
    case document
    case other
}

struct Asset: Identifiable, Hashable {
    let id: String
    let source: AssetSource
    let type: AssetType
    let createdAt: Date?
    let byteSize: Int64
    let dimensions: CGSize?
    let durationSeconds: Double?
    let isScreenshot: Bool

    var displayName: String {
        switch source {
        case .photoLibrary(let id):
            return id
        case .file(let url):
            return url.lastPathComponent
        }
    }
}

extension Asset {
    init(phAsset: PHAsset) {
        let isScreenshot = phAsset.mediaSubtypes.contains(.photoScreenshot)
        let type: AssetType = {
            switch phAsset.mediaType {
            case .video: return .video
            case .image: return isScreenshot ? .screenshot : .photo
            default: return .other
            }
        }()
        let dimensions: CGSize? = (phAsset.pixelWidth > 0 && phAsset.pixelHeight > 0)
            ? CGSize(width: phAsset.pixelWidth, height: phAsset.pixelHeight)
            : nil
        let duration: Double? = phAsset.mediaType == .video ? phAsset.duration : nil

        self.init(
            id: phAsset.localIdentifier,
            source: .photoLibrary(localIdentifier: phAsset.localIdentifier),
            type: type,
            createdAt: phAsset.creationDate,
            byteSize: 0,
            dimensions: dimensions,
            durationSeconds: duration,
            isScreenshot: isScreenshot
        )
    }
}
