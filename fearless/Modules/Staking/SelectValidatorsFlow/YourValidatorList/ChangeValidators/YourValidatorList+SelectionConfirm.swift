import Foundation

extension YourValidatorList {
    final class SelectValidatorsConfirmWireframe: SelectValidatorsConfirmWireframeProtocol, ModalAlertPresenting, AllDonePresentable {
        func complete(txHash: String, from view: SelectValidatorsConfirmViewProtocol?) {
            let presenter = view?.controller.navigationController?.presentingViewController
            let navigationController = view?.controller.navigationController

            navigationController?.dismiss(animated: true)
            if let presenter = presenter as? ControllerBackedProtocol {
                presentDone(extrinsicHash: txHash, from: presenter)
            }
        }
    }
}
