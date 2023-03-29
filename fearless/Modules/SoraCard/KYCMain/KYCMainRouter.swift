import Foundation

final class KYCMainRouter: KYCMainRouterInput {
    func showSwap(from view: ControllerBackedProtocol?, wallet: MetaAccountModel, chainAsset: ChainAsset) {
        guard let module = PolkaswapAdjustmentAssembly.configureModule(swapFromChainAsset: chainAsset, wallet: wallet) else {
            return
        }
        let navigationController = FearlessNavigationController(rootViewController: module.view.controller)

        view?.controller.navigationController?.present(
            navigationController,
            animated: true
        )
    }

    func showBuyXor(from view: ControllerBackedProtocol?, wallet: MetaAccountModel, chainAsset: ChainAsset) {
        guard let module = SCXOneAssembly.configureModule(wallet: wallet, chainAsset: chainAsset) else {
            return
        }
        let navigationController = FearlessNavigationController(rootViewController: module.view.controller)

        view?.controller.navigationController?.present(
            navigationController,
            animated: true
        )
    }

    func showTermsAndConditions(from view: ControllerBackedProtocol?) {
        guard let module = TermsAndConditionsAssembly.configureModule() else {
            return
        }
        let navigationController = FearlessNavigationController(rootViewController: module.view.controller)

        view?.controller.present(navigationController, animated: true)
    }

    func showSelectAsset(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        selectedAssetId: AssetModel.Id?,
        chainAssets: [ChainAsset]?,
        output: SelectAssetModuleOutput
    ) {
        guard
            let module = SelectAssetAssembly.configureModule(
                wallet: wallet,
                selectedAssetId: selectedAssetId,
                chainAssets: chainAssets,
                searchTextsViewModel: .searchAssetPlaceholder,
                output: output
            )
        else {
            return
        }
        view?.controller.present(module.view.controller, animated: true)
    }
}
