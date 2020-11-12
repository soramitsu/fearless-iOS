import Foundation

final class LanguageSelectionWireframe: LanguageSelectionWireframeProtocol {
    func proceed(from view: LanguageSelectionViewProtocol?) {
        guard let navigationController = view?.controller.navigationController else {
            return
        }

        MainTransitionHelper.transitToMainIfExists(tabBarController: navigationController.tabBarController,
                                                   closing: navigationController,
                                                   animated: true)
    }
}
