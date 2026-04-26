//
//  VisionAnalyzers.swift
//  SwipeClean
//
//  On-device analyzers using Vision and Core Image.
//  All work happens locally -- nothing leaves the device here.
//

import Foundation
import UIKit
import Vision
import CoreImage

// MARK: - Perceptual hashing

protocol PerceptualHashing {
    func hash(_ image: UIImage) async -> String?
}

final class PerceptualHasher: PerceptualHashing {

    /// Generates a feature-print hash using VNGenerateImageFeaturePrintRequest.
    /// Stored as base64. Compare with `distance(from:to:)`.
    func hash(_ image: UIImage) async -> String? {
        guard let cgImage = image.cgImage else { return nil }

        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let observation = request.results?.first as? VNFeaturePrintObservation else {
            return nil
        }

        return observation.data.base64EncodedString()
    }

    /// Approximate L1 distance between two stored hashes.
    /// Lower = more visually similar. Threshold ~15 works well for near-duplicates.
    /// Phase 5 can upgrade to native VNFeaturePrintObservation.computeDistance if needed.
    static func distance(from lhsHash: String, to rhsHash: String) -> Float? {
        guard
            let lhsData = Data(base64Encoded: lhsHash),
            let rhsData = Data(base64Encoded: rhsHash),
            lhsData.count == rhsData.count,
            !lhsData.isEmpty
        else { return nil }

        let lBytes = [UInt8](lhsData)
        let rBytes = [UInt8](rhsData)
        let l1 = zip(lBytes, rBytes).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }
        return Float(l1) / Float(lBytes.count)
    }
}

// MARK: - Blur detection

struct BlurResult {
    let isBlurry: Bool
    let score: Double  // Higher = sharper
}

protocol BlurDetecting {
    func detect(_ image: UIImage) async -> BlurResult
}

final class BlurDetector: BlurDetecting {

    private static let context = CIContext(options: [.useSoftwareRenderer: false])
    private static let blurThreshold: Double = 8.0

    func detect(_ image: UIImage) async -> BlurResult {
        guard let cgImage = image.cgImage else {
            return BlurResult(isBlurry: false, score: 100)
        }

        let ciImage = CIImage(cgImage: cgImage)

        // Convert to grayscale via CIColorMatrix
        guard let grayscaleFilter = CIFilter(name: "CIColorMatrix") else {
            return BlurResult(isBlurry: false, score: 100)
        }
        let lumR = CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0)
        grayscaleFilter.setValue(ciImage, forKey: kCIInputImageKey)
        grayscaleFilter.setValue(lumR, forKey: "inputRVector")
        grayscaleFilter.setValue(lumR, forKey: "inputGVector")
        grayscaleFilter.setValue(lumR, forKey: "inputBVector")

        guard let grayImage = grayscaleFilter.outputImage else {
            return BlurResult(isBlurry: false, score: 100)
        }

        // Apply Laplacian kernel to measure edge energy
        guard let convFilter = CIFilter(name: "CIConvolution3X3") else {
            return BlurResult(isBlurry: false, score: 100)
        }
        let laplacian = CIVector(values: [0, -1, 0, -1, 4, -1, 0, -1, 0], count: 9)
        convFilter.setValue(grayImage, forKey: kCIInputImageKey)
        convFilter.setValue(laplacian, forKey: "inputWeights")
        convFilter.setValue(NSNumber(value: 0.0), forKey: "inputBias")

        guard let edgeImage = convFilter.outputImage else {
            return BlurResult(isBlurry: false, score: 100)
        }

        // Average edge brightness = proxy for variance (sharp images have more edges)
        guard let avgFilter = CIFilter(name: "CIAreaAverage") else {
            return BlurResult(isBlurry: false, score: 100)
        }
        avgFilter.setValue(edgeImage, forKey: kCIInputImageKey)
        avgFilter.setValue(CIVector(cgRect: edgeImage.extent), forKey: kCIInputExtentKey)

        guard let avgOutput = avgFilter.outputImage else {
            return BlurResult(isBlurry: false, score: 100)
        }

        var pixel = [UInt8](repeating: 0, count: 4)
        BlurDetector.context.render(
            avgOutput,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        let score = Double(pixel[0])
        return BlurResult(isBlurry: score < BlurDetector.blurThreshold, score: score)
    }
}

// MARK: - Face detection

struct FaceResult {
    let count: Int
    let regions: [CGRect]  // Normalized [0,1] Vision coordinates
}

protocol FaceDetecting {
    func detect(_ image: UIImage) async -> FaceResult
}

final class FaceDetector: FaceDetecting {

    func detect(_ image: UIImage) async -> FaceResult {
        guard let cgImage = image.cgImage else {
            return FaceResult(count: 0, regions: [])
        }

        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return FaceResult(count: 0, regions: [])
        }

        let observations = request.results ?? []
        let regions = observations.map(\.boundingBox)
        return FaceResult(count: observations.count, regions: regions)
    }
}

// MARK: - Text recognition

protocol TextRecognizing {
    func recognize(_ image: UIImage) async -> String
}

final class TextRecognizer: TextRecognizing {

    func recognize(_ image: UIImage) async -> String {
        guard let cgImage = image.cgImage else { return "" }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return ""
        }

        let text = (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: " ")

        // Max 500 chars per API contract
        return String(text.prefix(500))
    }
}

// MARK: - On-device classification

protocol OnDeviceClassifying {
    func classify(_ image: UIImage) async -> [String]
}

final class OnDeviceClassifier: OnDeviceClassifying {

    private static let confidenceThreshold: Float = 0.3
    private static let maxLabels = 5

    func classify(_ image: UIImage) async -> [String] {
        guard let cgImage = image.cgImage else { return [] }

        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return []
        }

        return (request.results ?? [])
            .filter { $0.confidence >= OnDeviceClassifier.confidenceThreshold }
            .prefix(OnDeviceClassifier.maxLabels)
            .map(\.identifier)
    }
}
