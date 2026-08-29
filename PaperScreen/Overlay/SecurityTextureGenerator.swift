import AppKit
import CoreGraphics

/// Renders tiles for the security techniques. All tiles are built in
/// *physical* pixels so 1-px blinds stay truly sub-pixel on Retina.
final class SecurityTextureGenerator {

    /// Small tile for the technique: blinds = 2px column, dither = 64x64 mesh.
    /// Returns nil for textureless techniques (contrast).
    func tile(for technique: SecurityTechnique,
              scale: CGFloat,
              strength: Double) -> CGImage? {
        switch technique {
        case .blinds:
            return blindsTile(scale: scale)
        case .dither:
            return ditherTile(strength: strength)
        case .contrast:
            return nil
        }
    }

    /// Tile `tile` across a full-screen bitmap of `size` points at `scale`.
    /// Blinds tile stretches vertically (uniform columns); dither tiles 2D.
    func tiled(tile: CGImage, size: CGSize, scale: CGFloat, stretchVertically: Bool) -> CGImage? {
        let w = max(1, Int(size.width * scale))
        let h = max(1, Int(size.height * scale))

        guard let ctx = CGContext(
            data: nil,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.setShouldAntialias(false)
        ctx.interpolationQuality = .none

        if stretchVertically {
            // Uniform vertical columns: draw one stretched tile per 2-px step
            let step = tile.width
            var x = 0
            while x < w {
                ctx.draw(tile, in: CGRect(x: CGFloat(x), y: 0,
                                          width: CGFloat(step), height: CGFloat(h)))
                x += step
            }
        } else {
            var y = 0
            while y < h {
                var x = 0
                while x < w {
                    ctx.draw(tile, in: CGRect(x: CGFloat(x), y: CGFloat(y),
                                              width: CGFloat(tile.width),
                                              height: CGFloat(tile.height)))
                    x += tile.width
                }
                y += tile.height
            }
        }

        return ctx.makeImage()
    }

    // MARK: - Tiles

    /// Vertical blinds: opaque black 1-physical-px line + 1-px transparent gap.
    private func blindsTile(scale: CGFloat) -> CGImage? {
        let px = max(1, Int(scale.rounded()))
        let width = 2 * px
        let height = max(1, px)   // at least square-ish; uniform vertically anyway

        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.setShouldAntialias(false)
        ctx.interpolationQuality = .none

        ctx.setFillColor(NSColor.black.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: px, height: height))
        // second half stays transparent

        return ctx.makeImage()
    }

    /// 64x64 ordered dither mesh from a Bayer 8x8 matrix.
    /// Mid-gray dots with density driven by strength.
    private func ditherTile(strength: Double) -> CGImage? {
        let bayer: [[Int]] = [
            [ 0, 32,  8, 40,  2, 34, 10, 42],
            [48, 16, 56, 24, 50, 18, 56, 22],
            [12, 44,  4, 36, 14, 46,  6, 38],
            [60, 28, 52, 20, 62, 30, 54, 26],
            [ 3, 35, 11, 43,  1, 33,  9, 41],
            [51, 19, 59, 27, 49, 17, 57, 25],
            [15, 47,  5, 37, 13, 45,  5, 39],
            [63, 31, 55, 23, 61, 29, 53, 25]
        ]

        let size = 64
        guard let ctx = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.setShouldAntialias(false)

        let s = Swift.min(Swift.max(CGFloat(strength), 0.05), 1.0)
        // Density: threshold scaled so strength=1 fills ~7/8 of cells
        let threshold = Double(s) * 64.0
        ctx.setFillColor(NSColor(calibratedWhite: 0.5, alpha: 1).cgColor)

        for y in 0..<size {
            for x in 0..<size {
                if Double(bayer[y % 8][x % 8]) < threshold {
                    ctx.fill(CGRect(x: CGFloat(x), y: CGFloat(y), width: 1, height: 1))
                }
            }
        }

        return ctx.makeImage()
    }
}