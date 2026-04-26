//
//  QueueCategory.swift
//  SwipeClean
//
//  The bucketed categories users can choose from on the queue selection screen.
//

import Foundation

enum QueueCategory: String, Codable, CaseIterable, Identifiable {
    case duplicates
    case screenshots
    case blurry
    case largeFiles
    case oldUntouched
    case receiptsAndDocuments
    case everythingElse
    case surpriseMe

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .duplicates: return "Duplicates"
        case .screenshots: return "Screenshots"
        case .blurry: return "Blurry"
        case .largeFiles: return "Large Files"
        case .oldUntouched: return "Old & Untouched"
        case .receiptsAndDocuments: return "Receipts & Documents"
        case .everythingElse: return "Everything Else"
        case .surpriseMe: return "Surprise Me"
        }
    }

    var iconSystemName: String {
        switch self {
        case .duplicates: return "square.stack.3d.up.fill"
        case .screenshots: return "rectangle.dashed"
        case .blurry: return "camera.filters"
        case .largeFiles: return "externaldrive.fill"
        case .oldUntouched: return "clock.arrow.circlepath"
        case .receiptsAndDocuments: return "doc.text.fill"
        case .everythingElse: return "photo.stack"
        case .surpriseMe: return "wand.and.stars"
        }
    }
}
