//
//  VisionPipeline.swift
//  SwipeClean
//
//  Coordinates the on-device Vision and Core Image work for a single asset.
//  Outputs a LocalAnalysis. Caches results in SwiftData.
//
//  TODO(phase2): wire up the individual analyzers.
//

import Foundation
import UIKit

protocol VisionPipelining: AnyObject {
    func analyze(_ asset: Asset, image: UIImage) async -> LocalAnalysis
    func batchAnalyze(_ assets: [Asset], thumbnailFor: (Asset) async -> UIImage?) async -> [LocalAnalysis]
}

final class VisionPipeline: VisionPipelining {

    private let perceptualHasher: PerceptualHashing
    private let blurDetector: BlurDetecting
    private let faceDetector: FaceDetecting
    private let textRecognizer: TextRecognizing
    private let classifier: OnDeviceClassifying

    init(
        perceptualHasher: PerceptualHashing = PerceptualHasher(),
        blurDetector: BlurDetecting = BlurDetector(),
        faceDetector: FaceDetecting = FaceDetector(),
        textRecognizer: TextRecognizing = TextRecognizer(),
        classifier: OnDeviceClassifying = OnDeviceClassifier()
    ) {
        self.perceptualHasher = perceptualHasher
        self.blurDetector = blurDetector
        self.faceDetector = faceDetector
        self.textRecognizer = textRecognizer
        self.classifier = classifier
    }

    func analyze(_ asset: Asset, image: UIImage) async -> LocalAnalysis {
        async let hash = perceptualHasher.hash(image)
        async let blur = blurDetector.detect(image)
        async let faces = faceDetector.detect(image)
        async let text = textRecognizer.recognize(image)
        async let labels = classifier.classify(image)

        let (hashValue, blurResult, faceResult, textResult, labelResult) = await (hash, blur, faces, text, labels)

        return LocalAnalysis(
            assetId: asset.id,
            perceptualHash: hashValue,
            isBlurry: blurResult.isBlurry,
            blurScore: blurResult.score,
            hasFaces: faceResult.count > 0,
            faceCount: faceResult.count,
            recognizedText: textResult.isEmpty ? nil : textResult,
            visionLabels: labelResult,
            isScreenshot: asset.isScreenshot,
            analyzedAt: Date()
        )
    }

    func batchAnalyze(_ assets: [Asset], thumbnailFor: (Asset) async -> UIImage?) async -> [LocalAnalysis] {
        var results: [LocalAnalysis] = []
        for asset in assets {
            guard let image = await thumbnailFor(asset) else { continue }
            let analysis = await analyze(asset, image: image)
            results.append(analysis)
        }
        return results
    }
}
