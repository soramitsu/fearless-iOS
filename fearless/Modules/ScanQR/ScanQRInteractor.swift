import UIKit
import CommonWallet

final class ScanQRInteractor {
    // MARK: - Private properties

    private weak var output: ScanQRInteractorOutput?
    private let qrExtractionService: QRExtractionServiceProtocol
    private let qrScanService: QRCaptureServiceProtocol

    init(
        qrExtractionService: QRExtractionServiceProtocol,
        qrScanService: QRCaptureServiceProtocol
    ) {
        self.qrExtractionService = qrExtractionService
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
        qrExtractionService.extract(
            from: image,
            dispatchCompletionIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(code):
                self?.output?.handleMatched(code: code)
            case let .failure(error):
                self?.output?.handleQRService(error: error)
            }
        }
    }

    func startScanning() {
        qrScanService.start()
    }

    func stopScanning() {
        qrScanService.stop()
    }
}
