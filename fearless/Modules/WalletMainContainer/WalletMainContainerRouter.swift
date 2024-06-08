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
        view?.controller.present(navigationController, animated: true)
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

    func showMainStaking() {
        if let tabBar = UIApplication.shared.keyWindow?.rootViewController as? MainTabBarViewController? {
            tabBar?.selectedIndex = 2
        }
    }
}
