import Foundation
import UIKit

final class WalletSendConfirmWireframe: WalletSendConfirmWireframeProtocol {
    func finish(view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.dismiss(
            animated: true,
            completion: nil
        )
    }

    func close(view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }

    func complete(
        on view: ControllerBackedProtocol?,
        title: String
    ) {
        let presenter = view?.controller.navigationController?.presentingViewController

        view?.controller.navigationController?.dismiss(animated: true, completion: nil)

        if let presenter = presenter as? ControllerBackedProtocol {
            presentSuccessNotification(title, from: presenter)
        }
    }
}
