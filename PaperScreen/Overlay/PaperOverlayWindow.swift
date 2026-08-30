import AppKit

final class PaperOverlayWindow: NSWindow {
    private let tintLayer = CALayer()
    private let noiseLayer = CALayer()
    private let securityLayer = CALayer()
    private let securityTintLayer = CALayer()

    // Base opacities so paper visibility can be toggled independently
    // of the security layers living in the same window.
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

    /// Show/hide only the paper layers; security layers unaffected.
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

    /// `texture == nil && tint == nil` disables the security layer entirely.
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
}