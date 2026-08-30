import AppKit

/// Blur-everything privacy shield with a clear circle that follows
/// the mouse cursor. Zero screen capture: NSVisualEffectView with
/// .behindWindow lets WindowServer blur the content below in hardware.
final class BlurShieldWindow: NSWindow, NSWindowDelegate {

    let effectView: NSVisualEffectView
    let maskLayer = CAShapeLayer()
    let containerLayer = CALayer()

    /// Hole radius in points.
    var holeRadius: CGFloat = 140 {
        didSet { updateMask() }
    }

    /// Center of the hole in *window local* coordinates (top-left origin,
    /// as AppKit view geometry uses flipped coordinates inside windows).
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
        delegate = self

        effectView.material = .underWindowBackground
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.autoresizingMask = [.width, .height]
        effectView.frame = NSRect(origin: .zero, size: frame.size)

        let content = NSView(frame: NSRect(origin: .zero, size: frame.size))
        content.wantsLayer = true
        content.addSubview(effectView)

        // Inverted mask: blur everywhere except the hole.
        containerLayer.frame = CGRect(origin: .zero, size: frame.size)
        content.layer?.addSublayer(containerLayer)

        maskLayer.fillRule = .evenOdd
        containerLayer.mask = maskLayer
        containerLayer.backgroundColor = NSColor.black.withAlphaComponent(0.08).cgColor

        contentView = content
        updateMask()
    }

    private func updateMask() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let frame = CGRect(origin: .zero, size: frame.size)
        let fullPath = CGMutablePath()
        fullPath.addRect(frame)

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
        maskLayer.frame = containerLayer.bounds
         CATransaction.commit()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        false
    }
}

private extension CGSize {
    var asRect: NSRect { NSRect(origin: .zero, size: self) }
}