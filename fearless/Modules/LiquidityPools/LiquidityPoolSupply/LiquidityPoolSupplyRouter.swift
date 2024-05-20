import Foundation

final class LiquidityPoolSupplyRouter: LiquidityPoolSupplyRouterInput {
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
}
