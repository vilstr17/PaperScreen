import AppKit

/// Privacy ("security") techniques layered on top of paper mode.
/// All three exploit IPS gamma falloff at oblique viewing angles:
/// content that is readable head-on degrades for shoulder-surfers.
enum SecurityTechnique: String, CaseIterable, Identifiable {

    /// Vertical 1-physical-pixel black blinds (1 px line, 1 px gap).
    /// Simulates a physical privacy filter via sub-pixel parallax.
    case blinds

    /// Fine ordered (Bayer 8x8) dither mesh, hard-light blended.
    /// Burns into text edges when viewed from the side.
    case dither

    /// Contrast compression: mid-gray wash lifts the black floor,
    /// so the dynamic range left for a side viewer collapses.
    case contrast

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .blinds: return "Blinds"
        case .dither: return "Dither"
        case .contrast: return "Gray Merge"
        }
    }

    var systemImage: String {
        switch self {
        case .blinds: return "rectangle.split.3x1"
        case .dither: return "grid"
        case .contrast: return "circle.lefthalf.filled"
        }
    }

    /// Base layer opacity at strength = 1.0
    var baseOpacity: CGFloat {
        switch self {
        case .blinds: return 0.55
        case .dither: return 0.12
        case .contrast: return 0.45
        }
    }

    /// CALayer compositing filter; nil = normal blending.
    var blendMode: String? {
        switch self {
        case .blinds: return nil // plain source-over: crisp black lines
        case .dither: return "hardLightBlendMode"
        case .contrast: return nil
        }
    }

    /// Tint applied by the window for this technique (nil = textureless tint only).
    var tint: NSColor? {
        switch self {
        case .contrast:
            return NSColor(calibratedWhite: 0.5, alpha: 1)
        default:
            return nil
        }
    }

    /// Whether this technique renders the strip/texture layer.
    var usesTexture: Bool {
        switch self {
        case .blinds, .dither: return true
        case .contrast: return false
        }
    }
}