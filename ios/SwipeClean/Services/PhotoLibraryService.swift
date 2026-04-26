//
//  PhotoLibraryService.swift
//  SwipeClean
//
//  Wraps PhotoKit. Permission handling, asset enumeration, thumbnail loading,
//  album CRUD, and batch deletion.
//

import Foundation
import Photos
import UIKit
import os.log

protocol PhotoLibraryServicing: AnyObject {
    func requestAuthorization() async -> PHAuthorizationStatus
    func currentAuthorizationStatus() -> PHAuthorizationStatus
    func fetchAllAssets() async -> [Asset]
    func fetchThumbnail(for asset: Asset, targetSize: CGSize) async -> UIImage?
    func fetchFullImage(for asset: Asset) async -> UIImage?
    func listAlbums() async -> [String]
    func createAlbum(named name: String) async throws -> String
    func addAsset(_ asset: Asset, toAlbum name: String) async throws
    func batchDelete(_ assets: [Asset]) async throws
}

final class PhotoLibraryService: PhotoLibraryServicing {

    private static let logger = Logger(subsystem: "app.swipeclean", category: "PhotoLibraryService")
    private let imageManager = PHImageManager.default()

    func requestAuthorization() async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    func currentAuthorizationStatus() -> PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    func fetchAllAssets() async -> [Asset] {
        await Task.detached(priority: .userInitiated) {
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            options.includeHiddenAssets = false
            let result = PHAsset.fetchAssets(with: options)
            var assets: [Asset] = []
            assets.reserveCapacity(result.count)
            result.enumerateObjects { phAsset, _, _ in
                assets.append(Asset(phAsset: phAsset))
            }
            Self.logger.log("fetchAllAssets returned \(assets.count, privacy: .public) assets")
            return assets
        }.value
    }

    func fetchThumbnail(for asset: Asset, targetSize: CGSize) async -> UIImage? {
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

    func fetchFullImage(for asset: Asset) async -> UIImage? {
        guard case .photoLibrary(let localId) = asset.source else { return nil }
        let identified = PHAsset.fetchAssets(withLocalIdentifiers: [localId], options: nil)
        guard let phAsset = identified.firstObject else { return nil }
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .none
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        let manager = imageManager
        return await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
            manager.requestImage(
                for: phAsset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .default,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    func listAlbums() async -> [String] {
        // TODO(phase8): enumerate user albums via PHAssetCollection.
        return []
    }

    func createAlbum(named name: String) async throws -> String {
        // TODO(phase8): PHAssetCollectionChangeRequest.creationRequestForAssetCollection.
        throw NSError(domain: "SwipeClean", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not implemented"])
    }

    func addAsset(_ asset: Asset, toAlbum name: String) async throws {
        // TODO(phase8): PHAssetCollectionChangeRequest with addAssets.
    }

    func batchDelete(_ assets: [Asset]) async throws {
        // TODO(phase6): PHAssetChangeRequest.deleteAssets. iOS shows native confirmation.
    }
}
