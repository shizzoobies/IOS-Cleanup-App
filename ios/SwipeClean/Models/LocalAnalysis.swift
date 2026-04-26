//
//  LocalAnalysis.swift
//  SwipeClean
//
//  Output of the on-device Vision pipeline. This is what we have before any
//  Claude call. Most users get value from this alone for duplicate detection
//  and basic categorization.
//

import Foundation

struct LocalAnalysis: Hashable, Codable {
    let assetId: String
    let perceptualHash: String?
    let isBlurry: Bool
    let blurScore: Double
    let hasFaces: Bool
    let faceCount: Int
    let recognizedText: String?
    let visionLabels: [String]
    let isScreenshot: Bool
    let analyzedAt: Date
}
