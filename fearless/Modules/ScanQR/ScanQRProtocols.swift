import AVFoundation
import UIKit
import FearlessUtils

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
    func setup(with output: ScanQRInteractorOutput)
    func extractQr(from image: UIImage)
    func startScanning(delegate: QRCaptureServiceDelegate)
    func stopScanning()
}

protocol ScanQRInteractorOutput: AnyObject {
    func handleQRService(error: Error)
    func handleMatched(addressInfo: AddressQRInfo)
}

protocol ScanQRRouterInput: ApplicationSettingsPresentable, PresentDismissable, ImageGalleryPresentable {}

protocol ScanQRModuleInput: AnyObject {}

protocol ScanQRModuleOutput: AnyObject {
    func didFinishWith(addressInfo: AddressQRInfo)
    func didFinishWith(address: String)
}
