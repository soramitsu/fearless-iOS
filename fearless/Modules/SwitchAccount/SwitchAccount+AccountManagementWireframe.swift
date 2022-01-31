import Foundation

extension SwitchAccount {
    final class AccountManagementWireframe: AccountManagementWireframeProtocol {
        func showAccountDetails(
            from view: AccountManagementViewProtocol?,
            metaAccount: MetaAccountModel,
            walletChangeNameCompletion: @escaping (MetaAccountModel) -> Void
        ) {
            let walletDetails = WalletDetailsViewFactory.createView(
                with: metaAccount,
                completion: walletChangeNameCompletion
            )
            if let navigationController = view?.controller.navigationController {
                navigationController.present(walletDetails.controller, animated: true)
            }
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
