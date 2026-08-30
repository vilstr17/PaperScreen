import AppKit
import Combine

final class PaperOverlayController: ObservableObject {

    /// One authoritative pass: window visibility + paper layers.
    private func applyState() {
        let paperOn = settings.paperEnabled
        let excluded = excludedApps.contains(focusedApp.frontBundleID ?? "")
        for window in windows.values {
            if paperOn && !excluded {
                window.orderFrontRegardless()
            } else {
                window.orderOut(nil)
            }
            window.setPaperVisible(paperOn)
        }
    }

    func setTexture(_ texture: PaperTexture) {
        let tile = generator.generateTile(for: texture)
        windows.values.forEach { window in
            window.setTexture(tile)
            window.configure(with: texture, opacity: CGFloat(settings.opacity))
        }
    }

    /// Bundle IDs excluded from the overlay.
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

        focusedApp.$frontBundleID
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.applyState() }
            .store(in: &cancellables)

        settings.$opacity
            .sink { [weak self] value in
                self?.windows.values.forEach { $0.setOpacity(CGFloat(value)) }
            }
            .store(in: &cancellables)
        settings.$texture
            .receive(on: RunLoop.main)
            .sink { [weak self] texture in self?.setTexture(texture) }
            .store(in: &cancellables)
        settings.$paperEnabled
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.applyState() }
            .store(in: &cancellables)

        rebuild()
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