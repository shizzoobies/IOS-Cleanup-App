//
//  SwipeDeckViewModel.swift
//  SwipeClean
//

import Foundation
import Observation
import UIKit

@Observable
final class SwipeDeckViewModel {

    struct Card: Identifiable {
        let id: String
        let asset: Asset
        var thumbnail: UIImage?
        var analysis: ClaudeAnalysis?
        var isLoadingAnalysis: Bool
    }

    var queue: [Card] = []
    var pendingDeletions: [Asset] = []
    var swipeCount: Int = 0
    var checkpointEvery: Int = 50

    private let photoLibrary: PhotoLibraryServicing
    private let claude: ClaudeServicing
    private let undoStack: UndoStacking

    init(
        photoLibrary: PhotoLibraryServicing,
        claude: ClaudeServicing,
        undoStack: UndoStacking = UndoStack()
    ) {
        self.photoLibrary = photoLibrary
        self.claude = claude
        self.undoStack = undoStack
    }

    func load(_ assets: [Asset]) async {
        // TODO(phase6): create Cards, prefetch thumbnails for the next ~5 cards.
    }

    func handleKeep(_ card: Card) async {
        // TODO(phase6 + phase8): record decision, prompt for album filing.
        swipeCount += 1
    }

    func handleDelete(_ card: Card) async {
        // TODO(phase6): add to pendingDeletions, advance, trigger checkpoint if needed.
        pendingDeletions.append(card.asset)
        swipeCount += 1
    }

    func handleSkip(_ card: Card) async {
        // TODO(phase6).
        swipeCount += 1
    }

    func undo() async {
        // TODO(phase6).
    }

    func confirmBatchDeletion() async throws {
        // TODO(phase6): photoLibrary.batchDelete(pendingDeletions). iOS shows native dialog.
    }
}

// MARK: - Undo

protocol UndoStacking {
    func push(_ action: () async -> Void)
    func pop() async -> (() async -> Void)?
}

final class UndoStack: UndoStacking {
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
