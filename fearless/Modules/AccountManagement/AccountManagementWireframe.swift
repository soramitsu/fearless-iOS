import Foundation

final class AccountManagementWireframe: AccountManagementWireframeProtocol {
    func showAccountDetails(
        from view: AccountManagementViewProtocol?,
        metaAccount: MetaAccountModel
    ) {
        let walletDetails = WalletDetailsViewFactory.createView(
            with: metaAccount
        )
        let navigationController = FearlessNavigationController(
            rootViewController: walletDetails.controller
        )
        view?.controller.present(navigationController, animated: true)
    }

    func showAddAccount(from view: AccountManagementViewProtocol?) {
        guard let onboarding = OnboardingMainViewFactory.createViewForAdding() else {
            return
        }
        view?.controller.hidesBottomBarWhenPushed = true

        if let navigationController = view?.controller.navigationController {
            navigationController.pushViewController(onboarding.controller, animated: true)
        }
    }

    func complete(from view: AccountManagementViewProtocol?) {
        guard let navigationController = view?.controller.navigationController else {
            return
        }

        MainTransitionHelper.transitToMainTabBarController(
            closing: navigationController,
            animated: true
        )
    }
}
