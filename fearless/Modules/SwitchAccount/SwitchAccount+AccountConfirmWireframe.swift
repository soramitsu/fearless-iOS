import Foundation

extension SwitchAccount {
    final class AccountConfirmWireframe: AccountConfirmWireframeProtocol {
        func proceed(from view: AccountConfirmViewProtocol?, flow _: AccountConfirmFlow?) {
            guard let navigationController = view?.controller.navigationController else {
                return
            }

            navigationController.popToRootViewController(animated: true)
        }
    }
}
