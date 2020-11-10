import Foundation

final class AddConfirmationWireframe: AccountConfirmWireframeProtocol {
    func proceed(from view: AccountConfirmViewProtocol?) {
        guard let navigationController = view?.controller.navigationController else {
            return
        }

        MainTransitionHelper.transitToMainIfExists(tabBarController: navigationController.tabBarController,
                                                   closing: navigationController,
                                                   animated: true)
    }
}
