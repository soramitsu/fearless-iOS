import AVFoundation
import UIKit
import SSFUtils

typealias ScanQRModuleCreationResult = (view: ScanQRViewInput, input: ScanQRModuleInput)

protocol ScanQRViewInput: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(session: AVCaptureSession)
    func present(message: String, animated: Bool)
}

protocol ScanQRViewOutput: AnyObject {
    func didLoad(view: ScanQRViewInput)
    func prepareDismiss()
    func prepareAppearance()
    func handleDismiss()
    func handleAppearance()
    func activateImport()
    func didTapBackButton()
}

protocol ScanQRInteractorInput: AnyObject {
    func setup(with output: ScanQRInteractorOutput & QRCaptureServiceDelegate)
    func extractQr(from image: UIImage)
    func startScanning()
    func stopScanning()
}

protocol ScanQRInteractorOutput: AnyObject {
    func handleQRService(error: Error)
    func handleMatched(code: String)
}

protocol ScanQRRouterInput: ApplicationSettingsPresentable, PresentDismissable, ImageGalleryPresentable, SheetAlertPresentable {
    func close(view: ControllerBackedProtocol?, completion: @escaping () -> Void)
}

protocol ScanQRModuleInput: AnyObject {}

protocol ScanQRModuleOutput: AnyObject {
    func didFinishWith(scanType: QRMatcherType)
}
