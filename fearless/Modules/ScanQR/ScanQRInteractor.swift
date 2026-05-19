import UIKit
import SSFQRService

final class ScanQRInteractor {
    // MARK: - Private properties

    private weak var output: ScanQRInteractorOutput?
    private let qrService: QRService
    private let qrScanService: QRCaptureServiceProtocol

    init(
        qrService: QRService,
        qrScanService: QRCaptureServiceProtocol
    ) {
        self.qrService = qrService
        self.qrScanService = qrScanService
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
        if let url = URL(string: code), url.scheme == "ws" {
            output?.didReceive(matcher: .walletConnect(code))
            return
        }

        output?.handleQRService(error: QRDecoderError.brokenFormat)
    }

    func startScanning() {
        qrScanService.start()
    }

    func stopScanning() {
        qrScanService.stop()
    }
}
