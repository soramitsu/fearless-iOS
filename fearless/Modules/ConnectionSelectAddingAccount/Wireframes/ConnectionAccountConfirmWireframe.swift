import Foundation

final class ConnectionAccountConfirmWireframe: AccountConfirmWireframeProtocol {
    func proceed(from view: AccountConfirmViewProtocol?) {
        guard let navigationController = view?.controller.navigationController else {
            return
        }

        navigationController.popToRootViewController(animated: false)

        navigationController.tabBarController?.selectedIndex = MainTabBarViewFactory.walletIndex
    }
}
