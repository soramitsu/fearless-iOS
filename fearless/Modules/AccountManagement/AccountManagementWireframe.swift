import Foundation

final class AccountManagementWireframe: AccountManagementWireframeProtocol {
    func showAccountDetails(from _: AccountManagementViewProtocol?, metaAccount _: MetaAccountModel) {
        // TODO: Implement with new onboarding story
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

        MainTransitionHelper.transitToMainTabBarController(
            closing: navigationController,
            animated: true
        )
    }
}
