import Foundation

extension AddAccount {
    final class AccountConfirmWireframe: AccountConfirmWireframeProtocol {
        func proceed(from view: AccountConfirmViewProtocol?, flow _: AccountConfirmFlow?) {
            guard let navigationController = view?.controller.navigationController else {
                return
            }

            MainTransitionHelper.transitToMainTabBarController(
                closing: navigationController,
                animated: true
            )
        }
    }
}
