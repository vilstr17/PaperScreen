import AppKit
import AVFoundation
import Vision

/// Black sheet with a rectangular cut-out ("spotlight") that follows
/// the user's face. Front camera + Vision face detection, ~2 Hz
/// (Neural Engine class workload, negligible load).
final class SpotlightTracker: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    static let shared = SpotlightTracker()

    /// Spotlight hole in *screen coordinates* (AppKit, bottom-left origin).
    @Published var spotlightRect: NSRect = .zero
    @Published var faceVisible = false

    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "paperscreen.spotlight", qos: .utility)
    private var lastDetection = Date.distantPast
    private let context = CIContext(options: [.useSoftwareRenderer: false])

    /// Minimum interval between Vision passes (2 Hz).
    private let detectionInterval: TimeInterval = 0.5

    /// Spotlight hole size in points.
    private let holeSize = CGSize(width: 560, height: 400)

    private var cameraAuthorized: Bool {
        AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    func start() {
        guard cameraAuthorized else {
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async { self?.start() }
                }
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

        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.session.startRunning()
        }
    }

    func stop() {
        queue.async { [weak self] in
            self?.session.stopRunning()
        }
        DispatchQueue.main.async {
            self.faceVisible = false
        }
    }

    // MARK: - Frame processing

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        // Throttle: only run Vision every 0.5 s
        guard Date().timeIntervalSince(lastDetection) >= detectionInterval else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        lastDetection = Date()

        let request = VNDetectFaceRectanglesRequest { [weak self] req, _ in
            self?.handleFaces(req)
        }
        request.preferBackgroundProcessing = false

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .leftMirrored)
        try? handler.perform([request])
    }

    private func handleFaces(_ request: VNRequest) {
        guard let results = request.results as? [VNFaceObservation] else { return }

        guard let face = results.max(by: { $0.boundingBox.width < $1.boundingBox.width }) else {
            DispatchQueue.main.async { self.faceVisible = false }
            return
        }

        DispatchQueue.main.async {
            self.faceVisible = true
            self.spotlightRect = self.screenHole(for: face.boundingBox)
        }
    }

    /// Map normalized camera face box -> screen hole rect.
    /// Front camera with .leftMirrored: face moving right in the camera
    /// view moves the user right in front of the screen, so normalized
    /// x maps 1:1; vertical: camera y-up aligns with AppKit y-up.
    private func screenHole(for face: CGRect) -> NSRect {
        guard let screen = NSScreen.main else { return .zero }
        let sf = screen.frame

        let cx = sf.minX + (face.midX) * sf.width
        let cy = sf.minY + (face.midY) * sf.height

        return NSRect(
            x: cx - holeSize.width / 2,
            y: cy - holeSize.height / 2 + 30,   // bias up: eyes sit above face center
            width: holeSize.width,
            height: holeSize.height
        )
    }
}