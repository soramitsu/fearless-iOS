import Foundation

final class ExperimentalListWireframe: ExperimentalListWireframeProtocol {
    func showNotificationSettings(from _: ExperimentalListViewProtocol?) {}

    func showMobileSigning(from view: ExperimentalListViewProtocol?) {
        guard let signerView = QRScannerViewFactory.createBeaconView() else {
            return
        }

        view?.controller.navigationController?.pushViewController(signerView.controller, animated: true)
    }
}
