import Foundation
import SSFModels

final class CrossChainSwapSetupRouter: CrossChainSwapSetupRouterInput {
    func showSelectAsset(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        output: SelectAssetModuleOutput,
        flow: MultichainChainFetchingFlow,
        selectedChainAsset: ChainAsset?,
        filter: ((ChainAsset) throws -> Bool)?
    ) {
        guard let module = MultichainAssetSelectionAssembly.configureModule(
            flow: flow,
            wallet: wallet,
            selectAssetModuleOutput: output,
            contextTag: flow.contextTag,
            selectedChainAsset: selectedChainAsset,
            filter: filter
        ) else {
            return
        }

        view?.controller.present(module.view.controller, animated: true)
    }

    func presentConfirm(
        swapFromChainAsset: ChainAsset,
        swapToChainAsset: ChainAsset,
        wallet: MetaAccountModel,
        amount: String,
        selectedDexIds: [String]?,
        swap: CrossChainSwap,
        slippage: Decimal,
        from view: ControllerBackedProtocol?
    ) {
        guard let module = CrossChainSwapConfirmAssembly.configureModule(
            swapFromChainAsset: swapFromChainAsset,
            swapToChainAsset: swapToChainAsset,
            wallet: wallet,
            amount: amount,
            selectedDexIds: selectedDexIds,
            swap: swap,
            slippage: slippage
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(module.view.controller, animated: true)
    }

    func presentLiquiditySourcesSelection(
        sourceChainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        amount: String,
        wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?,
        moduleOutput: DexListModuleOutput?,
        selectedDexIds: [String]?
    ) {
        guard let module = DexListAssembly.configureModule(
            sourceChainAsset: sourceChainAsset,
            destinationChainAsset: destinationChainAsset,
            amount: amount,
            wallet: wallet,
            moduleOutput: moduleOutput,
            selectedDexIds: selectedDexIds
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(module.view.controller, animated: true)
    }

    func presentBridgeSelection(
        sourceChainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        amount: String,
        wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?,
        moduleOutput: BridgeListModuleOutput?,
        selectedSort: UInt8
    ) {
        guard let module = BridgeListAssembly.configureModule(
            sourceChainAsset: sourceChainAsset,
            destinationChainAsset: destinationChainAsset,
            amount: amount,
            wallet: wallet,
            moduleOutput: moduleOutput,
            selectedSort: selectedSort
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(module.view.controller, animated: true)
    }
}
