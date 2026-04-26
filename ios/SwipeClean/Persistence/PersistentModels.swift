//
//  PersistentModels.swift
//  SwipeClean
//
//  SwiftData @Model types. All persistent state for sessions, decisions,
//  cached analysis, and album suggestions lives here.
//

import Foundation
import SwiftData

@Model
final class Session {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var categoryRaw: String
    @Relationship(deleteRule: .cascade) var decisions: [Decision]

    var category: QueueCategory {
        QueueCategory(rawValue: categoryRaw) ?? .everythingElse
    }

    init(category: QueueCategory) {
        self.id = UUID()
        self.startedAt = Date()
        self.categoryRaw = category.rawValue
        self.decisions = []
    }
}

enum DecisionAction: String, Codable {
    case keep
    case delete
    case skip
}

@Model
final class Decision {
    @Attribute(.unique) var id: UUID
    var assetIdentifier: String
    var actionRaw: String
    var albumName: String?
    var createdAt: Date
    var undone: Bool

    var action: DecisionAction {
        DecisionAction(rawValue: actionRaw) ?? .skip
    }

    init(assetIdentifier: String, action: DecisionAction, albumName: String? = nil) {
        self.id = UUID()
        self.assetIdentifier = assetIdentifier
        self.actionRaw = action.rawValue
        self.albumName = albumName
        self.createdAt = Date()
        self.undone = false
    }
}

@Model
final class CachedAnalysis {
    @Attribute(.unique) var perceptualHash: String
    var category: String
    var summary: String
    var suggestedAlbum: String?
    var cachedAt: Date

    init(perceptualHash: String, category: String, summary: String, suggestedAlbum: String?) {
        self.perceptualHash = perceptualHash
        self.category = category
        self.summary = summary
        self.suggestedAlbum = suggestedAlbum
        self.cachedAt = Date()
    }
}

@Model
final class AlbumSuggestion {
    @Attribute(.unique) var id: UUID
    var assetIdentifier: String
    var suggestedName: String
    var accepted: Bool?
    var createdAt: Date

    init(assetIdentifier: String, suggestedName: String) {
        self.id = UUID()
        self.assetIdentifier = assetIdentifier
        self.suggestedName = suggestedName
        self.accepted = nil
        self.createdAt = Date()
    }
}
