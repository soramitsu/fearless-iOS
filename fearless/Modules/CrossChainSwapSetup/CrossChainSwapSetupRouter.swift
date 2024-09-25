import Foundation
import SSFModels

final class CrossChainSwapSetupRouter: CrossChainSwapSetupRouterInput {
    func showSelectAsset(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        output: SelectAssetModuleOutput,
        flow: MultichainChainFetchingFlow,
        selectedChainAsset: ChainAsset?
    ) {
        guard let module = MultichainAssetSelectionAssembly.configureModule(
            flow: flow,
            wallet: wallet,
            selectAssetModuleOutput: output,
            contextTag: flow.contextTag,
            selectedChainAsset: selectedChainAsset
        ) else {
            return
        }

        view?.controller.present(module.view.controller, animated: true)
    }

    func presentConfirm(
        swapFromChainAsset: ChainAsset,
        swapToChainAsset: ChainAsset,
        wallet: MetaAccountModel,
        swap: CrossChainSwap,
        from view: ControllerBackedProtocol?
    ) {
        guard let module = CrossChainSwapConfirmAssembly.configureModule(
            swapFromChainAsset: swapFromChainAsset,
            swapToChainAsset: swapToChainAsset,
            wallet: wallet,
            swap: swap
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(module.view.controller, animated: true)
    }
}
