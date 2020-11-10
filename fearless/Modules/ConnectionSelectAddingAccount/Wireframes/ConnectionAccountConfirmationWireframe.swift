import Foundation

final class ConnectionAccountConfirmationWireframe: AccountConfirmWireframeProtocol {
    func proceed(from view: AccountConfirmViewProtocol?) {
        guard let navigationController = view?.controller.navigationController else {
            return
        }

        navigationController.popToRootViewController(animated: false)

        navigationController.tabBarController?.selectedIndex = MainTabBarViewFactory.walletIndex
    }
}
