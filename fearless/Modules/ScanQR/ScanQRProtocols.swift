import AVFoundation
import UIKit
import SSFUtils

typealias ScanQRModuleCreationResult = (view: ScanQRViewInput, input: ScanQRModuleInput)

protocol ScanQRViewInput: ControllerBackedProtocol {
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
    func handleAddress(_ address: String)
    func handleMatched(addressInfo: QRInfo)
    func handleMatched(connect: URL)
}

protocol ScanQRRouterInput: ApplicationSettingsPresentable, PresentDismissable, ImageGalleryPresentable {
    func close(view: ControllerBackedProtocol?, completion: @escaping () -> Void)
}

protocol ScanQRModuleInput: AnyObject {}

protocol ScanQRModuleOutput: AnyObject {
    func didFinishWith(address: String)
    func didFinishWithConnect(uri: String)
}

extension ScanQRModuleOutput {
    func didFinishWith(address _: String) {}
    func didFinishWithConnect(uri _: String) {}
}
