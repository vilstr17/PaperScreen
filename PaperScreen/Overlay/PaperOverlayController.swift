import AppKit
import Combine

final class PaperOverlayController: ObservableObject {

    // MARK: - Single source of truth

    /// One authoritative pass: window visibility + paper layers +
    /// shield layers. Every state change funnels through here.
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

        applyShield()
    }

    /// Manages the cursor-follow blur shield (the single technique).
    private func applyShield() {
        for win in blurShields.values { win.orderOut(nil) }
        blurShields.removeAll()
        cursorCancellables.removeAll()
        CursorMonitor.shared.stop()

        guard settings.securityEnabled else { return }

        for screen in NSScreen.screens {
            let win = BlurShieldWindow(screen: screen)
            win.orderFrontRegardless()
            let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? Int)
                .map(String.init) ?? UUID().uuidString
            blurShields[id] = win
        }

        // Start cursor feed and place the hole immediately
        CursorMonitor.shared.start()
        CursorMonitor.shared.$globalPosition
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateBlurHoles() }
            .store(in: &cursorCancellables)
        updateBlurHoles()
    }

    // MARK: - Blur shield

    private var blurShields: [String: BlurShieldWindow] = [:]
    private var cursorCancellables = Set<AnyCancellable>()

    private func updateBlurHoles() {
        guard settings.securityEnabled, !blurShields.isEmpty else { return }
        let global = CursorMonitor.shared.globalPosition

        for (id, win) in blurShields {
            guard let screen = screenForDisplayID(id) else { continue }
            let sf = screen.frame
            // global (bottom-left origin) -> window local (top-left origin)
            let localX = global.x - sf.minX
            let localY = sf.maxY - global.y
            let onScreen = global.x >= 0 && sf.contains(global)
            win.holeCenter = onScreen
                ? CGPoint(x: localX, y: localY)
                : CGPoint(x: -10000, y: -10000)
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

    private var cancellables = Set<AnyCancellable>()

    init(settings: PaperSettings) {
        self.settings = settings

        let d = UserDefaults.standard
        excludedApps = Set(d.stringArray(forKey: "excludedApps") ?? [])
        // Old persisted values from removed techniques fall back
        if SecurityTechnique(rawValue: UserDefaults.standard.string(forKey: "securityTechnique") ?? "") == nil {
            settings.securityTechnique = .spotlightFollow
        }

        focusedApp.$frontBundleID
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyState()
                self?.updateBlurHoles()
            }
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
        settings.$securityStrength
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateBlurRadius() }
            .store(in: &cancellables)

        rebuild()
    }

    // MARK: Helpers

    /// Strength slider maps to hole size: 10% -> small, 100% -> huge.
    private func updateBlurRadius() {
        let r = 60 + CGFloat(settings.securityStrength) * 260
        for win in blurShields.values { win.holeRadius = r }
    }

    private func screenForDisplayID(_ id: String) -> NSScreen? {
        NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? Int)
                .map(String.init) == id
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
            if let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? Int {
                windows[String(displayID)] = w
            }
        }
        applyState()
    }

    func setOpacity(_ value: CGFloat) {
        windows.values.forEach { $0.setOpacity(value) }
    }
}