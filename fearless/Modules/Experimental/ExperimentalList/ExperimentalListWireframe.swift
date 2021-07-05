import Foundation

final class ExperimentalListWireframe: ExperimentalListWireframeProtocol {
    func showNotificationSettings(from _: ExperimentalListViewProtocol?) {}

    func showBeaconConnection(from view: ExperimentalListViewProtocol?, delegate: BeaconQRDelegate) {
        guard let signerView = QRScannerViewFactory.createBeaconView(for: delegate) else {
            return
        }

        view?.controller.navigationController?.pushViewController(signerView.controller, animated: true)
    }

    func showBeaconSession(from view: ExperimentalListViewProtocol?, connectionInfo: BeaconConnectionInfo) {
        guard let sessionView = SignerConnectViewFactory.createBeaconView(for: connectionInfo) else {
            return
        }

        let navigationController = FearlessNavigationController(rootViewController: sessionView.controller)
        view?.controller.present(navigationController, animated: true, completion: nil)
    }
}
