import AppKit

/// Privacy shield techniques. Only ONE user-facing option now:
/// the system-blur shield with a clear circle following the cursor.
enum SecurityTechnique: String, CaseIterable, Identifiable {

    /// Hardware-accelerated system blur over everything, with a clear
    /// circular hole that follows the mouse cursor (NSVisualEffectView,
    /// zero screen capture).
    case spotlightFollow

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .spotlightFollow: return "Cursor Shield"
        }
    }

    var systemImage: String {
        switch self {
        case .spotlightFollow: return "cursorarrow.rays"
        }
    }
}