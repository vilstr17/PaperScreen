import AppKit
import AVFoundation
import Vision

/// Black sheet with a rectangular cut-out ("spotlight") that follows
/// the user's face. Front camera + Vision face detection, ~2 Hz.
///
/// Mapping: face position in the camera frame is amplified (gain 2.2)
/// around the frame center and low-pass smoothed, so natural head
/// movement sweeps the hole across the whole screen. When the face is
/// lost the hole holds its last position for a grace period, then
/// parks in the screen center. Camera denied -> static centered hole.
final class SpotlightTracker: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    static let shared = SpotlightTracker()

    /// Spotlight hole in *screen coordinates* (AppKit, bottom-left origin).
    @Published var spotlightRect: NSRect = .zero
    /// True while the hole should sit dead center (camera denied or no face yet).
    @Published var parked = true
    /// Camera permission was explicitly refused.
    @Published var cameraDenied = false
    /// Face currently tracked.
    @Published var faceVisible = false

    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "paperscreen.spotlight", qos: .utility)
    private var lastDetection = Date.distantPast
    private var lastFaceSeen = Date.distantPast

    /// Amplification of head movement (1.0 = mirror camera frame 1:1).
    private let gain: CGFloat = 2.2
    /// Low-pass factor: higher = snappier, lower = smoother.
    private let smoothing: CGFloat = 0.35
    /// Keep following the last position this long after the face vanishes.
    private let gracePeriod: TimeInterval = 2.5

    /// Minimum interval between Vision passes (2 Hz).
    private let detectionInterval: TimeInterval = 0.5

    /// Spotlight hole size in points.
    private let holeSize = CGSize(width: 620, height: 440)

    private var centeredHole: NSRect {
        guard let screen = NSScreen.main else { return .zero }
        let c = screen.frame
        return NSRect(
            x: c.midX - holeSize.width / 2,
            y: c.midY - holeSize.height / 2 + 30,
            width: holeSize.width,
            height: holeSize.height
        )
    }

    private var running = false

    func start() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.start()
                    } else {
                        self?.cameraDenied = true
                        self?.parkHole()
                    }
                }
            }
            return
        default:
            DispatchQueue.main.async {
                self.cameraDenied = true
                self.parkHole()
            }
            return
        }

        guard session.outputs.isEmpty else { return }

        session.beginConfiguration()
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            return
        }
        session.addOutput(output)
        session.commitConfiguration()

        DispatchQueue.main.async {
            self.cameraDenied = false
        }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.session.startRunning()
        }
        parkHole()
    }

    func stop() {
        queue.async { [weak self] in
            self?.session.stopRunning()
        }
        DispatchQueue.main.async {
            self.faceVisible = false
        }
    }

    /// Put the hole in the screen center (also the "parked" position).
    private func parkHole() {
        parked = true
        spotlightRect = centeredHole
    }

    // MARK: - Frame processing

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard Date().timeIntervalSince(lastDetection) >= detectionInterval else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        lastDetection = Date()

        let request = VNDetectFaceRectanglesRequest { [weak self] req, _ in
            self?.handleFaces(req)
        }
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .leftMirrored)
        try? handler.perform([request])
    }

    private func handleFaces(_ request: VNRequest) {
        guard let results = request.results as? [VNFaceObservation] else { return }

        guard let face = results.max(by: { $0.boundingBox.width < $1.boundingBox.width }) else {
            // Grace period: hold last position briefly before parking
            if Date().timeIntervalSince(lastFaceSeen) > gracePeriod {
                DispatchQueue.main.async {
                    self.faceVisible = false
                    self.parkHole()
                }
            }
            return
        }

        lastFaceSeen = Date()

        DispatchQueue.main.async {
            self.faceVisible = true
            self.parked = false
            self.moveToward(self.screenHole(for: face.boundingBox))
        }
    }

    /// Amplified face position -> screen hole rect.
    private func screenHole(for face: CGRect) -> NSRect {
        guard let screen = NSScreen.main else { return .zero }
        let sf = screen.frame

        // Amplify around camera-frame center so a natural range of head
        // positions covers the whole screen.
        var nx = 0.5 + (face.midX - 0.5) * gain
        var ny = 0.5 + (face.midY - 0.5) * gain
        nx = min(0.92, max(0.08, nx))
        ny = min(0.92, max(0.08, ny))

        let cx = sf.minX + CGFloat(nx) * sf.width
        let cy = sf.minY + CGFloat(ny) * sf.height

        return NSRect(
            x: cx - holeSize.width / 2,
            y: cy - holeSize.height / 2 + 30,
            width: holeSize.width,
            height: holeSize.height
        )
    }

    /// Low-pass filter so the hole glides instead of jumping.
    private func moveToward(_ target: NSRect) {
        if parked || spotlightRect.isEmpty {
            spotlightRect = target
            parked = false
            return
        }
        let a = smoothing
        let ox = spotlightRect.origin.x + (target.origin.x - spotlightRect.origin.x) * a
        let oy = spotlightRect.origin.y + (target.origin.y - spotlightRect.origin.y) * a
        spotlightRect = NSRect(origin: NSPoint(x: ox, y: oy), size: holeSize)
    }
}