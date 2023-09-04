import Foundation
import SoraFoundation
import CommonWallet
import RobinHood
import AVFoundation
import SSFUtils

final class ScanQRPresenter: NSObject {
    enum ScanState {
        case initializing(accessRequested: Bool)
        case inactive
        case active
        case processing(receiverInfo: ReceiveInfo, operation: CancellableCall)
        case failed(code: String)
    }

    let localizationManager: LocalizationManagerProtocol?

    // MARK: Private properties

    private weak var view: ScanQRViewInput?
    private weak var moduleOutput: ScanQRModuleOutput?

    private let router: ScanQRRouterInput
    private let interactor: ScanQRInteractorInput
    private let qrScanMatcher: QRScanMatcher
    private let qrUriMatcher: QRUriMatcher
    private let logger: LoggerProtocol
    private let qrScanService: QRCaptureServiceProtocol

    private var scanState: ScanState = .initializing(accessRequested: false)

    // MARK: - Constructors

    init(
        interactor: ScanQRInteractorInput,
        router: ScanQRRouterInput,
        logger: LoggerProtocol,
        moduleOutput: ScanQRModuleOutput?,
        qrScanMatcher: QRScanMatcher,
        qrUriMatcher: QRUriMatcher,
        qrScanService: QRCaptureServiceProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.logger = logger
        self.qrScanMatcher = qrScanMatcher
        self.qrUriMatcher = qrUriMatcher
        self.moduleOutput = moduleOutput
        self.qrScanService = qrScanService

        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func handleQRCaptureService(error: QRCaptureServiceError) {
        guard case let .initializing(alreadyAskedAccess) = scanState, !alreadyAskedAccess else {
            logger.warning("Requested to ask access but already done earlier")
            return
        }

        scanState = .initializing(accessRequested: true)

        switch error {
        case .deviceAccessRestricted:
            view?.present(message: L10n.InvoiceScan.Error.cameraRestricted, animated: true)
        case .deviceAccessDeniedPreviously:
            let message = L10n.InvoiceScan.Error.cameraRestrictedPreviously
            let title = L10n.InvoiceScan.Error.cameraTitle
            router.askOpenApplicationSettings(with: message, title: title, from: view)
        case .deviceAccessDeniedNow:
            break
        }
    }

    private func handleQRExtractionService(error: QRExtractionServiceError) {
        switch error {
        case .noFeatures:
            view?.present(message: L10n.InvoiceScan.Error.noInfo, animated: true)
        case .detectorUnavailable, .invalidImage:
            view?.present(message: L10n.InvoiceScan.Error.invalidImage, animated: true)
        case .plainAddress:
            break
        }
    }

    private func handleImageGallery(error: ImageGalleryError) {
        switch error {
        case .accessRestricted:
            view?.present(message: L10n.InvoiceScan.Error.galleryRestricted, animated: true)
        case .accessDeniedPreviously:
            let message = L10n.InvoiceScan.Error.galleryRestrictedPreviously
            let title = L10n.InvoiceScan.Error.galleryTitle
            router.askOpenApplicationSettings(with: message, title: title, from: view)
        case .accessDeniedNow, .unknownAuthorizationStatus:
            break
        }
    }

    private func handleReceived(captureSession: AVCaptureSession) {
        if case .initializing = scanState {
            scanState = .active

            view?.didReceive(session: captureSession)
        }
    }

    private func handleFailedMatching(for code: String) {
        router.close(view: view) { [weak self] in
            self?.moduleOutput?.didFinishWith(address: code)
        }
    }

    private func didCompleteImageSelection(with selectedImages: [UIImage]) {
        if let image = selectedImages.first {
            interactor.extractQr(from: image)
        }
    }

    private func handleConnect(uri: String) {
        router.close(view: view) { [weak self] in
            self?.moduleOutput?.didFinishWithConnect(uri: uri)
        }
    }
}

// MARK: - ScanQRViewOutput

extension ScanQRPresenter: ScanQRViewOutput {
    func didLoad(view: ScanQRViewInput) {
        self.view = view
        interactor.setup(with: self)
    }

    func prepareAppearance() {
        interactor.startScanning()
    }

    func handleAppearance() {
        if case .inactive = scanState {
            scanState = .active
        }
    }

    func prepareDismiss() {
        if case .initializing = scanState {
            return
        }

        if case let .processing(_, operation) = scanState {
            operation.cancel()
        }

        scanState = .inactive
    }

    func handleDismiss() {
        interactor.stopScanning()
    }

    func activateImport() {
        router.presentImageGallery(
            from: view,
            delegate: self,
            pickerDelegate: self
        )
    }

    func didTapBackButton() {
        router.dismiss(view: view)
    }
}

// MARK: - ScanQRInteractorOutput

extension ScanQRPresenter: ScanQRInteractorOutput {
    func handleQRService(error: Error) {
        if let captureError = error as? QRCaptureServiceError {
            handleQRCaptureService(error: captureError)
            return
        }

        if let extractionError = error as? QRExtractionServiceError {
            handleQRExtractionService(error: extractionError)
            return
        }

        if let imageGalleryError = error as? ImageGalleryError {
            handleImageGallery(error: imageGalleryError)
        }

        logger.error("Unexpected qr service error \(error)")
    }

    func handleMatched(addressInfo: QRInfo) {
        router.close(view: view) { [weak self] in
            self?.moduleOutput?.didFinishWith(address: addressInfo.address)
        }
    }

    func handleAddress(_ address: String) {
        DispatchQueue.main.async { [weak self] in
            self?.router.close(view: self?.view) {
                self?.moduleOutput?.didFinishWith(address: address)
            }
        }
    }

    func handleMatched(connect: URL) {
        handleConnect(uri: connect.absoluteString)
    }
}

extension ScanQRPresenter: QRCaptureServiceDelegate {
    func qrCapture(service _: QRCaptureServiceProtocol, didSetup captureSession: AVCaptureSession) {
        DispatchQueue.main.async {
            self.handleReceived(captureSession: captureSession)
        }
    }

    func qrCapture(service _: QRCaptureServiceProtocol, didMatch _: String) {
        if let connectUrl = qrUriMatcher.url {
            DispatchQueue.main.async {
                self.handleConnect(uri: connectUrl.absoluteString)
            }
            return
        }

        guard let addressInfo = qrScanMatcher.qrInfo else {
            logger.warning("Can't find receiver's info for matched code")
            return
        }

        DispatchQueue.main.async {
            self.handleMatched(addressInfo: addressInfo)
        }
    }

    func qrCapture(service _: QRCaptureServiceProtocol, didFailMatching code: String) {
        DispatchQueue.main.async {
            self.handleFailedMatching(for: code)
        }
    }

    func qrCapture(service _: QRCaptureServiceProtocol, didReceive error: Error) {
        DispatchQueue.main.async {
            self.handleQRService(error: error)
        }
    }
}

extension ScanQRPresenter: ImageGalleryDelegate {
    func didCompleteImageSelection(
        from _: ImageGalleryPresentable,
        with selectedImages: [UIImage]
    ) {
        if let image = selectedImages.first {
            interactor.extractQr(from: image)
        }
    }

    func didFail(in _: ImageGalleryPresentable, with error: Error) {
        handleQRService(error: error)
    }
}

extension ScanQRPresenter: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    @objc func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        picker.presentingViewController?.dismiss(animated: true, completion: nil)
        if let originalImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
            didCompleteImageSelection(with: [originalImage])
        } else {
            didCompleteImageSelection(with: [])
        }
    }

    @objc func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.presentingViewController?.dismiss(animated: true, completion: nil)
        didCompleteImageSelection(with: [])
    }
}

// MARK: - Localizable

extension ScanQRPresenter: Localizable {
    func applyLocalization() {}
}

extension ScanQRPresenter: ScanQRModuleInput {}
