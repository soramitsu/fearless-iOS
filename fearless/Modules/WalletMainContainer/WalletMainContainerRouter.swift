import Foundation
import UIKit

final class WalletMainContainerRouter: WalletMainContainerRouterInput {
    func showCreateNewWallet(from view: WalletMainContainerViewInput?) {
        guard let usernameSetup = UsernameSetupViewFactory.createViewForAdding() else {
            return
        }

        usernameSetup.controller.hidesBottomBarWhenPushed = true

        if let navigationController = view?.controller.navigationController {
            navigationController.pushViewController(usernameSetup.controller, animated: true)
        }
    }

    func showImportWallet(from view: WalletMainContainerViewInput?) {
        guard let restorationController = AccountImportViewFactory
            .createViewForAdding()?.controller
        else {
            return
        }

        restorationController.hidesBottomBarWhenPushed = true

        if let navigationController = view?.controller.navigationController {
            navigationController.pushViewController(restorationController, animated: true)
        }
    }

    func showWalletManagment(
        from view: WalletMainContainerViewInput?,
        moduleOutput: WalletsManagmentModuleOutput?
    ) {
        guard
            let module = WalletsManagmentAssembly.configureModule(
                shouldSaveSelected: true,
                moduleOutput: moduleOutput
            )
        else {
            return
        }

        view?.controller.present(module.view.controller, animated: true)
    }

    func showScanQr(from _: WalletMainContainerViewInput?) {}

    func showSearch(from view: WalletMainContainerViewInput?, wallet: MetaAccountModel) {
        guard let module = AssetListSearchAssembly.configureModule(wallet: wallet) else {
            return
        }

        let navigationController = FearlessNavigationController(
            rootViewController: module.view.controller
        )
        navigationController.modalPresentationStyle = .fullScreen

        view?.controller.present(navigationController, animated: true)
    }

    func showSelectNetwork(
        from view: WalletMainContainerViewInput?,
        wallet: MetaAccountModel,
        selectedChainId: ChainModel.Id?,
        chainModels: [ChainModel]?,
        delegate: SelectNetworkDelegate?
    ) {
        guard
            let module = SelectNetworkAssembly.configureModule(
                wallet: wallet,
                selectedChainId: selectedChainId,
                chainModels: chainModels,
                searchTexts: .searchNetworkPlaceholder,
                delegate: delegate
            )
        else {
            return
        }

        view?.controller.present(module.view.controller, animated: true)
    }

    func showSelectCurrency(
        from view: WalletMainContainerViewInput?,
        wallet: MetaAccountModel
    ) {
        guard let module = SelectCurrencyAssembly.configureModule(
            with: wallet,
            isModal: true
        ) else {
            return
        }

        view?.controller.navigationController?.present(module.view.controller, animated: true)
    }

    func showIssueNotification(
        from view: WalletMainContainerViewInput?,
        issues: [ChainIssue],
        wallet: MetaAccountModel
    ) {
        guard let module = NetworkIssuesNotificationAssembly.configureModule(
            wallet: wallet,
            issues: issues
        ) else {
            return
        }

        view?.controller.present(module.view.controller, animated: true)
    }
}
