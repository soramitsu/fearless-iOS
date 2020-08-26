import Foundation

final class AccountManagementWireframe: AccountManagementWireframeProtocol {
    func showAccountDetails(_ account: ManagedAccountItem, from view: AccountManagementViewProtocol?) {}

    func showAddAccount(from view: AccountManagementViewProtocol?) {
        guard let onboarding = OnboardingMainViewFactory.createViewForAdding() else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            navigationController.pushViewController(onboarding.controller, animated: true)
        }
    }
}
