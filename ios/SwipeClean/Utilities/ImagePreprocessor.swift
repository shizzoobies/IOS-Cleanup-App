//
//  ImagePreprocessor.swift
//  SwipeClean
//
//  Prepares images for upload to the Claude proxy. Downsamples, strips EXIF,
//  blurs faces. This is a privacy-critical class. Test it.
//

import Foundation
import UIKit
import CoreImage

protocol ImagePreprocessing {
    func prepareForUpload(
        _ image: UIImage,
        faceRegions: [CGRect],
        blurFaces: Bool
    ) -> Data?
}

final class ImagePreprocessor: ImagePreprocessing {

    private let maxLongEdge: CGFloat = 512
    private let jpegQuality: CGFloat = 0.7
    private let context = CIContext()

    func prepareForUpload(
        _ image: UIImage,
        faceRegions: [CGRect],
        blurFaces: Bool
    ) -> Data? {
        // TODO(phase4):
        //   1. Resize to maxLongEdge while preserving aspect ratio.
        //   2. If blurFaces and !faceRegions.isEmpty, apply CIGaussianBlur in face regions.
        //   3. Encode JPEG at jpegQuality.
        //   4. Confirm output strips EXIF (UIImage JPEG encoding does not preserve EXIF GPS).
        return nil
    }
}
