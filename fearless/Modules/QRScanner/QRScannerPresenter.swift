import Foundation
import AVFoundation

final class QRScannerPresenter {
    weak var view: QRScannerViewProtocol?
    let wireframe: QRScannerWireframeProtocol

    let qrScanService: QRCaptureServiceProtocol
    let logger: LoggerProtocol?

    init(
        wireframe: QRScannerWireframeProtocol,
        qrScanService: QRCaptureServiceProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.wireframe = wireframe
        self.qrScanService = qrScanService
        self.logger = logger

        self.qrScanService.delegate = self
    }

    deinit {
        qrScanService.stop()
    }

    private func handleQRService(error: Error) {
        if let captureError = error as? QRCaptureServiceError {
            handleQRCaptureService(error: captureError)
        } else {
            logger?.error("Unexpected qr service error \(error)")
        }
    }

    private func handleQRCaptureService(error: QRCaptureServiceError) {
        guard let view = view else {
            return
        }

        let locale = view.selectedLocale
        switch error {
        case .deviceAccessRestricted:
            view.present(
                message: R.string.localizable.qrScanErrorCameraTitle(preferredLanguages: locale.rLanguages),
                animated: true
            )
        case .deviceAccessDeniedPreviously:
            let message = R.string.localizable.qrScanErrorCameraRestricted(preferredLanguages: locale.rLanguages)
            let title = R.string.localizable.qrScanErrorCameraTitle(preferredLanguages: locale.rLanguages)
            wireframe.askOpenApplicationSettings(with: message, title: title, from: view, locale: locale)
        default:
            break
        }
    }

    private func handleCompletion() {
        wireframe.close(view: view)
    }

    private func handleMatchingFailure() {
        let message = R.string.localizable.qrScanErrorExtractFail(preferredLanguages: view?.selectedLocale.rLanguages)
        view?.present(message: message, animated: true)
    }
}

extension QRScannerPresenter: QRScannerPresenterProtocol {
    func setup() {
        qrScanService.start()
    }
}

extension QRScannerPresenter: QRCaptureServiceDelegate {
    func qrCapture(service _: QRCaptureServiceProtocol, didSetup captureSession: AVCaptureSession) {
        DispatchQueue.main.async {
            self.view?.didReceive(session: captureSession)
        }
    }

    func qrCapture(service _: QRCaptureServiceProtocol, didMatch _: String) {
        DispatchQueue.main.async {
            self.handleCompletion()
        }
    }

    func qrCapture(service _: QRCaptureServiceProtocol, didFailMatching _: String) {
        DispatchQueue.main.async {
            self.handleMatchingFailure()
        }
    }

    func qrCapture(service _: QRCaptureServiceProtocol, didReceive error: Error) {
        DispatchQueue.main.async {
            self.handleQRService(error: error)
        }
    }
}
