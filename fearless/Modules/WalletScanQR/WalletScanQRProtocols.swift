import AVFoundation
import CommonWallet

protocol WalletScanQRViewProtocol: ControllerBackedProtocol {
    func didReceive(session: AVCaptureSession)
    func present(message: String, animated: Bool)
}

protocol WalletScanQRPresenterProtocol: AnyObject {
    func setup()

    func prepareAppearance()
    func handleAppearance()
    func prepareDismiss()
    func handleDismiss()
    func activateImport()
}

protocol WalletScanQRInteractorInputProtocol: AnyObject {}

protocol WalletScanQRInteractorOutputProtocol: AnyObject {}

protocol WalletScanQRWireframeProtocol: ApplicationSettingsPresentable, ImageGalleryPresentable {
    func close(view: ControllerBackedProtocol?)
}

protocol WalletScanQRModuleOutput: AnyObject {
    func didFinishWith(payload: TransferPayload)
}
