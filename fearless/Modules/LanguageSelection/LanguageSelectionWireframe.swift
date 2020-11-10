import Foundation

final class LanguageSelectionWireframe: LanguageSelectionWireframeProtocol {
    func proceed(from view: LanguageSelectionViewProtocol?) {
        guard let navigationController = view?.controller.navigationController else {
            return
        }

        navigationController.popToRootViewController(animated: false)

        navigationController.tabBarController?.selectedIndex = MainTabBarViewFactory.walletIndex
    }
}
