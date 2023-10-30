import Foundation
import SoraFoundation
import CommonWallet
import RobinHood
import AVFoundation
import SSFUtils

enum ScanState {
    case initializing(accessRequested: Bool)
    case inactive
    case active
    case processing(receiverInfo: ReceiveInfo, operation: CancellableCall)
    case failed(code: String)
}

enum ScanFinish {
    case address(String)
    case sora(SoraQRInfo)

    // this cases for solomon island qr codes. Will be use just one case, unused case must be removed
    case solomonAddress(String) // perhaps will be removed
    case bokoloCash(BokoloCashQRInfo) // priority

    var address: String {
        switch self {
        case let .address(address):
            return address
        case let .solomonAddress(address):
            return address
        case let .sora(soraQRInfo):
            return soraQRInfo.address
        case let .bokoloCash(bokoloQrInfo):
            return bokoloQrInfo.address
        }
    }
}

final class ScanQRPresenter: NSObject {
    let localizationManager: LocalizationManagerProtocol?

    // MARK: Private properties

    private weak var view: ScanQRViewInput?
    private weak var moduleOutput: ScanQRModuleOutput?

    private let router: ScanQRRouterInput
    private let interactor: ScanQRInteractorInput
    private let matchers: [QRMatcherProtocol]
    private let logger: LoggerProtocol

    private var scanState: ScanState = .initializing(accessRequested: false)

    // MARK: - Constructors

    init(
        interactor: ScanQRInteractorInput,
        router: ScanQRRouterInput,
        logger: LoggerProtocol,
        moduleOutput: ScanQRModuleOutput?,
        matchers: [QRMatcherProtocol],
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.logger = logger
        self.matchers = matchers
        self.moduleOutput = moduleOutput

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

    private func didCompleteImageSelection(with selectedImages: [UIImage]) {
        if let image = selectedImages.first {
            interactor.extractQr(from: image)
        }
    }

    private func searchMetcher(code: String) {
        let qrMatcherTypes = matchers.map { $0.match(code: code) }.compactMap { $0 }
        if qrMatcherTypes.isEmpty {
            DispatchQueue.main.async {
                let viewModel = SheetAlertPresentableViewModel(
                    title: R.string.localizable.otpErrorMessageWrongCode(
                        preferredLanguages: self.selectedLocale.rLanguages
                    ),
                    message: nil,
                    actions: [],
                    closeAction: nil,
                    dismissCompletion: { [weak self] in
                        self?.scanState = .initializing(accessRequested: true)
                        self?.interactor.startScanning()
                    }
                )
                self.router.present(viewModel: viewModel, from: self.view)
            }
        }
        guard
            qrMatcherTypes.count == 1,
            let qrType = qrMatcherTypes.first
        else {
            logger.error("QR must have one matching")
            return
        }

        DispatchQueue.main.async {
            self.router.close(view: self.view) { [weak self] in
                self?.moduleOutput?.didFinishWith(scanType: qrType)
            }
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
    func handleMatched(code: String) {
        searchMetcher(code: code)
    }

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
}

extension ScanQRPresenter: QRCaptureServiceDelegate {
    func qrCapture(service _: QRCaptureServiceProtocol, didSetup captureSession: AVCaptureSession) {
        DispatchQueue.main.async {
            self.handleReceived(captureSession: captureSession)
        }
    }

    func qrCapture(service _: QRCaptureServiceProtocol, didMatch code: String) {
        searchMetcher(code: code)
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
