import AppKit
import Combine

final class PaperOverlayController: ObservableObject {

    // MARK: - Single source of truth

    /// One authoritative pass: window visibility + paper layers +
    /// security layers. Every state change funnels through here.
    private func applyState() {
        let paperOn = settings.paperEnabled
        let shieldOn = settings.securityEnabled
        let excluded = excludedApps.contains(focusedApp.frontBundleID ?? "")

        for window in windows.values {
            if (paperOn || shieldOn) && !excluded {
                window.orderFrontRegardless()
            } else {
                window.orderOut(nil)
            }
            window.setPaperVisible(paperOn)
        }

        applySecurity()
    }

    /// Repaints ONLY the security layers — called on any shield change.
    private func applySecurity() {
        // Always stop side-effects first
        stopFlicker()
        SpotlightTracker.shared.stop()

        guard settings.securityEnabled else {
            windows.values.forEach {
                $0.setSecurityLayers(tint: nil, texture: nil,
                                     blendMode: nil, opacity: 0)
                $0.setSpotlight(active: false, hole: .zero)
            }
            return
        }

        switch settings.securityTechnique {
        case .blinds:
            // Per-screen pixel-exact tiles, keyed by stable display ID
            for (displayID, window) in windows {
                guard let screen = screenForDisplayID(displayID) else { continue }
                let scale = screen.backingScaleFactor
                if let smallTile = securityGenerator.tile(
                    for: .blinds, scale: scale, strength: settings.securityStrength) {
                    let full = securityGenerator.tiled(
                        tile: smallTile, size: window.frame.size, scale: scale,
                        stretchVertically: true)
                    window.setSecurityLayers(tint: nil, texture: full,
                                             blendMode: nil, opacity: securityOpacity())
                }
                window.setSpotlight(active: false, hole: .zero)
            }

        case .veil:
            if veilImage == nil { veilImage = advancedGenerator.veilTile() }
            windows.values.forEach {
                $0.setSecurityLayers(tint: nil, texture: veilImage,
                                     blendMode: nil, opacity: securityOpacity())
                $0.setSpotlight(active: false, hole: .zero)
            }

        case .flicker:
            windows.values.forEach {
                $0.setSecurityLayers(tint: nil, texture: nil, blendMode: nil, opacity: 0)
                $0.setSpotlight(active: false, hole: .zero)
            }
            startFlicker()

        case .spotlight:
            windows.values.forEach {
                $0.setSecurityLayers(tint: nil, texture: nil, blendMode: nil, opacity: 0)
            }
            SpotlightTracker.shared.start()
        }
    }

    func setTexture(_ texture: PaperTexture) {
        let tile = generator.generateTile(for: texture)
        windows.values.forEach { window in
            window.setTexture(tile)
            window.configure(with: texture, opacity: CGFloat(settings.opacity))
        }
    }

    // MARK: - State

    /// Bundle IDs excluded from the overlay entirely (paper AND shield).
    @Published var excludedApps: Set<String> = [] {
        didSet {
            UserDefaults.standard.set(Array(excludedApps).sorted(), forKey: "excludedApps")
            applyState()
        }
    }

    let focusedApp = FocusedAppMonitor()

    private let settings: PaperSettings
    private var windows: [String: PaperOverlayWindow] = [:]   // displayID -> window
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
            .sink { [weak self] _ in self?.applyState() }
            .store(in: &cancellables)

        // Paper internals
        settings.$opacity
            .sink { [weak self] value in
                self?.windows.values.forEach { $0.setOpacity(CGFloat(value)) }
            }
            .store(in: &cancellables)
        settings.$texture
            .receive(on: RunLoop.main)
            .sink { [weak self] texture in self?.setTexture(texture) }
            .store(in: &cancellables)

        // Masters & shield params -> one funnel
        settings.$paperEnabled
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.applyState() }
            .store(in: &cancellables)
        settings.$securityEnabled
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.applyState() }
            .store(in: &cancellables)
        settings.$securityTechnique
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.applyState() }
            .store(in: &cancellables)
        settings.$securityStrength
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.applyState() }
            .store(in: &cancellables)

        rebuild()
    }

    // MARK: - Helpers

    private func securityOpacity() -> CGFloat {
        CGFloat(settings.securityTechnique.baseOpacity * settings.securityStrength)
    }

    private func screenForDisplayID(_ id: String) -> NSScreen? {
        NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? Int)
                .map(String.init) == id
        }
    }

    // MARK: - Flicker

    private func startFlicker() {
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

    private func flickerTick() {
        let amplitude = 0.5 * settings.securityStrength + 0.1
        let frame = advancedGenerator.flickerFrame(amplitude: CGFloat(amplitude))
        windows.values.forEach {
            $0.setSecurityLayers(tint: nil, texture: frame,
                                 blendMode: nil, opacity: securityOpacity())
           $0.setSpotlight(active: false, hole: .zero)
        }
    }

    // MARK: - Spotlight pump

    private func startSpotlightPump() {
        SpotlightTracker.shared.$spotlightRect
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateSpotlightHole() }
            .store(in: &spotlightCancellables)
        SpotlightTracker.shared.$faceVisible
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateSpotlightHole() }
            .store(in: &spotlightCancellables)
    }

    private var spotlightCancellables = Set<AnyCancellable>()
    private var spotlightPumpStarted = false

    private func updateSpotlightHole() {
        guard settings.securityEnabled,
              settings.securityTechnique == .spotlight else { return }

        let hole = SpotlightTracker.shared.spotlightRect

        if SpotlightTracker.shared.faceVisible {
            windows.values.forEach {
                $0.setSecurityLayers(tint: nil, texture: nil, blendMode: nil, opacity: 0)
                var local = hole
                local.origin.x -= $0.frame.minX
                local.origin.y -= $0.frame.minY
                $0.setSpotlight(active: true, hole: local)
            }
        } else {
            // No face: dim veil fallback so the shield never looks "off"
            if veilImage == nil { veilImage = advancedGenerator.veilTile() }
            windows.values.forEach {
                $0.setSpotlight(active: false, hole: .zero)
                $0.setSecurityLayers(tint: nil, texture: veilImage,
                                     blendMode: nil, opacity: 0.5)
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
            // Key by stable CGDirectDisplayID, NOT screen.hash
            if let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? Int {
                windows[String(displayID)] = w
            }
        }
        if !spotlightPumpStarted {
            startSpotlightPump()
            spotlightPumpStarted = true
        }
        applyState()
    }

    func setOpacity(_ value: CGFloat) {
        windows.values.forEach { $0.setOpacity(value) }
    }
}