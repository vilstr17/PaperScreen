import AppKit
import Combine

final class PaperOverlayController: ObservableObject {

    /// Window is on screen iff paper mode or privacy shield is active
    /// (and the focused app is not excluded).
    private func updateVisibility() {
        let shouldShow = (enabled || settings.securityEnabled)
            && !excludedApps.contains(focusedApp.frontBundleID ?? "")
        for window in windows.values {
            if shouldShow {
                window.orderFrontRegardless()
            } else {
                window.orderOut(nil)
            }
        }
         // keep per-layer visibility in sync too
         for window in windows.values {
             window.setPaperVisible(enabled)
         }
         refreshSecurity()
    }

    func setTexture(_ texture: PaperTexture) {
        let tile = generator.generateTile(for: texture)

        windows.values.forEach { window in
            window.setTexture(tile)
            window.configure(with: texture, opacity: CGFloat(settings.opacity))
        }
    }

    /// Paper mode master switch — affects ONLY the paper layers.
    @Published var enabled = true {
        didSet {
            updateVisibility()
        }
    }

    /// Lowercased bundle IDs excluded from the overlay entirely
    /// (applies to paper AND shield).
    @Published var excludedApps: Set<String> = [] {
        didSet {
            UserDefaults.standard.set(Array(excludedApps).sorted(), forKey: "excludedApps")
            updateVisibility()
        }
    }

    let focusedApp = FocusedAppMonitor()

    private let settings: PaperSettings
    private var windows: [String: PaperOverlayWindow] = [:]
    private let generator = NoiseTextureGenerator()
    private let securityGenerator = SecurityTextureGenerator()
    private var cancellables = Set<AnyCancellable>()

    init(settings: PaperSettings) {
        self.settings = settings

        let d = UserDefaults.standard
        excludedApps = Set(d.stringArray(forKey: "excludedApps") ?? [])

        focusedApp.$frontBundleID
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateVisibility() }
            .store(in: &cancellables)

        settings.$opacity
            .sink { [weak self] value in
                self?.windows.values.forEach {
                    $0.setOpacity(CGFloat(value))
                }
            }
            .store(in: &cancellables)

        settings.$texture
            .receive(on: RunLoop.main)
            .sink { [weak self] texture in
                self?.setTexture(texture)
            }
            .store(in: &cancellables)

        settings.$securityEnabled
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.updateVisibility()
                self.refreshSecurity()
            }
            .store(in: &cancellables)
        settings.$securityTechnique
            .sink { [weak self] _ in self?.refreshSecurity() }
            .store(in: &cancellables)
        settings.$securityStrength
            .sink { [weak self] _ in self?.refreshSecurity() }
            .store(in: &cancellables)

        rebuild()
    }

    // MARK: - Security layer

    private func securityOpacity() -> CGFloat {
        CGFloat(settings.securityTechnique.baseOpacity * settings.securityStrength)
    }

    /// Rebuild the security layers on every window from current settings.
    func refreshSecurity() {
        guard settings.securityEnabled else {
            windows.values.forEach {
                $0.setSecurityLayers(tint: nil, texture: nil,
                                     blendMode: nil, opacity: 0)
            }
            return
        }

        let tech = settings.securityTechnique
        let opacity = securityOpacity()

        guard tech.usesTexture else {
            // Gray Merge: uniform wash, multiplied over content
            windows.values.forEach {
                $0.setSecurityLayers(tint: tech.tint, texture: nil,
                                     blendMode: "multiplyBlendMode",
                                     opacity: opacity)
            }
            return
        }

        // Per-screen pixel-exact texture (blinds / dither)
        for screen in NSScreen.screens {
            guard let win = windows["\(screen.hash)"] else { continue }
            let scale = screen.backingScaleFactor

            if let smallTile = securityGenerator.tile(
                for: tech, scale: scale, strength: settings.securityStrength) {

                let full = securityGenerator.tiled(
                    tile: smallTile,
                    size: win.frame.size,
                    scale: scale,
                    stretchVertically: tech == .blinds
                )
                win.setSecurityLayers(tint: nil, texture: full,
                                      blendMode: tech.blendMode, opacity: opacity)
            } else {
                win.setSecurityLayers(tint: nil, texture: nil,
                                      blendMode: nil, opacity: 0)
            }
        }
    }

    // MARK: - Rebuild

    func rebuild() {
        windows.removeAll()
        let texture = settings.texture
        let tile = generator.generateTile(for: texture)
        for screen in NSScreen.screens {
            let w = PaperOverlayWindow(
                screen: screen,
                opacity: CGFloat(settings.opacity)
            )
            w.setTexture(tile)
            w.configure(with: texture, opacity: CGFloat(settings.opacity))
            w.orderFront(nil)
            windows["\(screen.hash)"] = w
        }
        updateVisibility()
        refreshSecurity()
    }

    func setOpacity(_ value: CGFloat) {
        windows.values.forEach { $0.setOpacity(value) }
    }
}