import UIKit
import SSFUtils

typealias GetPreinstalledWalletModuleCreationResult = (view: ScanQRViewInput, input: GetPreinstalledWalletModuleInput)

protocol GetPreinstalledWalletViewInput: ControllerBackedProtocol, ScanQRViewInput {}

protocol GetPreinstalledWalletViewOutput: AnyObject, ScanQRViewOutput {
    func didLoad(view: GetPreinstalledWalletViewInput)
}

protocol GetPreinstalledWalletInteractorInput: AccountImportInteractorInputProtocol {
    func setup(with output: GetPreinstalledWalletInteractorOutput)
    func extractQr(from image: UIImage)
    func startScanning()
    func stopScanning()
}

protocol GetPreinstalledWalletInteractorOutput: AnyObject, QRCaptureServiceDelegate {
    func handleQRService(error: Error)
    func handleAddress(_ address: String)
    func handleMatched(addressInfo: QRInfo)
    func didCompleteAccountImport()
    func didReceiveAccountImport(error: Error)
}

protocol GetPreinstalledWalletRouterInput: AnyObject, ErrorPresentable, BaseErrorPresentable, SheetAlertPresentable, PresentDismissable, ImageGalleryPresentable, ApplicationSettingsPresentable {
    func presentImageGallery(
        from view: ControllerBackedProtocol?,
        delegate: ImageGalleryDelegate,
        pickerDelegate: UIImagePickerControllerDelegate & UINavigationControllerDelegate
    )
    func proceed()
}

protocol GetPreinstalledWalletModuleInput: AnyObject {}

protocol GetPreinstalledWalletModuleOutput: AnyObject {}
