import Foundation

final class ChangeConfirmationWireframe: AccountConfirmWireframeProtocol {
    func proceed(from view: AccountConfirmViewProtocol?) {
        guard let navigationController = view?.controller.navigationController else {
            return
        }

        navigationController.popToRootViewController(animated: true)
    }
}
