import Foundation

final class SelectCurrencyRouter: SelectCurrencyRouterInput {
    private let viewIsModal: Bool

    init(viewIsModal: Bool) {
        self.viewIsModal = viewIsModal
    }

    func proceed(from view: SelectCurrencyViewInput?) {
        if viewIsModal {
            view?.controller.dismiss(animated: true)
        } else {
            guard let navigationController = view?.controller.navigationController else {
                return
            }

            MainTransitionHelper.transitToMainTabBarController(
                closing: navigationController,
                animated: true
            )
        }
    }

    func back(from view: SelectCurrencyViewInput?) {
        if viewIsModal {
            view?.controller.dismiss(animated: true)
        } else {
            view?.controller.navigationController?.popViewController(animated: true)
        }
    }
}
