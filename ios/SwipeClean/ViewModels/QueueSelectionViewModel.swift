//
//  QueueSelectionViewModel.swift
//  SwipeClean
//

import Foundation
import Observation
import UIKit
import os.log

// MARK: - ViewModel

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

// MARK: - Protocol

protocol QueueBuilding: AnyObject {
    func buildSummaries() async throws -> [QueueSelectionViewModel.CategorySummary]
    func buildQueue(for category: QueueCategory) async throws -> [Asset]
}

// MARK: - QueueBuilder

actor QueueBuilder: QueueBuilding {

    private let photoLibrary: PhotoLibraryServicing
    private let visionPipeline: VisionPipelining
    private let logger = Logger(subsystem: "app.swipeclean", category: "QueueBuilder")

    // In-memory cache keyed by asset.id. Survives for the lifetime of the session.
    private var analysisCache: [String: LocalAnalysis] = [:]
    private var cachedAssets: [Asset] = []

    // Thresholds
    private static let largeFileThresholdBytes: Int64 = 50 * 1_024 * 1_024    // 50 MB
    private static let oldUntouchedThreshold: TimeInterval = 2 * 365 * 24 * 3_600  // 2 years
    private static let minOCRLengthForDocument = 50    // chars
    private static let visionConcurrency = 8           // parallel Vision tasks

    init(photoLibrary: PhotoLibraryServicing, visionPipeline: VisionPipelining) {
        self.photoLibrary = photoLibrary
        self.visionPipeline = visionPipeline
    }

    // MARK: - QueueBuilding

    func buildSummaries() async throws -> [QueueSelectionViewModel.CategorySummary] {
        logger.info("QueueBuilder: fetching assets for Vision pre-pass")

        let assets = await photoLibrary.fetchAllAssets()
        cachedAssets = assets

        await runVisionPrePass(on: assets)

        var summaries: [QueueSelectionViewModel.CategorySummary] = QueueCategory.allCases
            .compactMap { category in
                guard category != .surpriseMe else { return nil }
                let count = assets.filter { categorize($0) == category }.count
                guard count > 0 else { return nil }
                return QueueSelectionViewModel.CategorySummary(id: category, count: count)
            }

        // Surprise Me always appears, count = total assets
        summaries.append(QueueSelectionViewModel.CategorySummary(id: .surpriseMe, count: assets.count))

        logger.info("QueueBuilder: built \(summaries.count) category summaries from \(assets.count) assets")
        return summaries
    }

    func buildQueue(for category: QueueCategory) async throws -> [Asset] {
        let assets: [Asset]
        if cachedAssets.isEmpty {
            assets = await photoLibrary.fetchAllAssets()
            cachedAssets = assets
            await runVisionPrePass(on: assets)
        } else {
            assets = cachedAssets
        }

        switch category {
        case .duplicates:
            return buildDuplicatesQueue(from: assets)
        case .surpriseMe:
            // Weighted shuffle -- surface high-value categories first
            let highValue = assets.filter { categorize($0) != .everythingElse }
            let rest = assets.filter { categorize($0) == .everythingElse }
            return highValue.shuffled() + rest.shuffled()
        default:
            return assets
                .filter { categorize($0) == category }
                .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        }
    }

    // MARK: - Vision pre-pass

    private func runVisionPrePass(on assets: [Asset]) async {
        logger.info("QueueBuilder: starting Vision pre-pass on \(assets.count) assets")

        // Only analyze assets not already in cache
        let uncached = assets.filter { analysisCache[$0.id] == nil }
        guard !uncached.isEmpty else {
            logger.info("QueueBuilder: all assets already cached, skipping Vision pass")
            return
        }

        var results: [(String, LocalAnalysis)] = []

        await withTaskGroup(of: (String, LocalAnalysis?).self) { group in
            var inFlight = 0

            for (index, asset) in uncached.enumerated() {
                // Drain one slot before adding more once we hit the concurrency cap
                if inFlight >= Self.visionConcurrency {
                    if let (id, analysis) = await group.next() {
                        if let a = analysis { results.append((id, a)) }
                        inFlight -= 1
                    }
                }

                let photoLib = self.photoLibrary
                let pipeline = self.visionPipeline

                group.addTask {
                    guard let thumbnail = await photoLib.fetchThumbnail(
                        for: asset,
                        targetSize: CGSize(width: 256, height: 256)
                    ) else { return (asset.id, nil) }
                    let analysis = await pipeline.analyze(asset, image: thumbnail)
                    return (asset.id, analysis)
                }
                inFlight += 1

                // Log progress every 100 assets
                if index % 100 == 0 {
                    self.logger.info("QueueBuilder: Vision pre-pass \(index)/\(uncached.count)")
                }
            }

            // Drain remaining tasks
            for await (id, analysis) in group {
                if let a = analysis { results.append((id, a)) }
            }
        }

        for (id, analysis) in results {
            analysisCache[id] = analysis
        }

        logger.info("QueueBuilder: Vision pre-pass complete, \(results.count) analyses cached")
    }

    // MARK: - Categorization

    private func categorize(_ asset: Asset) -> QueueCategory {
        let analysis = analysisCache[asset.id]

        // Order matters -- more specific categories first
        if asset.isScreenshot { return .screenshots }

        if analysis?.isBlurry == true { return .blurry }

        if asset.byteSize > Self.largeFileThresholdBytes { return .largeFiles }

        if let created = asset.createdAt,
           Date().timeIntervalSince(created) > Self.oldUntouchedThreshold {
            return .oldUntouched
        }

        if let text = analysis?.recognizedText, text.count >= Self.minOCRLengthForDocument {
            return .receiptsAndDocuments
        }

        return .everythingElse
    }

    // MARK: - Duplicates

    private func buildDuplicatesQueue(from assets: [Asset]) -> [Asset] {
        // Coarse bucketing by first 32 chars of perceptual hash
        var hashBuckets: [String: [Asset]] = [:]

        for asset in assets {
            guard let hash = analysisCache[asset.id]?.perceptualHash,
                  !hash.isEmpty else { continue }
            let bucketKey = String(hash.prefix(32))
            hashBuckets[bucketKey, default: []].append(asset)
        }

        // Assets that share a bucket are likely duplicates
        // Sort so the duplicate groups appear together, newest first within each group
        return hashBuckets.values
            .filter { $0.count >= 2 }
            .sorted { lhs, rhs in
                // Larger groups first
                lhs.count > rhs.count
            }
            .flatMap { group in
                group.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
            }
    }
}
