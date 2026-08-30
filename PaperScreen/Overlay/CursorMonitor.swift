import AppKit
import CoreGraphics

/// Follows the global mouse cursor and reports its position in each
/// screen's local coordinate space. Pure CGEvent tap-free polling of
/// NSEvent.addGlobalMonitorForEvents — no permissions needed for
/// mouse-moved monitoring when the app has accessibility OFF (global
/// monitors for .mouseMoved require Input Monitoring on newer macOS,
/// so we also fall back to CGEvent polling via CoreGraphics).
final class CursorMonitor: ObservableObject {

    static let shared = CursorMonitor()

    /// Global cursor position (screen coordinates, bottom-left origin).
    @Published var globalPosition: CGPoint = CGPoint(x: -1, y: -1)

    private var monitor: Any?
    private var pollTimer: Timer?
    private var lastSample = CGPoint.zero
    /// Poll rate for the fallback path (60 Hz, trivially cheap).
    private let pollInterval: TimeInterval = 1.0 / 60.0

    func start() {
        guard monitor == nil, pollTimer == nil else { return }

        // Primary: event monitor (needs Input Monitoring permission on
        // macOS 10.15+; silently no-ops if not granted).
        monitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .otherMouseDragged]
        ) { [weak self] event in
            DispatchQueue.main.async {
                self?.globalPosition = NSEvent.mouseLocation
            }
        }

        // Fallback poll: CGEvent based, always works, negligible cost.
        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            let pos = NSEvent.mouseLocation
            if pos != self?.globalPosition {
                self?.globalPosition = pos
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer

        globalPosition = NSEvent.mouseLocation
    }

    func stop() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        pollTimer?.invalidate()
        pollTimer = nil
    }
}