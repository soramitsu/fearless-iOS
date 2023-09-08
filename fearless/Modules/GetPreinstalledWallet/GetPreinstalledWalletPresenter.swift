import Foundation
import SoraFoundation
import AVFoundation
import CommonWallet
import SSFUtils

final class GetPreinstalledWalletPresenter: NSObject {
    // MARK: Private properties

    private weak var view: ScanQRViewInput?
    private let router: GetPreinstalledWalletRouterInput
    private let interactor: GetPreinstalledWalletInteractorInput
    private let logger: LoggerProtocol
    private let qrScanMatcher: QRScanMatcher
    private var scanState: ScanState = .initializing(accessRequested: false)
    private var processingIsActive: Bool = false

    // MARK: - Constructors

    init(
        interactor: GetPreinstalledWalletInteractorInput,
        router: GetPreinstalledWalletRouterInput,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol,
        qrScanMatcher: QRScanMatcher
    ) {
        self.interactor = interactor
        self.router = router
        self.logger = logger
        self.qrScanMatcher = qrScanMatcher
        super.init()
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func handle(qrString: String) {
        guard !processingIsActive else {
            return
        }

        processingIsActive = true

        guard
            let mnemonicData = try? Data(hexStringSSF: qrString),
            let mnemonicString = mnemonicData.toUTF8String(),
            let mnemonic = interactor.createMnemonicFromString(mnemonicString)
        else {
            DispatchQueue.main.async { [weak self] in
                self?.didReceiveAccountImport(error: AccountCreateError.invalidMnemonicFormat)
            }

            return
        }
        let sourceData = MetaAccountImportRequestSource.MnemonicImportRequestData(
            mnemonic: mnemonic,
            substrateDerivationPath: "",
            ethereumDerivationPath: DerivationPathConstants.defaultEthereum
        )
        let source = MetaAccountImportRequestSource.mnemonic(data: sourceData)
        let request = MetaAccountImportRequest(
            source: source,
            username: "Pendulum Wallet",
            cryptoType: .sr25519,
            defaultChainId: "5d3c298622d5634ed019bf61ea4b71655030015bde9beb0d6a24743714462c86"
        )

        interactor.importMetaAccount(request: request)
    }

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
        handle(qrString: code)
    }

    private func didCompleteImageSelection(with selectedImages: [UIImage]) {
        if let image = selectedImages.first {
            interactor.extractQr(from: image)
        }
    }
}

// MARK: - GetPreinstalledWalletViewOutput

extension GetPreinstalledWalletPresenter: ScanQRViewOutput {
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

// MARK: - GetPreinstalledWalletInteractorOutput

extension GetPreinstalledWalletPresenter: GetPreinstalledWalletInteractorOutput {
    func didReceiveAccountImport(error: Error) {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        guard !router.present(error: error, from: view, locale: locale) else {
            return
        }

        _ = router.present(
            error: CommonError.undefined,
            from: view,
            locale: locale
        )
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

        processingIsActive = false

        logger.error("Unexpected qr service error \(error)")
    }

    func handleMatched(addressInfo: QRInfo) {
        handle(qrString: addressInfo.address)
    }

    func handleAddress(_ address: String) {
        handle(qrString: address)
    }

    func didCompleteAccountImport() {
        router.proceed(from: view)
    }
}

// MARK: - Localizable

extension GetPreinstalledWalletPresenter: Localizable {
    func applyLocalization() {}
}

extension GetPreinstalledWalletPresenter: GetPreinstalledWalletModuleInput {}

extension GetPreinstalledWalletPresenter: QRCaptureServiceDelegate {
    func qrCapture(service _: QRCaptureServiceProtocol, didSetup captureSession: AVCaptureSession) {
        DispatchQueue.main.async {
            self.handleReceived(captureSession: captureSession)
        }
    }

    func qrCapture(service _: QRCaptureServiceProtocol, didMatch _: String) {
        guard let qrInfo = qrScanMatcher.qrInfo else {
            logger.warning("Can't find receiver's info for matched code")
            return
        }

        handle(qrString: qrInfo.address)
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

extension GetPreinstalledWalletPresenter: ImageGalleryDelegate {
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

extension GetPreinstalledWalletPresenter: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
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
