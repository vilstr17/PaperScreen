import AppKit

final class PaperOverlayWindow: NSWindow {
    private let tintLayer = CALayer()
    private let noiseLayer = CALayer()
    private let securityTintLayer = CALayer()
    private let securityLayer = CALayer()

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
        tintLayer.opacity = Float(settings.opacity)
        noiseLayer.compositingFilter = settings.blendMode
        noiseLayer.opacity = Float(opacity)
    }

    func setOpacity(_ value: CGFloat) {
        noiseLayer.opacity = Float(value)
    }

    // MARK: - Security layer

    /// `image == nil` disables the security layer entirely.
    func setSecurityLayers(tint: NSColor?, texture: CGImage?,
                           blendMode: String?, opacity: CGFloat) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        securityTintLayer.backgroundColor = tint?.cgColor
        securityTintLayer.opacity = Float(tint == nil ? 0 : opacity)
        securityTintLayer.compositingFilter = "multiplyBlendMode"

        securityLayer.contents = texture
        securityLayer.opacity = Float(texture == nil ? 0 : opacity)
        securityLayer.compositingFilter = blendMode
        // full-screen pre-tiled image; default .resize gravity maps it 1:1 to pixels

        CATransaction.commit()
    }

    /// Adjust only the security layer opacity (strength slider).
    func setSecurityOpacity(_ value: CGFloat) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        securityTintLayer.opacity = Float(securityTintLayer.backgroundColor == nil ? 0 : value)
        securityLayer.opacity = Float(securityLayer.contents == nil ? 0 : value)
        CATransaction.commit()
    }
}