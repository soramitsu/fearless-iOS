import Foundation

final class AddConfirmationWireframe: AccountConfirmWireframeProtocol {
    func proceed(from view: AccountConfirmViewProtocol?) {
        guard let navigationController = view?.controller.navigationController else {
            return
        }

        if let managementController = navigationController.viewControllers
            .first(where: { $0 is AccountManagementViewController }) {
            navigationController.popToViewController(managementController, animated: true)
        } else {
            navigationController.popToRootViewController(animated: true)
        }
    }
}
