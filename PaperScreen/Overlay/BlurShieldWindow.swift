import AppKit

/// Blur-everything privacy shield with a clear circle that follows
/// the mouse cursor. Zero screen capture: NSVisualEffectView with
/// .behindWindow lets WindowServer blur the content below in hardware.
/// The fog alpha is adjustable — subtle by design, contours stay visible.
final class BlurShieldWindow: NSWindow {

    private let maskLayer = CAShapeLayer()
    private let effectView: NSVisualEffectView

    /// Clear-circle radius in points.
    var holeRadius: CGFloat = 150 {
        didSet { updateMask() }
    }

    /// How strong the fog is (0 = invisible, 1 = heavy).
    var fogAlpha: CGFloat = 0.30 {
        didSet { effectView.alphaValue = fogAlpha }
    }

    /// Hole center in window-local coordinates (bottom-left origin,
    /// matching both AppKit global coords and unflipped CALayer space).
    var holeCenter: CGPoint = CGPoint(x: -10000, y: -10000) {
        didSet { updateMask() }
    }

    init(screen: NSScreen) {
        let frame = screen.frame
        effectView = NSVisualEffectView(frame: NSRect(origin: .zero, size: frame.size))

        super.init(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        ignoresMouseEvents = true
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        effectView.material = .underWindowBackground
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.autoresizingMask = [.width, .height]
        effectView.alphaValue = fogAlpha
        effectView.wantsLayer = true

        contentView = effectView
        effectView.layer?.mask = maskLayer
        effectView.layer?.masksToBounds = false
        updateMask()
    }

    private func updateMask() {
        guard let bounds = contentView?.bounds, bounds.width > 0 else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        // Even-odd: full rect (blur) minus ellipse (hole) = inverted mask
        let fullPath = CGMutablePath()
        fullPath.addRect(CGRect(origin: .zero, size: bounds.size))

        let hole = CGPath(
            ellipseIn: CGRect(
                x: holeCenter.x - holeRadius,
                y: holeCenter.y - holeRadius,
                width: holeRadius * 2,
                height: holeRadius * 2
            ),
            transform: nil
        )
        fullPath.addPath(hole)

        maskLayer.path = fullPath
        maskLayer.frame = CGRect(origin: .zero, size: bounds.size)
        CATransaction.commit()
    }
}