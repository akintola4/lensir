//
//  CodeImage.swift
//  Lensir
//
//  Draws a QR code with CoreImage's generator at correction level M, black
//  on white with a four-module quiet zone, the margin scanners expect. The
//  small image has one pixel per module; anything bigger is scaled up with
//  nearest-neighbour, so every module stays a hard-edged square.
//

import CoreGraphics
import CoreImage.CIFilterBuiltins
import UIKit

nonisolated enum CodeImage {
    /// Modules of white around the code, on every side.
    static let quietZone = 4

    private static let context = CIContext(options: [.cacheIntermediates: false])

    /// One pixel per module, quiet zone included. Nil when the text is too
    /// much for one code.
    static func modules(for payload: String) -> CGImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage,
              let generated = context.createCGImage(output, from: output.extent)
        else { return nil }
        // CoreImage leaves one module of margin; pad it out to four.
        let pad = quietZone - 1
        return draw(generated, side: generated.width + pad * 2, inset: pad, scale: 1)
    }

    /// The code at `scale` pixels per module, for sharing and saving.
    static func scaled(_ modules: CGImage, scale: Int) -> CGImage? {
        draw(modules, side: modules.width * scale, inset: 0, scale: scale)
    }

    /// The code at least `pixels` wide, in whole pixels per module.
    static func image(for payload: String, atLeast pixels: Int) -> UIImage? {
        guard let modules = modules(for: payload) else { return nil }
        let scale = max(1, Int((Double(pixels) / Double(modules.width)).rounded(.up)))
        return scaled(modules, scale: scale).map { UIImage(cgImage: $0) }
    }

    private static func draw(_ image: CGImage, side: Int, inset: Int, scale: Int) -> CGImage? {
        guard let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
        else { return nil }
        context.interpolationQuality = .none
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        let origin = CGFloat(inset * scale)
        context.draw(image, in: CGRect(x: origin, y: origin, width: CGFloat(image.width * scale), height: CGFloat(image.height * scale)))
        return context.makeImage()
    }
}

/// Codes already drawn, by payload, so a list of them doesn't redraw every
/// row on every pass.
enum CodeImageCache {
    private static var images: [String: CGImage] = [:]

    static func modules(for payload: String) -> CGImage? {
        if let image = images[payload] { return image }
        guard let image = CodeImage.modules(for: payload) else { return nil }
        if images.count > 200 { images.removeAll() }
        images[payload] = image
        return image
    }
}
