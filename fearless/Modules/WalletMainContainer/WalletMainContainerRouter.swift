import Foundation
import UIKit
import SSFModels

final class WalletMainContainerRouter: WalletMainContainerRouterInput {
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

    func showScanQr(from view: WalletMainContainerViewInput?, moduleOutput: ScanQRModuleOutput) {
        guard let module = ScanQRAssembly.configureModule(moduleOutput: moduleOutput) else {
            return
        }

        let navigationController = FearlessNavigationController(
            rootViewController: module.view.controller
        )
        view?.controller.present(navigationController, animated: true)
    }

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
        delegate: NetworkManagmentModuleOutput?
    ) {
        guard
            let module = NetworkManagmentAssembly.configureModule(
                wallet: wallet,
                chains: nil,
                contextTag: nil,
                moduleOutput: delegate
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

    func showSendFlow(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        initialData: SendFlowInitialData
    ) {
        let sendModule = SendAssembly.configureModule(wallet: wallet, initialData: initialData)
        guard let controller = sendModule?.view.controller else {
            return
        }

        let navigationController = FearlessNavigationController(rootViewController: controller)
        present(navigationController, from: view)
    }

    func showControllerAccountFlow(from view: ControllerBackedProtocol?, chainAsset: ChainAsset, wallet: MetaAccountModel) {
        guard let controllerAccount = ControllerAccountViewFactory.createView(
            chain: chainAsset.chain,
            asset: chainAsset.asset,
            selectedAccount: wallet
        ) else {
            return
        }
        let navigationController = ImportantFlowViewFactory.createNavigation(
            from: controllerAccount.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showMainStaking(from view: WalletMainContainerViewInput?) {
        guard
            let tabBar = view?.controller.tabBarController as? MainTabBarViewController
        else {
            return
        }

        tabBar.select(destination: .defi)

        guard
            let navigationController = tabBar.controller(for: .defi) as? UINavigationController,
            let defiHub = navigationController.viewControllers.first as? DeFiHubViewController
        else {
            return
        }

        defiHub.showStaking()
    }

    func showWalletDetails(from view: WalletMainContainerViewInput?, wallet: MetaAccountModel) {
        let module = WalletDetailsViewFactory.createView(flow: .normal(wallet: wallet))
        let navigationController = FearlessNavigationController(
            rootViewController: module.controller
        )

        view?.controller.present(navigationController, animated: true)
    }

    // MARK: - Sun-lit wallet home actions

    func showAssetPicker(
        from view: WalletMainContainerViewInput?,
        wallet: MetaAccountModel,
        action: WalletHomeAction,
        output: SelectAssetModuleOutput
    ) {
        guard let module = SelectAssetAssembly.configureModule(
            wallet: wallet,
            selectedAssetId: nil,
            chainAssets: nil,
            searchTextsViewModel: .searchAssetPlaceholder,
            output: output,
            contextTag: action.rawValue
        ) else {
            return
        }
        present(module.view.controller, from: view)
    }

    func showReceive(from view: WalletMainContainerViewInput?, wallet: MetaAccountModel, chainAsset: ChainAsset) {
        guard let controller = ReceiveAndRequestAssetAssembly.configureModule(
            wallet: wallet, chainAsset: chainAsset
        )?.view.controller else {
            return
        }
        present(controller, from: view)
    }

    func showAssetDetails(from view: WalletMainContainerViewInput?, chainAsset: ChainAsset) {
        guard let details = WalletChainAccountDashboardViewFactory.createDetailsView(chainAsset: chainAsset) else {
            return
        }
        view?.controller.navigationController?.pushViewController(details.controller, animated: true)
    }

    func showSwap(from view: WalletMainContainerViewInput?) {
        (view?.controller.tabBarController as? MainTabBarViewController)?.select(destination: .polkaswap)
    }

    /// Presents once any sheet that is still leaving (the asset picker) has gone.
    private func present(_ controller: UIViewController, from view: ControllerBackedProtocol?) {
        guard let host = view?.controller else { return }
        if let presented = host.presentedViewController, presented.isBeingDismissed,
           let coordinator = presented.transitionCoordinator {
            coordinator.animate(alongsideTransition: nil) { [weak host] _ in
                host?.present(controller, animated: true)
            }
        } else if host.presentedViewController == nil {
            host.present(controller, animated: true)
        }
    }
}
