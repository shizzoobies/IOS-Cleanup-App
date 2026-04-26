//
//  PhotoLibraryService.swift
//  SwipeClean
//
//  Wraps PhotoKit. Permission handling, asset enumeration, thumbnail loading,
//  album CRUD, and batch deletion.
//
//  TODO(phase1): full implementation.
//

import Foundation
import Photos
import UIKit

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

    func requestAuthorization() async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    func currentAuthorizationStatus() -> PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    func fetchAllAssets() async -> [Asset] {
        // TODO(phase1): implement with PHFetchOptions, paginate as needed.
        return []
    }

    func fetchThumbnail(for asset: Asset, targetSize: CGSize) async -> UIImage? {
        // TODO(phase1): use PHImageManager.requestImage with .opportunistic.
        return nil
    }

    func fetchFullImage(for asset: Asset) async -> UIImage? {
        // TODO(phase7): full-res for inspect mode.
        return nil
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
