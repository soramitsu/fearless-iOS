import Foundation

final class PoolRolesConfirmRouter: PoolRolesConfirmRouterInput {
    func finish(view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.dismiss(
            animated: true,
            completion: nil
        )
    }

    func complete(
        on view: ControllerBackedProtocol?,
        title: String
    ) {
        let presenter = view?.controller.navigationController?.presentingViewController

        if let presenter = presenter as? ControllerBackedProtocol {
            presentSuccessNotification(title, from: presenter)
        }
    }
}
