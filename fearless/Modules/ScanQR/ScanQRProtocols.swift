import AVFoundation
import UIKit
import SSFUtils
import SSFQRService

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
    func lookingMatcher(for code: String)
}

protocol ScanQRInteractorOutput: AnyObject {
    func handleQRService(error: Error)
    func didReceive(matcher: QRMatcherType)
}

protocol ScanQRRouterInput: ApplicationSettingsPresentable, PresentDismissable, ImageGalleryPresentable, SheetAlertPresentable {
    func close(view: ControllerBackedProtocol?, completion: @escaping () -> Void)
}

protocol ScanQRModuleInput: AnyObject {}

protocol ScanQRModuleOutput: AnyObject {
    func didFinishWith(scanType: QRMatcherType)
}
