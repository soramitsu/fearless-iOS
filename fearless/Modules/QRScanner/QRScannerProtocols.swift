import Foundation
import AVFoundation
import SoraFoundation

protocol QRScannerViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceive(session: AVCaptureSession)
    func present(message: String, animated: Bool)
}

protocol QRScannerPresenterProtocol: AnyObject {
    func setup()
}

protocol QRScannerWireframeProtocol: ApplicationSettingsPresentable {
    func close(view: QRScannerViewProtocol?)
}
