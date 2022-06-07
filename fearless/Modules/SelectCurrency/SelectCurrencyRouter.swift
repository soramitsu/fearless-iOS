import Foundation

final class SelectCurrencyRouter: SelectCurrencyRouterInput {
    func proceed(from view: SelectCurrencyViewInput?) {
        guard let navigationController = view?.controller.navigationController else {
            return
        }

        MainTransitionHelper.transitToMainTabBarController(
            closing: navigationController,
            animated: true
        )
    }
}
