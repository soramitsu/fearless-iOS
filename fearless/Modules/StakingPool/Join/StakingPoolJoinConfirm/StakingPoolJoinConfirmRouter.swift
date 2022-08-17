import Foundation

final class StakingPoolJoinConfirmRouter: StakingPoolJoinConfirmRouterInput {
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

        view?.controller.navigationController?.dismiss(animated: true, completion: nil)

        if let presenter = presenter as? ControllerBackedProtocol {
            presentSuccessNotification(title, from: presenter)
        }
    }
}
