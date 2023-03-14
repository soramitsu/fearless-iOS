import UIKit
import CommonWallet

final class ScanQRInteractor {
    // MARK: - Private properties

    private weak var output: ScanQRInteractorOutput?
    private let qrDecoder: QRDecoderProtocol
    private let qrExtractionService: QRExtractionServiceProtocol
    private let qrScanService: QRCaptureServiceProtocol

    init(
        qrDecoder: QRDecoderProtocol,
        qrExtractionService: QRExtractionServiceProtocol,
        qrScanService: QRCaptureServiceProtocol
    ) {
        self.qrDecoder = qrDecoder
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
        let matcher = QRScanMatcher(decoder: qrDecoder)

        qrExtractionService.extract(
            from: image,
            using: matcher,
            dispatchCompletionIn: .main
        ) { [weak self] result in
            switch result {
            case .success:
                if let addressInfo = matcher.qrInfo {
                    self?.output?.handleMatched(addressInfo: addressInfo)
                }
            case let .failure(error):
                if case let QRExtractionServiceError.plainAddress(address) = error {
                    self?.output?.handleAddress(address)
                    return
                }

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
