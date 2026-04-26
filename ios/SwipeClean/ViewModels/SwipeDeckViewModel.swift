//
//  SwipeDeckViewModel.swift
//  SwipeClean
//

import Foundation
import Observation
import UIKit
import os.log

@Observable
final class SwipeDeckViewModel {

    struct Card: Identifiable {
        let id: String
        let asset: Asset
        var thumbnail: UIImage?
        var analysis: ClaudeAnalysis?
        var isLoadingAnalysis: Bool = false
    }

    // MARK: - State

    var queue: [Card] = []
    var pendingDeletions: [Asset] = []
    var swipeCount: Int = 0
    var isLoading: Bool = false
    var errorMessage: String?
    var checkpointReached: Bool = false      // triggers the batch-delete confirmation sheet

    let checkpointEvery: Int = 50

    // MARK: - Dependencies

    private let photoLibrary: PhotoLibraryServicing
    private let claude: ClaudeServicing
    private let undoStack: UndoStacking
    private let logger = Logger(subsystem: "app.swipeclean", category: "SwipeDeckViewModel")

    init(
        photoLibrary: PhotoLibraryServicing,
        claude: ClaudeServicing,
        undoStack: UndoStacking = UndoStack()
    ) {
        self.photoLibrary = photoLibrary
        self.claude = claude
        self.undoStack = undoStack
    }

    // MARK: - Loading

    func load(_ assets: [Asset]) async {
        isLoading = true
        defer { isLoading = false }

        queue = assets.map { Card(id: $0.id, asset: $0) }
        logger.info("SwipeDeckViewModel: loaded \(assets.count) assets into deck")

        // Prefetch thumbnails for the first cards so they show instantly
        await prefetchThumbnails(upTo: 5)

        // Start loading analysis for the very first card
        if !queue.isEmpty {
            await loadAnalysis(for: queue[0])
        }
    }

    // MARK: - Swipe actions

    func handleKeep(_ card: Card) async {
        guard let index = queue.firstIndex(where: { $0.id == card.id }) else { return }

        logger.info("SwipeDeckViewModel: keep \(card.asset.id)")

        let removedCard = queue.remove(at: index)

        await undoStack.push { [weak self] in
            guard let self else { return }
            self.queue.insert(removedCard, at: 0)
            self.swipeCount = max(0, self.swipeCount - 1)
        }

        swipeCount += 1
        await advanceDeck()
    }

    func handleDelete(_ card: Card) async {
        guard let index = queue.firstIndex(where: { $0.id == card.id }) else { return }

        logger.info("SwipeDeckViewModel: delete \(card.asset.id)")

        let removedCard = queue.remove(at: index)
        pendingDeletions.append(removedCard.asset)

        await undoStack.push { [weak self] in
            guard let self else { return }
            self.queue.insert(removedCard, at: 0)
            self.pendingDeletions.removeAll { $0.id == removedCard.asset.id }
            self.swipeCount = max(0, self.swipeCount - 1)
        }

        swipeCount += 1

        if swipeCount % checkpointEvery == 0 && !pendingDeletions.isEmpty {
            checkpointReached = true
        }

        await advanceDeck()
    }

    func handleSkip(_ card: Card) async {
        guard let index = queue.firstIndex(where: { $0.id == card.id }) else { return }

        logger.info("SwipeDeckViewModel: skip \(card.asset.id)")

        // Move skipped card to end of queue
        let removedCard = queue.remove(at: index)
        queue.append(removedCard)

        await undoStack.push { [weak self] in
            guard let self else { return }
            if let last = self.queue.popLast() {
                self.queue.insert(last, at: 0)
            }
            self.swipeCount = max(0, self.swipeCount - 1)
        }

        swipeCount += 1
        await advanceDeck()
    }

    func undo() async {
        guard let action = await undoStack.pop() else {
            logger.info("SwipeDeckViewModel: nothing to undo")
            return
        }
        await action()
        logger.info("SwipeDeckViewModel: undo performed")
    }

    func confirmBatchDeletion() async throws {
        let toDelete = pendingDeletions
        guard !toDelete.isEmpty else { return }

        logger.info("SwipeDeckViewModel: confirming batch deletion of \(toDelete.count) assets")
        try await photoLibrary.batchDelete(toDelete)
        pendingDeletions.removeAll()
        checkpointReached = false
        logger.info("SwipeDeckViewModel: batch deletion complete")
    }

    // MARK: - Private helpers

    private func advanceDeck() async {
        // Prefetch thumbnails for next cards as we move through the deck
        await prefetchThumbnails(upTo: 5)

        // Load analysis for the new top card if not already loaded
        if let topCard = queue.first, topCard.analysis == nil, !topCard.isLoadingAnalysis {
            await loadAnalysis(for: topCard)
        }
    }

    private func prefetchThumbnails(upTo count: Int) async {
        let needsThumbnail = queue.prefix(count).filter { $0.thumbnail == nil }
        guard !needsThumbnail.isEmpty else { return }

        await withTaskGroup(of: (String, UIImage?).self) { group in
            for card in needsThumbnail {
                group.addTask { [weak self] in
                    guard let self else { return (card.id, nil) }
                    let image = await self.photoLibrary.fetchThumbnail(
                        for: card.asset,
                        targetSize: CGSize(width: 640, height: 640)
                    )
                    return (card.id, image)
                }
            }

            for await (id, image) in group {
                if let idx = queue.firstIndex(where: { $0.id == id }) {
                    queue[idx].thumbnail = image
                }
            }
        }
    }

    private func loadAnalysis(for card: Card) async {
        guard let idx = queue.firstIndex(where: { $0.id == card.id }) else { return }
        guard queue[idx].analysis == nil, !queue[idx].isLoadingAnalysis else { return }
        guard let thumbnail = queue[idx].thumbnail else { return }

        queue[idx].isLoadingAnalysis = true

        let asset = card.asset
        let albums = await photoLibrary.listAlbums()

        let metadata = AnalyzeMetadata(
            assetType: AssetType(rawValue: asset.type.rawValue) ?? .photo,
            capturedAt: asset.createdAt,
            durationSeconds: asset.durationSeconds,
            byteSize: asset.byteSize,
            visionLabels: [],
            ocrText: nil,
            isScreenshot: asset.isScreenshot,
            hasFaces: false
        )

        do {
            let analysis = try await claude.analyze(
                thumbnail: thumbnail,
                metadata: metadata,
                existingAlbums: albums,
                suggestAlbum: true
            )
            if let finalIdx = queue.firstIndex(where: { $0.id == card.id }) {
                queue[finalIdx].analysis = analysis
                queue[finalIdx].isLoadingAnalysis = false
            }
        } catch {
            logger.error("SwipeDeckViewModel: analysis failed for \(asset.id): \(error)")
            if let finalIdx = queue.firstIndex(where: { $0.id == card.id }) {
                queue[finalIdx].isLoadingAnalysis = false
            }
        }
    }
}

// MARK: - Undo

protocol UndoStacking {
    func push(_ action: @escaping () async -> Void) async
    func pop() async -> (() async -> Void)?
}

actor UndoStack: UndoStacking {
    private var actions: [() async -> Void] = []
    private let maxDepth = 10

    func push(_ action: @escaping () async -> Void) {
        actions.append(action)
        if actions.count > maxDepth {
            actions.removeFirst()
        }
    }

    func pop() async -> (() async -> Void)? {
        actions.popLast()
    }
}
