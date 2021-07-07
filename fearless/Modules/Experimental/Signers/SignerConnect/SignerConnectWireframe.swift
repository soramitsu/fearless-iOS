import Foundation

final class SignerConnectWireframe: SignerConnectWireframeProtocol {
    func showConfirmation(from view: SignerConnectViewProtocol?, request: SignerOperationRequestProtocol) {
        guard let confirmView = SignerConfirmViewFactory.createView(from: request) else {
            return
        }

        let navigationController = FearlessNavigationController(rootViewController: confirmView.controller)

        view?.controller.present(navigationController, animated: true, completion: nil)
    }
}
