//
//  FileAccessService.swift
//  SwipeClean
//
//  Wraps UIDocumentPickerViewController and FileManager for the Files-side flow.
//
//  TODO(phase9): full implementation.
//

import Foundation
import UniformTypeIdentifiers

protocol FileAccessServicing: AnyObject {
    func pickFolder() async throws -> URL
    func enumerateFiles(in folder: URL) async throws -> [Asset]
    func deleteFile(at url: URL) async throws
}

final class FileAccessService: FileAccessServicing {

    func pickFolder() async throws -> URL {
        // TODO(phase9): present UIDocumentPickerViewController with .folder UTType, return security-scoped URL.
        throw NSError(domain: "SwipeClean", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not implemented"])
    }

    func enumerateFiles(in folder: URL) async throws -> [Asset] {
        // TODO(phase9): FileManager.default.enumerator with prefetched keys.
        return []
    }

    func deleteFile(at url: URL) async throws {
        // TODO(phase9): FileManager.default.trashItem (uses iOS trash, recoverable).
    }
}
