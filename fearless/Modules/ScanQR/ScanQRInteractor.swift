import UIKit
import SSFQRService

final class ScanQRInteractor {
    // MARK: - Private properties

    private weak var output: ScanQRInteractorOutput?
    private let qrService: WalletQRService
    private let cameraStateLock = NSLock()
    private var cameraGeneration: UUID? = UUID()
    private let qrScanService: QRCaptureServiceProtocol

    init(
        qrService: QRService,
        qrScanService: QRCaptureServiceProtocol
    ) {
        self.qrService = (qrService as? WalletQRService) ?? WalletQRService(standard: qrService)
        self.qrScanService = qrScanService
    }

    private func currentCameraGeneration() -> UUID? {
        cameraStateLock.lock()
        defer { cameraStateLock.unlock() }
        return cameraGeneration
    }

    private func replaceCameraGeneration(_ generation: UUID?) {
        cameraStateLock.lock()
        cameraGeneration = generation
        cameraStateLock.unlock()
    }

    private func consumeCameraGeneration(_ generation: UUID) -> Bool {
        cameraStateLock.lock()
        defer { cameraStateLock.unlock() }
        guard cameraGeneration == generation else { return false }
        cameraGeneration = nil
        return true
    }

    private func matchCameraCode(_ code: String, generation: UUID) {
        guard currentCameraGeneration() == generation else { return }
        do {
            let matcher = try qrService.extractQrCode(from: code)
            guard consumeCameraGeneration(generation) else { return }
            qrScanService.stop()
            output?.didReceive(matcher: matcher)
        } catch {
            guard currentCameraGeneration() == generation else { return }
            output?.handleQRService(error: error)
        }
    }
}

// MARK: - ScanQRInteractorInput

extension ScanQRInteractor: ScanQRInteractorInput {
    func setup(with output: ScanQRInteractorOutput & QRCaptureServiceDelegate) {
        self.output = output
        qrScanService.delegate = output
    }

    func extractQr(from image: UIImage) {
        do {
            let matcher = try qrService.extractQrCode(from: image)
            output?.didReceive(matcher: matcher)
        } catch {
            output?.handleQRService(error: error)
        }
    }

    func lookingMatcher(for code: String) {
        // Capture identity before hopping queues: a frame already delivered by
        // the capture service must not join a later stop/start cycle.
        guard let generation = currentCameraGeneration() else { return }
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.matchCameraCode(code, generation: generation) }
            return
        }
        matchCameraCode(code, generation: generation)
    }

    func startScanning() {
        replaceCameraGeneration(UUID())
        qrScanService.start()
    }

    func stopScanning() {
        replaceCameraGeneration(nil)
        qrScanService.stop()
    }
}
