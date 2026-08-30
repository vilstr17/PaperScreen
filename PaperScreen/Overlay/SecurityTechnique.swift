import AppKit

/// Privacy ("security") techniques layered on top of paper mode.
/// All exploit IPS gamma falloff at oblique viewing angles.
enum SecurityTechnique: String, CaseIterable, Identifiable {

    /// Vertical 1-physical-pixel black blinds (1 px line, 1 px gap).
    case blinds

    /// Dynamic high-frequency GPU noise, low amplitude, ~16 fps.
    /// Head-on the eye averages it out; from the side it destroys
    /// letter edges ("broken display").
    case flicker

    /// Heavily blurred gray veil. Head-on the eye filters the fog out;
    /// from the side scattered light merges with text, contrast -> 0.
    case veil

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .blinds: return "Blinds"
        case .flicker: return "Static"
        case .veil: return "Veil"
        }
    }

    var systemImage: String {
        switch self {
        case .blinds: return "rectangle.split.3x1"
        case .flicker: return "sparkles"
        case .veil: return "cloud.fog"
        }
    }

    /// Layer alpha at strength = 1.0.
    var baseOpacity: CGFloat {
        switch self {
        case .blinds: return 0.55
        case .flicker: return 0.22
        case .veil: return 0.62
        }
    }

    /// CALayer compositing filter; nil = plain source-over.
    var blendMode: String? { nil }

    /// Whether the technique draws a pre-tiled texture layer.
    var usesTexture: Bool { true }

    var animates: Bool { self == .flicker }
}