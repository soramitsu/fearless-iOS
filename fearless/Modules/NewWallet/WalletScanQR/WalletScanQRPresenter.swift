import Foundation
import RobinHood
import AVFoundation
import SoraFoundation
import CommonWallet
import UIKit
import SSFModels

final class WalletScanQRPresenter: NSObject {
    enum ScanState {
        case initializing(accessRequested: Bool)
        case inactive
        case active
        case processing(receiverInfo: ReceiveInfo, operation: CancellableCall)
        case failed(code: String)
    }

    weak var view: WalletScanQRViewProtocol?
    let wireframe: WalletScanQRWireframeProtocol
    let interactor: WalletScanQRInteractorInputProtocol
    weak var moduleOutput: WalletScanQRModuleOutput?

    private(set) var searchService: SearchServiceProtocol
    private(set) var currentAccountId: String
    private(set) var scanState: ScanState = .initializing(accessRequested: false)

    private let qrScanService: QRCaptureServiceProtocol
    private let qrCoderFactory: WalletQRCoderFactoryProtocol
    private let qrScanMatcher: InvoiceScanMatcher
    private let localSearchEngine: InvoiceLocalSearchEngineProtocol?
    private let chain: ChainModel
    private let qrExtractionService: QRExtractionServiceProtocol?

    private var localizationManager: LocalizationManagerProtocol?

    var logger: LoggerProtocol?

    init(
        interactor: WalletScanQRInteractorInputProtocol,
        wireframe: WalletScanQRWireframeProtocol,
        currentAccountId: String,
        searchService: SearchServiceProtocol,
        localSearchEngine: InvoiceLocalSearchEngineProtocol?,
        qrScanServiceFactory: QRCaptureServiceFactoryProtocol,
        qrCoderFactory: WalletQRCoderFactoryProtocol,
        localizationManager: LocalizationManagerProtocol?,
        chain: ChainModel,
        moduleOutput: WalletScanQRModuleOutput?,
        qrExtractionService: QRExtractionServiceProtocol?
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chain = chain
        self.moduleOutput = moduleOutput
        self.searchService = searchService
        self.localSearchEngine = localSearchEngine
        self.currentAccountId = currentAccountId
        self.qrExtractionService = qrExtractionService
        self.qrCoderFactory = qrCoderFactory

        let qrDecoder = qrCoderFactory.createDecoder()
        qrScanMatcher = InvoiceScanMatcher(decoder: qrDecoder)

        self.localizationManager = localizationManager

        qrScanService = qrScanServiceFactory.createService(
            with: qrScanMatcher,
            delegate: nil,
            delegateQueue: nil
        )

        super.init()

        qrScanService.delegate = self
    }

    private func handleQRService(error: Error) {
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

        logger?.error("Unexpected qr service error \(error)")
    }

    private func handleQRCaptureService(error: QRCaptureServiceError) {
        guard case let .initializing(alreadyAskedAccess) = scanState, !alreadyAskedAccess else {
            logger?.warning("Requested to ask access but already done earlier")
            return
        }

        scanState = .initializing(accessRequested: true)

        switch error {
        case .deviceAccessRestricted:
            view?.present(message: L10n.InvoiceScan.Error.cameraRestricted, animated: true)
        case .deviceAccessDeniedPreviously:
            let message = L10n.InvoiceScan.Error.cameraRestrictedPreviously
            let title = L10n.InvoiceScan.Error.cameraTitle
            wireframe.askOpenApplicationSettings(with: message, title: title, from: view)
        default:
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
            wireframe.askOpenApplicationSettings(with: message, title: title, from: view)
        default:
            break
        }
    }

    private func handleReceived(captureSession: AVCaptureSession) {
        if case .initializing = scanState {
            scanState = .active

            view?.didReceive(session: captureSession)
        }
    }

    private func handleMatched(receiverInfo: ReceiveInfo) {
        if receiverInfo.accountId == currentAccountId {
            let message = L10n.InvoiceScan.Error.match
            view?.present(message: message, animated: true)
            return
        }

        switch scanState {
        case let .processing(oldReceiverInfo, oldOperation) where oldReceiverInfo != receiverInfo:
            oldOperation.cancel()

            performProcessing(of: receiverInfo)
        case .active:
            performProcessing(of: receiverInfo)
        default:
            break
        }
    }

    private func handleFailedMatching(for code: String) {
        moduleOutput?.didFinishWith(incorrectAddress: code)
        wireframe.close(view: view)
    }

    private func performProcessing(of receiverInfo: ReceiveInfo) {
        if let searchData = localSearchEngine?.searchByAccountId(receiverInfo.accountId) {
            scanState = .active

            completeTransferFoundAccount(searchData, receiverInfo: receiverInfo)
        } else {
            let operation = searchService.searchPeople(
                query: receiverInfo.accountId,
                chain: chain,
                filterResults: nil
            ) { [weak self] result in
                switch result {
                case let .success(searchResult):
                    let loadedResult = searchResult ?? []
                    self?.handleProccessing(searchResult: loadedResult)
                case let .failure(error):
                    self?.handleProcessing(error: error)
                }
            }

            scanState = .processing(
                receiverInfo: receiverInfo,
                operation: operation
            )
        }
    }

    private func handleProccessing(searchResult: [SearchData]) {
        guard case let .processing(receiverInfo, _) = scanState else {
            logger?.warning("Unexpected state \(scanState) after successfull processing")
            return
        }

        scanState = .active

        guard let foundAccount = searchResult.first else {
            let message = L10n.InvoiceScan.Error.userNotFound
            view?.present(message: message, animated: true)
            return
        }

        completeTransferFoundAccount(foundAccount, receiverInfo: receiverInfo)
    }

    private func completeTransferFoundAccount(
        _ foundAccount: SearchData,
        receiverInfo: ReceiveInfo
    ) {
        guard foundAccount.accountId == receiverInfo.accountId else {
            let message = L10n.InvoiceScan.Error.noReceiver
            view?.present(message: message, animated: true)
            return
        }

        let receiverName = "\(foundAccount.firstName) \(foundAccount.lastName)"
        let payload = TransferPayload(
            receiveInfo: receiverInfo,
            receiverName: receiverName
        )

        wireframe.close(view: view)
        moduleOutput?.didFinishWith(payload: payload)
    }

    private func handleProcessing(error: Error) {
        guard case .processing = scanState else {
            logger?.warning("Unexpected state \(scanState) after failed processing")
            return
        }

        scanState = .active

        if let contentConvertible = error as? WalletErrorContentConvertible {
            let locale = localizationManager?.selectedLocale
            let content = contentConvertible.toErrorContent(for: locale)
            view?.present(message: content.message, animated: true)
        } else {
            let message = L10n.InvoiceScan.Error.noInternet
            view?.present(message: message, animated: true)
        }
    }

    private func didCompleteImageSelection(with selectedImages: [UIImage]) {
        if let image = selectedImages.first {
            let qrDecoder = qrCoderFactory.createDecoder()
            let matcher = InvoiceScanMatcher(decoder: qrDecoder)

            qrExtractionService?.extract(
                from: image,
                using: matcher,
                dispatchCompletionIn: .main
            ) { [weak self] result in
                switch result {
                case .success:
                    if let recieverInfo = matcher.receiverInfo {
                        self?.handleMatched(receiverInfo: recieverInfo)
                    }
                case let .failure(error):
                    self?.handleQRService(error: error)
                }
            }
        }
    }
}

extension WalletScanQRPresenter: WalletScanQRPresenterProtocol {
    func prepareAppearance() {
        qrScanService.start()
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
        qrScanService.stop()
    }

    func activateImport() {
        if qrExtractionService != nil {
            wireframe.presentImageGallery(
                from: view,
                delegate: self,
                pickerDelegate: self
            )
        }
    }

    func setup() {}
}

extension WalletScanQRPresenter: WalletScanQRInteractorOutputProtocol {}

extension WalletScanQRPresenter: QRCaptureServiceDelegate {
    func qrCapture(service _: QRCaptureServiceProtocol, didSetup captureSession: AVCaptureSession) {
        DispatchQueue.main.async {
            self.handleReceived(captureSession: captureSession)
        }
    }

    func qrCapture(service _: QRCaptureServiceProtocol, didMatch _: String) {
        guard let receiverInfo = qrScanMatcher.receiverInfo else {
            logger?.warning("Can't find receiver's info for matched code")
            return
        }

        DispatchQueue.main.async {
            self.handleMatched(receiverInfo: receiverInfo)
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

extension WalletScanQRPresenter: ImageGalleryDelegate {
    func didCompleteImageSelection(
        from _: ImageGalleryPresentable,
        with selectedImages: [UIImage]
    ) {
        if let image = selectedImages.first {
            let qrDecoder = qrCoderFactory.createDecoder()
            let matcher = InvoiceScanMatcher(decoder: qrDecoder)

            qrExtractionService?.extract(
                from: image,
                using: matcher,
                dispatchCompletionIn: .main
            ) { [weak self] result in
                switch result {
                case .success:
                    if let recieverInfo = matcher.receiverInfo {
                        self?.handleMatched(receiverInfo: recieverInfo)
                    }
                case let .failure(error):
                    self?.handleQRService(error: error)
                }
            }
        }
    }

    func didFail(in _: ImageGalleryPresentable, with error: Error) {
        handleQRService(error: error)
    }
}

extension WalletScanQRPresenter: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    @objc func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        if let originalImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
            didCompleteImageSelection(with: [originalImage])
        } else {
            didCompleteImageSelection(with: [])
        }

        picker.presentingViewController?.dismiss(animated: true, completion: nil)
    }

    @objc func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        didCompleteImageSelection(with: [])

        picker.presentingViewController?.dismiss(animated: true, completion: nil)
    }
}
