//
//  QueueSelectionViewModel.swift
//  SwipeClean
//

import Foundation
import Observation

@Observable
final class QueueSelectionViewModel {

    struct CategorySummary: Identifiable {
        let id: QueueCategory
        let count: Int
        var category: QueueCategory { id }
    }

    var summaries: [CategorySummary] = []
    var isLoading: Bool = false
    var errorMessage: String?

    private let queueBuilder: QueueBuilding

    init(queueBuilder: QueueBuilding) {
        self.queueBuilder = queueBuilder
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            summaries = try await queueBuilder.buildSummaries()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

protocol QueueBuilding {
    func buildSummaries() async throws -> [QueueSelectionViewModel.CategorySummary]
    func buildQueue(for category: QueueCategory) async throws -> [Asset]
}

final class QueueBuilder: QueueBuilding {

    private let photoLibrary: PhotoLibraryServicing
    private let visionPipeline: VisionPipelining

    init(photoLibrary: PhotoLibraryServicing, visionPipeline: VisionPipelining) {
        self.photoLibrary = photoLibrary
        self.visionPipeline = visionPipeline
    }

    func buildSummaries() async throws -> [QueueSelectionViewModel.CategorySummary] {
        // TODO(phase5): full implementation. Run vision pre-pass, group, count.
        return []
    }

    func buildQueue(for category: QueueCategory) async throws -> [Asset] {
        // TODO(phase5).
        return []
    }
}
