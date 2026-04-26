//
//  FileAccessService.swift
//  SwipeClean
//
//  Wraps UIDocumentPickerViewController and FileManager for the Files-side flow.
//  Uses security-scoped bookmarks for persistent access across launches.
//

import Foundation
import UIKit
import UniformTypeIdentifiers
import os.log

protocol FileAccessServicing: AnyObject {
    func pickFolder() async throws -> URL
    func enumerateFiles(in folder: URL) async throws -> [Asset]
    func deleteFile(at url: URL) async throws
}

enum FileAccessError: LocalizedError {
    case noPresentingController
    case accessDenied(URL)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .noPresentingController: return "Cannot present file picker"
        case .accessDenied(let url):  return "Access denied to \(url.lastPathComponent)"
        case .cancelled:              return "File picker cancelled"
        }
    }
}

final class FileAccessService: NSObject, FileAccessServicing {

    private let logger = Logger(subsystem: "app.swipeclean", category: "FileAccessService")
    private var pickerContinuation: CheckedContinuation<URL, Error>?

    // MARK: - Pick folder

    func pickFolder() async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            self.pickerContinuation = continuation

            DispatchQueue.main.async {
                let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
                picker.allowsMultipleSelection = false
                picker.delegate = self

                guard
                    let scene = UIApplication.shared.connectedScenes
                        .compactMap({ $0 as? UIWindowScene })
                        .first(where: { $0.activationState == .foregroundActive }),
                    let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
                else {
                    continuation.resume(throwing: FileAccessError.noPresentingController)
                    return
                }

                // Present from the topmost view controller
                var presenter = root
                while let presented = presenter.presentedViewController {
                    presenter = presented
                }
                presenter.present(picker, animated: true)
            }
        }
    }

    // MARK: - Enumerate files

    func enumerateFiles(in folder: URL) async throws -> [Asset] {
        guard folder.startAccessingSecurityScopedResource() else {
            throw FileAccessError.accessDenied(folder)
        }
        defer { folder.stopAccessingSecurityScopedResource() }

        let keys: [URLResourceKey] = [
            .fileSizeKey,
            .creationDateKey,
            .contentTypeKey,
            .nameKey,
            .isDirectoryKey
        ]

        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var assets: [Asset] = []

        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: Set(keys))

            // Skip directories
            if values?.isDirectory == true { continue }

            let byteSize = Int64(values?.fileSize ?? 0)
            let createdAt = values?.creationDate
            let contentType = values?.contentType

            let assetType = assetType(for: contentType)

            let asset = Asset(
                id: fileURL.absoluteString,
                source: .file(url: fileURL),
                type: assetType,
                createdAt: createdAt,
                byteSize: byteSize,
                dimensions: nil,
                durationSeconds: nil,
                isScreenshot: false
            )
            assets.append(asset)
        }

        logger.info("FileAccessService: enumerated \(assets.count) files in \(folder.lastPathComponent)")
        return assets
    }

    // MARK: - Delete file

    func deleteFile(at url: URL) async throws {
        guard url.startAccessingSecurityScopedResource() else {
            throw FileAccessError.accessDenied(url)
        }
        defer { url.stopAccessingSecurityScopedResource() }

        var trashURL: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &trashURL)
        logger.info("FileAccessService: trashed \(url.lastPathComponent)")
    }

    // MARK: - Helpers

    private func assetType(for contentType: UTType?) -> AssetType {
        guard let contentType else { return .other }
        if contentType.conforms(to: .image) { return .photo }
        if contentType.conforms(to: .movie) || contentType.conforms(to: .video) { return .video }
        if contentType.conforms(to: .pdf) || contentType.conforms(to: .text) { return .document }
        return .other
    }
}

// MARK: - UIDocumentPickerDelegate

extension FileAccessService: UIDocumentPickerDelegate {

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            pickerContinuation?.resume(throwing: FileAccessError.cancelled)
            pickerContinuation = nil
            return
        }
        pickerContinuation?.resume(returning: url)
        pickerContinuation = nil
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        pickerContinuation?.resume(throwing: FileAccessError.cancelled)
        pickerContinuation = nil
    }
}
