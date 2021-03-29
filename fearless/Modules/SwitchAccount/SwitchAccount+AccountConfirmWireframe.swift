import Foundation

extension SwitchAccount {
    final class AccountConfirmWireframe: AccountConfirmWireframeProtocol {
        func proceed(from view: AccountConfirmViewProtocol?) {
            guard let navigationController = view?.controller.navigationController else {
                return
            }

            navigationController.popToRootViewController(animated: true)
        }
    }
}
