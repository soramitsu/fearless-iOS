import Foundation

final class ConnectionAccountConfirmWireframe: AccountConfirmWireframeProtocol {
    func proceed(from view: AccountConfirmViewProtocol?) {
        guard let navigationController = view?.controller.navigationController else {
            return
        }

        MainTransitionHelper.transitToMainTabBarController(closing: navigationController,
                                                           animated: true)
    }
}
