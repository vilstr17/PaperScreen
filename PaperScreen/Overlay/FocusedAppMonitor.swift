import AppKit
import Combine

/// Tracks the frontmost app so the overlay can exclude specific apps.
/// Uses NSWorkspace notifications plus a light polling fallback —
/// no Apple Events, no Accessibility permission needed.
final class FocusedAppMonitor: ObservableObject {
    @Published private(set) var frontAppName: String? = nil
    @Published private(set) var frontBundleID: String? = nil

    private var observer: NSObjectProtocol?
    private var timer: Timer?

    init() {
        refresh()

        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }

        // Fallback poll in case notifications are missed
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    deinit {
        if let observer = observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        timer?.invalidate()
    }

    func refresh() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }

        // Skip ourselves — while our menu-bar menu is open, PaperScreen
        // is "frontmost", and the toggle should target the app underneath.
        if app.bundleIdentifier == Bundle.main.bundleIdentifier { return }

        let name = app.localizedName?.lowercased()
        let bid = app.bundleIdentifier

        if name != frontAppName || bid != frontBundleID {
            frontAppName = name
            frontBundleID = bid
        }
    }
}