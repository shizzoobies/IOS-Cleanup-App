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
    private let context: CIContext

    init() {
        self.context = CIContext(options: [.useSoftwareRenderer: false])
    }

    func prepareForUpload(
        _ image: UIImage,
        faceRegions: [CGRect],
        blurFaces: Bool
    ) -> Data? {
        // Render the UIImage's display orientation into a fresh CGImage so
        // downstream CIImage and Vision regions share the same coordinate space.
        guard let cgImage = renderUprightCGImage(image) else { return nil }

        let originalExtent = CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
        let longEdge = max(originalExtent.width, originalExtent.height)
        let scale: CGFloat = longEdge > maxLongEdge ? (maxLongEdge / longEdge) : 1.0

        var ciImage = CIImage(cgImage: cgImage)
        if scale < 1.0 {
            ciImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        }
        let scaledExtent = ciImage.extent.integral
        ciImage = ciImage.cropped(to: scaledExtent)

        if blurFaces && !faceRegions.isEmpty {
            ciImage = applyFaceBlur(to: ciImage, faceRegions: faceRegions, in: scaledExtent)
        }

        guard let renderedCG = context.createCGImage(ciImage, from: scaledExtent) else {
            return nil
        }

        // UIImage(cgImage:) -> jpegData(compressionQuality:) does not preserve
        // EXIF or GPS metadata; the resulting JPEG carries only the JFIF header.
        let renderedUI = UIImage(cgImage: renderedCG)
        return renderedUI.jpegData(compressionQuality: jpegQuality)
    }

    private func renderUprightCGImage(_ image: UIImage) -> CGImage? {
        if image.imageOrientation == .up, let cg = image.cgImage {
            return cg
        }
        // Redraw into a context to bake in any orientation transform.
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        let upright = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        return upright.cgImage
    }

    private func applyFaceBlur(
        to base: CIImage,
        faceRegions: [CGRect],
        in extent: CGRect
    ) -> CIImage {
        // Vision returns boxes normalized [0,1] with origin at bottom-left,
        // matching CIImage's coordinate space directly.
        let blurredFull = base
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 18.0])
            .cropped(to: extent)

        let mask = buildFaceMask(faceRegions: faceRegions, in: extent)

        return blurredFull.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: base,
            kCIInputMaskImageKey: mask
        ]).cropped(to: extent)
    }

    private func buildFaceMask(faceRegions: [CGRect], in extent: CGRect) -> CIImage {
        var mask = solidColor(.black, extent: extent)

        for region in faceRegions {
            // Pad faces a bit so hair, ears, and forehead are also obscured.
            let padded = region.insetBy(dx: -0.05, dy: -0.06)
            let absolute = CGRect(
                x: extent.minX + padded.minX * extent.width,
                y: extent.minY + padded.minY * extent.height,
                width: padded.width * extent.width,
                height: padded.height * extent.height
            ).intersection(extent)
            guard !absolute.isEmpty else { continue }
            let whiteRect = solidColor(.white, extent: absolute)
            mask = whiteRect.composited(over: mask)
        }
        return mask
    }

    private func solidColor(_ color: CIColor, extent: CGRect) -> CIImage {
        guard let filter = CIFilter(name: "CIConstantColorGenerator") else {
            return CIImage.empty()
        }
        filter.setValue(color, forKey: kCIInputColorKey)
        return (filter.outputImage ?? CIImage.empty()).cropped(to: extent)
    }
}
