//
//  AssetRepository.swift
//  SwipeClean
//
//  Owns a PHFetchResult and exposes paginated access plus thumbnail loading.
//  Backs view-layer code that needs to scroll a large library without holding
//  every Asset in memory at once.
//

import Foundation
import Photos
import UIKit
import os.log

protocol AssetRepositorying: AnyObject {
    func authorizationStatus() -> PHAuthorizationStatus
    func requestAuthorization() async -> PHAuthorizationStatus
    func reload() async
    func count() async -> Int
    func page(offset: Int, limit: Int) async -> [Asset]
    func thumbnail(for asset: Asset, targetSize: CGSize) async -> UIImage?
}

actor AssetRepository: AssetRepositorying {

    private static let logger = Logger(subsystem: "app.swipeclean", category: "AssetRepository")

    private let imageManager: PHCachingImageManager
    private var fetchResult: PHFetchResult<PHAsset>?

    init() {
        self.imageManager = PHCachingImageManager()
    }

    nonisolated func authorizationStatus() -> PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    func requestAuthorization() async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    func reload() async {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.includeHiddenAssets = false
        let result = PHAsset.fetchAssets(with: options)
        self.fetchResult = result
        Self.logger.log("reload: fetched \(result.count, privacy: .public) assets")
    }

    func count() async -> Int {
        fetchResult?.count ?? 0
    }

    func page(offset: Int, limit: Int) async -> [Asset] {
        guard let fetchResult else { return [] }
        let upperBound = min(offset + limit, fetchResult.count)
        guard offset >= 0, offset < upperBound else { return [] }
        var page: [Asset] = []
        page.reserveCapacity(upperBound - offset)
        for index in offset..<upperBound {
            page.append(Asset(phAsset: fetchResult.object(at: index)))
        }
        return page
    }

    func thumbnail(for asset: Asset, targetSize: CGSize) async -> UIImage? {
        guard case .photoLibrary(let localId) = asset.source else { return nil }
        let identified = PHAsset.fetchAssets(withLocalIdentifiers: [localId], options: nil)
        guard let phAsset = identified.firstObject else { return nil }
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        let manager = imageManager
        return await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
            manager.requestImage(
                for: phAsset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}
