import Foundation

final class ExperimentalListWireframe: ExperimentalListWireframeProtocol {
    func showNotificationSettings(from _: ExperimentalListViewProtocol?) {}

    func showBeaconConnection(from view: ExperimentalListViewProtocol?, delegate: BeaconQRDelegate) {
        guard let signerView = QRScannerViewFactory.createBeaconView(for: delegate) else {
            return
        }

        view?.controller.navigationController?.pushViewController(signerView.controller, animated: true)
    }

    func showBeaconSession(from _: ExperimentalListViewProtocol?, connectionInfo: BeaconConnectionInfo) {
        Logger.shared.info("Will present session for info: \(connectionInfo)")
    }
}
