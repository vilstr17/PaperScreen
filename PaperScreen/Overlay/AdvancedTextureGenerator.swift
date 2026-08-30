import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Renders source imagery for the advanced security techniques.
final class AdvancedTextureGenerator {

    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // MARK: - Veil (blurred gray fog)

    /// Large soft noise field blurred heavily — an organic gray fog.
    func veilTile(size: Int = 256, blur: CGFloat = 40, gray: CGFloat = 0.68) -> CGImage? {
        guard let ctx = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // Low-frequency blotches
        var rnd = SystemRandomNumberGenerator()
        var lastY: UInt8 = 128
        for y in 0..<size {
            var lastX: UInt8 = 128
            for x in 0..<size {
                // smooth pseudo-noise: random walk on both axes
                let step = UInt8.random(in: 0...6, using: &rnd)
                let v = Int(lastX) - 3 + Int.random(in: -2...2)
                lastX = UInt8(max(0, min(255, v + Int(step) / 2)))
                if x == 0 { lastX = lastY }
                let g = UInt8(max(0, min(255, Int(gray * 255) + (Int(lastX) - 128) / 3)))
                ctx.setFillColor(NSColor(calibratedWhite: CGFloat(g) / 255.0, alpha: 1).cgColor)
                ctx.fill(CGRect(x: x, y: y, width: 1, height: 1))
            }
            lastY = lastX
        }

        guard var image = ctx.makeImage() else { return nil }

        var ci = CIImage(cgImage: image)
        let blurFilter = CIFilter.gaussianBlur()
        blurFilter.inputImage = ci.cropped(to: CGRect(x: 0, y: 0, width: size, height: size))
        blurFilter.radius = Float(blur)
        if let out = blurFilter.outputImage {
            ci = out.cropped(to: CGRect(x: 8, y: 8, width: size - 16, height: size - 16))
        }
        return ciContext.createCGImage(ci, from: CGRect(x: 8, y: 8, width: size - 16, height: size - 16))
            ?? image
    }

    // MARK: - Flicker frame (high-frequency noise, GPU-accelerated)

    /// One frame of fine noise; the controller re-renders it ~16x per second.
    /// Blue-noise-ish: white speckle over transparent base.
    func flickerFrame(size: Int = 512, amplitude: CGFloat) -> CGImage? {
        guard let ctx = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // High spatial frequency = per-pixel random, uncorrelated.
        // Drawn as small rects; 512x512 fills are fast enough at 16 fps on M-series.
        ctx.setFillColor(NSColor.white.cgColor)
        let cells = size / 2
        for _ in 0..<(cells * cells / 3) {
            let x = CGFloat(Int.random(in: 0..<size))
            let y = CGFloat(Int.random(in: 0..<size))
            let a = Double.random(in: 0.1...Double(amplitude))
            ctx.setAlpha(a)
            ctx.fill(CGRect(x: x, y: y, width: 1, height: 1))
        }

        return ctx.makeImage()
    }
}

extension Double {
    var cg: CGFloat { CGFloat(self) }
}