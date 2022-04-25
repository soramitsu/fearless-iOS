import Foundation

final class AccountManagementWireframe: AccountManagementWireframeProtocol {
    func showAccountDetails(
        from view: AccountManagementViewProtocol?,
        metaAccount: MetaAccountModel
    ) {
        let walletDetails = WalletDetailsViewFactory.createView(
            flow: .normal(wallet: metaAccount)
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

    func showSelectAccounts(
        from view: AccountManagementViewProtocol?,
        managedMetaAccountModel: ManagedMetaAccountModel
    ) {
        guard let module = SelectExportAccountAssembly.configureModule(
            managedMetaAccountModel: managedMetaAccountModel
        ) else { return }
        view?.controller.navigationController?.pushViewController(module.view.controller, animated: true)
    }
}
