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
        crossChainSwapParameters: CrossChainSwapParameters,
        from view: ControllerBackedProtocol?
    ) {
        guard let module = CrossChainSwapConfirmAssembly.configureModule(
            crossChainSwapParameters: crossChainSwapParameters,
            approveTxHash: nil
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
    
    func presentFundsPermission(
        mode: CrossChainFundsPermissionMode,
        crossChainSwapParameters: CrossChainSwapParameters,
        from view: ControllerBackedProtocol?
    ) {
        guard let module = CrossChainFundsPermissionAssembly.configureModule(
            mode: mode,
            crossChainSwapParameters: crossChainSwapParameters
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(module.view.controller, animated: true)
    }
}
