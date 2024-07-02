import Foundation
import SSFPools
import SSFModels

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

    func showConfirmation(
        chain: ChainModel,
        wallet: MetaAccountModel,
        liquidityPair: LiquidityPair,
        inputData: LiquidityPoolSupplyConfirmInputData,
        flowClosure: @escaping () -> Void,
        from view: ControllerBackedProtocol?
    ) {
        guard let module = LiquidityPoolSupplyConfirmAssembly.configureModule(
            chain: chain,
            wallet: wallet,
            liquidityPair: liquidityPair,
            inputData: inputData,
            flowClosure: flowClosure
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(module.view.controller, animated: true)
    }
}
