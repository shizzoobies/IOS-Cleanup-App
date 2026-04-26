//
//  ClaudeAnalysis.swift
//  SwipeClean
//
//  Response from the backend proxy (which wraps Anthropic API).
//

import Foundation

enum AssetCategory: String, Codable, CaseIterable {
    case photo
    case screenshot
    case document
    case receipt
    case meme
    case social
    case art
    case nature
    case food
    case people
    case pet
    case place
    case other
}

struct AlbumSuggestionResult: Codable, Hashable {
    let name: String
    let isExisting: Bool
    let confidence: Double

    enum CodingKeys: String, CodingKey {
        case name
        case isExisting = "is_existing"
        case confidence
    }
}

struct ClaudeAnalysis: Codable, Hashable {
    let category: AssetCategory
    let summary: String
    let suggestedAlbum: AlbumSuggestionResult?
    let rationale: String?
    let cached: Bool
    let requestId: String

    enum CodingKeys: String, CodingKey {
        case category
        case summary
        case suggestedAlbum = "suggested_album"
        case rationale
        case cached
        case requestId = "request_id"
    }
}
