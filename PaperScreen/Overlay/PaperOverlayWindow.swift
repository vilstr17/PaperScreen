import AppKit

/// Draws a full-window black sheet with a rectangular hole (spotlight).
final class SpotlightMaskLayer: CALayer {
    var hole: NSRect = .zero {
        didSet { setNeedsDisplay() }
    }
    private var holeCornerRadius: CGFloat = 24

    override func draw(in ctx: CGContext) {
        guard bounds.width > 0 else { return }
        ctx.setFillColor(NSColor.black.cgColor)
        ctx.fill(bounds)

        if hole.width > 0, hole.height > 0 {
            // Convert window coords (top-left origin in layer space is
            // flipped: CALayer geometry is bottom-left) — the window is
            // borderless fullscreen, so local == global shifted by origin.
            let local = NSRect(
                x: hole.minX,
                y: hole.minY,
                width: hole.width,
                height: hole.height
            )
            let path = CGPath(roundedRect: local, cornerWidth: holeCornerRadius,
                              cornerHeight: holeCornerRadius, transform: nil)
            ctx.setBlendMode(.clear)     // punch a real hole (alpha 0) so the apps show through
            ctx.addPath(path)
            ctx.fillPath()
        }
    }
}

final class PaperOverlayWindow: NSWindow {
    private let tintLayer = CALayer()
    private let noiseLayer = CALayer()
    private let securityLayer = CALayer()
    private let securityTintLayer = CALayer()
    private let spotlightLayer = SpotlightMaskLayer()

    private var noiseBase: Float = 0.12
    private var tintBase: Float = 0.18
    private var paperVisible = true

    init(screen: NSScreen, opacity: CGFloat) {
        super.init(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)

        isOpaque = false
        backgroundColor = .clear
        ignoresMouseEvents = true
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces,.fullScreenAuxiliary,.stationary]

        contentView?.wantsLayer = true
        if let root = contentView?.layer {
            tintLayer.frame = root.bounds
            tintLayer.backgroundColor = NSColor(calibratedRed: 247/255, green: 243/255, blue: 232/255, alpha: 0.08).cgColor
            root.addSublayer(tintLayer)

            noiseLayer.frame = root.bounds
            noiseLayer.opacity = Float(opacity)
            noiseLayer.compositingFilter = "softLightBlendMode"
            root.addSublayer(noiseLayer)

            securityLayer.frame = root.bounds
            root.addSublayer(securityLayer)

            securityTintLayer.frame = root.bounds
            root.addSublayer(securityTintLayer)

            spotlightLayer.frame = root.bounds
            spotlightLayer.contentsScale = screen.backingScaleFactor
            spotlightLayer.needsDisplayOnBoundsChange = true
            root.addSublayer(spotlightLayer)
        }
    }

    func setTexture(_ image: CGImage?) {
        noiseLayer.contents = image
    }

    func configure(with texture: PaperTexture, opacity: CGFloat) {
        let settings = texture.settings
        tintLayer.backgroundColor = settings.tint.withAlphaComponent(0.14).cgColor
        tintBase = Float(settings.opacity)
        noiseBase = Float(opacity)
        noiseLayer.compositingFilter = settings.blendMode
        applyPaperOpacity()
    }

    func setOpacity(_ value: CGFloat) {
        noiseBase = Float(value)
        applyPaperOpacity()
    }

    func setPaperVisible(_ visible: Bool) {
        paperVisible = visible
        applyPaperOpacity()
    }

    private func applyPaperOpacity() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        tintLayer.opacity = paperVisible ? tintBase : 0
        noiseLayer.opacity = paperVisible ? noiseBase : 0
        CATransaction.commit()
    }

    // MARK: - Security layer

    func setSecurityLayers(tint: NSColor?, texture: CGImage?,
                           blendMode: String?, opacity: CGFloat) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        securityTintLayer.backgroundColor = tint?.cgColor
        securityTintLayer.opacity = Float(tint == nil ? 0 : opacity)
        securityTintLayer.compositingFilter = blendMode ?? "multiplyBlendMode"

        securityLayer.contents = texture
        securityLayer.opacity = Float(texture == nil ? 0 : opacity)
        securityLayer.compositingFilter = blendMode

        CATransaction.commit()
    }

    // MARK: - Spotlight

    func setSpotlight(active: Bool, hole: NSRect) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if active {
            spotlightLayer.isHidden = false
            spotlightLayer.opacity = 1
            spotlightLayer.hole = hole
            spotlightLayer.setNeedsDisplay()
        } else {
            spotlightLayer.isHidden = true
        }
        CATransaction.commit()
    }
}