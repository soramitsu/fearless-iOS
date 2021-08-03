import Foundation

extension SelectConnection {
    final class AccountConfirmWireframe: AccountConfirmWireframeProtocol {
        func proceed(from view: AccountConfirmViewProtocol?) {
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
