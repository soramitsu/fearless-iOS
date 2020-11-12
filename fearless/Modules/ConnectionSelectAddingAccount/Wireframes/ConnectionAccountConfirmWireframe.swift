import Foundation

final class ConnectionAccountConfirmWireframe: AccountConfirmWireframeProtocol {
    func proceed(from view: AccountConfirmViewProtocol?) {
        guard let navigationController = view?.controller.navigationController else {
            return
        }

        MainTransitionHelper.transitToMainIfExists(tabBarController: navigationController.tabBarController,
                                                   closing: navigationController,
                                                   animated: true)
    }
}
