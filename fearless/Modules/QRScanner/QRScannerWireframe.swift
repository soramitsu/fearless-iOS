import Foundation

final class QRScannerWireframe: QRScannerWireframeProtocol {
    func close(view: QRScannerViewProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
