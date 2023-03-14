import Foundation

final class PolkaswapAdjustmentRouter: PolkaswapAdjustmentRouterInput {
    func showSelectMarket(
        from view: ControllerBackedProtocol?,
        markets: [LiquiditySourceType],
        selectedMarket: LiquiditySourceType,
        slippadgeTolerance: Float,
        moduleOutput: PolkaswapTransaktionSettingsModuleOutput
    ) {
        guard let module = PolkaswapTransaktionSettingsAssembly.configureModule(
            markets: markets,
            selectedMarket: selectedMarket,
            slippadgeTolerance: slippadgeTolerance,
            moduleOutput: moduleOutput
        ) else {
            return
        }

        view?.controller.present(module.view.controller, animated: true)
    }

    func showSelectAsset(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        chainAssets: [ChainAsset]?,
        selectedAssetId: AssetModel.Id?,
        contextTag: Int?,
        output: SelectAssetModuleOutput
    ) {
        guard let module = SelectAssetAssembly.configureModule(
            wallet: wallet,
            selectedAssetId: selectedAssetId,
            chainAssets: chainAssets,
            searchTextsViewModel: .searchAssetPlaceholder,
            output: output,
            contextTag: contextTag,
            isFullSize: true
        ) else {
            return
        }

        view?.controller.present(module.view.controller, animated: true)
    }

    func showConfirmation(
        with params: PolkaswapPreviewParams,
        from view: ControllerBackedProtocol?
    ) -> PolkaswapSwapConfirmationModuleInput? {
        guard let module = PolkaswapSwapConfirmationAssembly.configureModule(params: params) else {
            return nil
        }

        view?.controller.navigationController?.pushViewController(
            module.view.controller,
            animated: true
        )

        return module.input
    }

    func showDisclaimer(
        moduleOutput: PolkaswapDisclaimerModuleOutput?,
        from view: ControllerBackedProtocol?
    ) {
        guard let module = PolkaswapDisclaimerAssembly.configureModule(moduleOutput: moduleOutput) else {
            return
        }

        view?.controller.present(module.view.controller, animated: true)
    }
}
