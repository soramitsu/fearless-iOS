import Foundation
import SSFModels
import SSFPolkaswap

final class LiquidityPoolsListRouter: LiquidityPoolsListRouterInput {
    func showPoolDetails(assetIdPair: AssetIdPair, chain: ChainModel, wallet: MetaAccountModel, input: LiquidityPoolDetailsInput, poolOperationFlowsClosure: @escaping () -> Void, from view: ControllerBackedProtocol?) {
        let module = LiquidityPoolDetailsAssembly.configureModule(assetIdPair: assetIdPair, chain: chain, wallet: wallet, input: input, poolOperationFlowsClosure: poolOperationFlowsClosure)

        guard let viewController = module?.view.controller else {
            return
        }

        view?.controller.navigationController?.pushViewController(viewController, animated: true)
    }
}
