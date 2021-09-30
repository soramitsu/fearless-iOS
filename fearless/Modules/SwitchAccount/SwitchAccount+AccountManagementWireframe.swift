import Foundation

extension SwitchAccount {
    final class AccountManagementWireframe: AccountManagementWireframeProtocol {
        func showAccountDetails(from _: AccountManagementViewProtocol?, metaAccount _: MetaAccountModel) {
            // TODO: Implement when new onboarding process done
        }

        func showAddAccount(from view: AccountManagementViewProtocol?) {
            guard let onboarding = OnboardingMainViewFactory.createViewForAccountSwitch() else {
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

            navigationController.popToRootViewController(animated: true)
        }
    }
}
