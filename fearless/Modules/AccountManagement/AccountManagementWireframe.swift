import Foundation

final class AccountManagementWireframe: AccountManagementWireframeProtocol {
    func showAccountDetails(_ account: ManagedAccountItem, from view: AccountManagementViewProtocol?) {
        guard let infoView = AccountInfoViewFactory.createView(address: account.address) else {
            return
        }

        let navigationController = FearlessNavigationController(rootViewController: infoView.controller)

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showAddAccount(from view: AccountManagementViewProtocol?) {
        guard let onboarding = OnboardingMainViewFactory.createViewForAdding() else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            navigationController.pushViewController(onboarding.controller, animated: true)
        }
    }

    func complete(from view: AccountManagementViewProtocol?) {
        guard let navigationController = view?.controller.navigationController else {
            return
        }

        MainTransitionHelper.transitToMainTabBarController(closing: navigationController,
                                                           animated: true)
    }
}
