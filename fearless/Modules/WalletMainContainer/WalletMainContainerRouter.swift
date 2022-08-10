import Foundation
import UIKit

final class WalletMainContainerRouter: WalletMainContainerRouterInput {
    func showSendFlow(
        from view: WalletMainContainerViewInput?,
        chainAsset: ChainAsset,
        selectedMetaAccount: MetaAccountModel,
        transferFinishBlock: WalletTransferFinishBlock?
    ) {
        let searchView = SearchPeopleViewFactory.createView(
            chain: chainAsset.chain,
            asset: chainAsset.asset,
            selectedMetaAccount: selectedMetaAccount,
            transferFinishBlock: transferFinishBlock
        )

        guard let controller = searchView?.controller else {
            return
        }

        let navigationController = UINavigationController(rootViewController: controller)
        view?.controller.present(navigationController, animated: true)
    }

    func showReceiveFlow(
        from view: WalletMainContainerViewInput?,
        chainAsset: ChainAsset,
        selectedMetaAccount: MetaAccountModel
    ) {
        let receiveView = ReceiveAssetViewFactory.createView(
            account: selectedMetaAccount,
            chain: chainAsset.chain,
            asset: chainAsset.asset
        )

        guard let controller = receiveView?.controller else {
            return
        }

        let navigationController = UINavigationController(rootViewController: controller)
        view?.controller.present(navigationController, animated: true)
    }

    func showCreateNewWallet(from view: WalletMainContainerViewInput?) {
        guard let usernameSetup = UsernameSetupViewFactory.createViewForOnboarding() else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            navigationController.pushViewController(usernameSetup.controller, animated: true)
        }
    }

    func showImportWallet(from view: WalletMainContainerViewInput?) {
        guard let restorationController = AccountImportViewFactory
            .createViewForOnboarding()?.controller
        else {
            return
        }

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
                moduleOutput: moduleOutput
            )
        else {
            return
        }

        view?.controller.present(module.view.controller, animated: true)
    }

    func showScanQr(from _: WalletMainContainerViewInput?) {}

    func showSearch(from view: WalletMainContainerViewInput?) {
        guard let module = AssetListSearchAssembly.configureModule() else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            module.view.controller,
            animated: true
        )
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
                delegate: delegate
            )
        else {
            return
        }

        view?.controller.present(module.view.controller, animated: true)
    }
}
