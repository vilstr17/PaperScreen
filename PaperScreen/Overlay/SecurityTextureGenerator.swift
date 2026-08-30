import AppKit
import CoreGraphics

/// Renders the blinds tile. All other techniques live in
/// AdvancedTextureGenerator / SpotlightTracker.
final class SecurityTextureGenerator {

    /// Vertical blinds: opaque black 1-physical-px line + 1-px transparent gap.
    /// Blinds tile is stretched vertically across the screen.
    func tile(for technique: SecurityTechnique,
              scale: CGFloat,
              strength: Double) -> CGImage? {
        guard technique == .blinds else { return nil }
        return blindsTile(scale: scale)
    }

    private func blindsTile(scale: CGFloat) -> CGImage? {
        let px = max(1, Int(scale.rounded()))
        let width = 2 * px
        let height = max(1, px)

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

    /// Tile `tile` across a full-screen bitmap of `size` points at `scale`.
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
}