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
    /// Backed by PaperSettings.paperEnabled so it persists and stays in
    /// sync with the UI binding.
    var enabled: Bool {
        get { settings.paperEnabled }
        set { settings.paperEnabled = newValue }
    }

    /// Bundle IDs excluded from the overlay entirely (paper AND shield).
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
    private let advancedGenerator = AdvancedTextureGenerator()
    private var cancellables = Set<AnyCancellable>()

    private var flickerTimer: Timer?
    private var veilImage: CGImage?

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
            .sink { [weak self] _ in self?.securityChanged() }
            .store(in: &cancellables)
        settings.$securityTechnique
            .sink { [weak self] _ in self?.securityChanged() }
            .store(in: &cancellables)
        settings.$securityStrength
            .sink { [weak self] _ in
                self?.refreshSecurity()
                self?.updateFlickerTimer()
            }
            .store(in: &cancellables)

        // Paper master toggle (paperEnabled) drives layer visibility only
        settings.$paperEnabled
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                let show = (self.enabled || self.settings.securityEnabled)
                    && !self.excludedApps.contains(self.focusedApp.frontBundleID ?? "")
                self.windows.values.forEach {
                    if show { $0.orderFrontRegardless() } else { $0.orderOut(nil) }
                    $0.setPaperVisible(self.enabled)
                }
            }
            .store(in: &cancellables)

        rebuild()
    }

    private func securityChanged() {
        updateVisibility()
        refreshSecurity()
        updateFlickerTimer()
        updateSpotlight()
    }

    // MARK: - Security layer

    private func securityOpacity() -> CGFloat {
        CGFloat(settings.securityTechnique.baseOpacity * settings.securityStrength)
    }

    func refreshSecurity() {
        let tech = settings.securityTechnique

        guard settings.securityEnabled else {
            windows.values.forEach {
                $0.setSecurityLayers(tint: nil, texture: nil,
                                     blendMode: nil, opacity: 0)
                $0.setSpotlight(active: false, hole: .zero)
            }
            stopFlicker()
            SpotlightTracker.shared.stop()
            return
        }

        SpotlightTracker.shared.stop()
        stopFlicker()

        switch tech {
        case .spotlight:
            windows.values.forEach {
                $0.setSecurityLayers(tint: nil, texture: nil, blendMode: nil, opacity: 0)
            }
            updateSpotlight()
            SpotlightTracker.shared.start()

        case .flicker:
            windows.values.forEach {
                $0.setSecurityLayers(tint: nil, texture: nil, blendMode: nil, opacity: 0)
            }
            updateFlickerTimer()

        case .veil:
            if veilImage == nil {
                veilImage = advancedGenerator.veilTile()
            }
            windows.values.forEach {
                $0.setSecurityLayers(tint: nil, texture: veilImage,
                                     blendMode: nil, opacity: securityOpacity())
            }

        case .blinds:
            for screen in NSScreen.screens {
                guard let win = windows["\(screen.hash)"] else { continue }
                let scale = screen.backingScaleFactor
                if let smallTile = securityGenerator.tile(
                    for: .blinds, scale: scale, strength: settings.securityStrength) {
                    let full = securityGenerator.tiled(
                        tile: smallTile, size: win.frame.size, scale: scale,
                        stretchVertically: true)
                    win.setSecurityLayers(tint: nil, texture: full,
                                          blendMode: nil, opacity: securityOpacity())
                }
            }
        }
    }

    // MARK: - Flicker (dynamic noise)

    private func updateFlickerTimer() {
        guard settings.securityEnabled,
              settings.securityTechnique == .flicker else {
            stopFlicker()
            return
        }
        guard flickerTimer == nil else { return }

        let timer = Timer(timeInterval: 1.0 / 16.0, repeats: true) { [weak self] _ in
            self?.flickerTick()
        }
        RunLoop.main.add(timer, forMode: .common)
        flickerTimer = timer
        flickerTick()
    }

    private func stopFlicker() {
        flickerTimer?.invalidate()
        flickerTimer = nil
    }

    private var flickerFrame: CGImage?

    private func flickerTick() {
        let amplitude = 0.5 * settings.securityStrength + 0.1
        let frame = advancedGenerator.flickerFrame(amplitude: CGFloat(amplitude))
        windows.values.forEach {
            $0.setSecurityLayers(tint: nil, texture: frame,
                                 blendMode: nil, opacity: securityOpacity())
        }
    }

    // MARK: - Spotlight

    /// When Spot is active but no face is seen (camera denied, user away),
    /// fall back to a dim veil so the shield never looks "off".
    private func updateSpotlight() {
        let techActive = settings.securityEnabled
            && settings.securityTechnique == .spotlight

        guard techActive else {
            windows.values.forEach { $0.setSpotlight(active: false, hole: .zero) }
            return
        }

        let hole = SpotlightTracker.shared.spotlightRect

        if SpotlightTracker.shared.faceVisible {
            // Face tracked: clear the texture/tint layers, paint the sheet+hole
            windows.values.forEach { $0.setSecurityLayers(tint: nil, texture: nil, blendMode: nil, opacity: 0) }
            for (key, win) in windows {
                guard screenForWindowKey(key) != nil else { continue }
                var local = hole
                local.origin.x -= win.frame.minX
                local.origin.y -= win.frame.minY
                win.setSpotlight(active: true, hole: local)
            }
        } else {
            // No face: dim veil fallback, never nothing
            windows.values.forEach {
                $0.setSpotlight(active: false, hole: .zero)
                if veilImage == nil { veilImage = advancedGenerator.veilTile() }
                $0.setSecurityLayers(tint: nil, texture: veilImage,
                                     blendMode: nil, opacity: 0.5)
            }
        }
    }

    /// Pump spotlight updates into the layers.
    private func startSpotlightPump() {
        SpotlightTracker.shared.$spotlightRect
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateSpotlight() }
            .store(in: &spotlightCancellables)
        SpotlightTracker.shared.$faceVisible
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateSpotlight() }
            .store(in: &spotlightCancellables)
    }

    private var spotlightCancellables = Set<AnyCancellable>()
    private var spotlightPumpStarted = false

    private func screenForWindowKey(_ key: String) -> NSScreen? {
        NSScreen.screens.first(where: { "\($0.hash)" == key })
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
        if !spotlightPumpStarted {
            startSpotlightPump()
            spotlightPumpStarted = true
        }
        updateVisibility()
    }

    func setOpacity(_ value: CGFloat) {
        windows.values.forEach { $0.setOpacity(value) }
    }
}