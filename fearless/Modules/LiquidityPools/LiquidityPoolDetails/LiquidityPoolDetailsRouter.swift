import Foundation
import SSFModels
import SSFPools

final class LiquidityPoolDetailsRouter: LiquidityPoolDetailsRouterInput {
    func showSupplyFlow(liquidityPair: LiquidityPair, chain: ChainModel, wallet: MetaAccountModel, from view: ControllerBackedProtocol?) {
        guard let controller = LiquidityPoolSupplyAssembly.configureModule(chain: chain, wallet: wallet, liquidityPair: liquidityPair)?.view.controller else {
            return
        }

        view?.controller.navigationController?.pushViewController(controller, animated: true)
    }

    func showRemoveFlow(liquidityPair _: LiquidityPair, chain _: ChainModel, wallet _: MetaAccountModel, from _: ControllerBackedProtocol?) {}
}
