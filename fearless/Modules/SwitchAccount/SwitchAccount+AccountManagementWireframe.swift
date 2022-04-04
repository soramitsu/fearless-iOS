import Foundation

extension SwitchAccount {
    final class AccountManagementWireframe: AccountManagementWireframeProtocol {
        func showAccountDetails(
            from view: AccountManagementViewProtocol?,
            metaAccount: MetaAccountModel
        ) {
            let walletDetails = WalletDetailsViewFactory.createView(
                with: metaAccount
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

        func showWalletSettings(
            from view: AccountManagementViewProtocol?,
            items: [WalletSettingsRow],
            callback: @escaping ModalPickerSelectionCallback
        ) {
            guard let pickerView = ModalPickerFactory.createPickerForWalletActions(
                items,
                callback: callback,
                context: nil
            ) else {
                return
            }

            view?.controller.navigationController?.present(pickerView, animated: true)
        }

        func showSelectAccounts(from _: AccountManagementViewProtocol?, metaAccount _: MetaAccountModel) {}
    }
}
