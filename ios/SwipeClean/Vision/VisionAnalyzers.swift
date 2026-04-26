//
//  VisionAnalyzers.swift
//  SwipeClean
//
//  Protocols and stub implementations for the individual on-device analyzers.
//  Each is wired up in phase 2.
//

import Foundation
import UIKit

// MARK: - Perceptual hashing

protocol PerceptualHashing {
    func hash(_ image: UIImage) async -> String?
}

final class PerceptualHasher: PerceptualHashing {
    func hash(_ image: UIImage) async -> String? {
        // TODO(phase2): VNGenerateImageFeaturePrintRequest, return a comparable hex string.
        return nil
    }
}

// MARK: - Blur detection

struct BlurResult {
    let isBlurry: Bool
    let score: Double
}

protocol BlurDetecting {
    func detect(_ image: UIImage) async -> BlurResult
}

final class BlurDetector: BlurDetecting {
    func detect(_ image: UIImage) async -> BlurResult {
        // TODO(phase2): Laplacian variance via Core Image. Threshold ~100 for "blurry".
        return BlurResult(isBlurry: false, score: 0)
    }
}

// MARK: - Face detection

struct FaceResult {
    let count: Int
    let regions: [CGRect]
}

protocol FaceDetecting {
    func detect(_ image: UIImage) async -> FaceResult
}

final class FaceDetector: FaceDetecting {
    func detect(_ image: UIImage) async -> FaceResult {
        // TODO(phase2): VNDetectFaceRectanglesRequest.
        return FaceResult(count: 0, regions: [])
    }
}

// MARK: - Text recognition

protocol TextRecognizing {
    func recognize(_ image: UIImage) async -> String
}

final class TextRecognizer: TextRecognizing {
    func recognize(_ image: UIImage) async -> String {
        // TODO(phase2): VNRecognizeTextRequest with .accurate level.
        return ""
    }
}

// MARK: - On-device classification

protocol OnDeviceClassifying {
    func classify(_ image: UIImage) async -> [String]
}

final class OnDeviceClassifier: OnDeviceClassifying {
    func classify(_ image: UIImage) async -> [String] {
        // TODO(phase2): VNClassifyImageRequest, return top-5 labels.
        return []
    }
}
