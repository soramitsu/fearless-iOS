import Foundation
import SSFModels
import SSFPools

final class LiquidityPoolDetailsRouter: LiquidityPoolDetailsRouterInput {
    func showSupplyFlow(
        liquidityPair: LiquidityPair,
        chain: ChainModel,
        wallet: MetaAccountModel,
        availablePairs: [LiquidityPair]?,
        didSubmitTransactionClosure: @escaping (String) -> Void,
        from view: ControllerBackedProtocol?
    ) {
        guard let controller = LiquidityPoolSupplyAssembly.configureModule(
            chain: chain,
            wallet: wallet,
            liquidityPair: liquidityPair,
            availablePairs: availablePairs,
            didSubmitTransactionClosure: didSubmitTransactionClosure
        )?.view.controller else {
            return
        }

        view?.controller.navigationController?.pushViewController(controller, animated: true)
    }

    func showRemoveFlow(
        liquidityPair: LiquidityPair,
        chain: ChainModel,
        wallet: MetaAccountModel,
        didSubmitTransactionClosure: @escaping (String) -> Void,
        from view: ControllerBackedProtocol?
    ) {
        guard let controller = LiquidityPoolRemoveLiquidityAssembly.configureModule(
            wallet: wallet,
            chain: chain,
            liquidityPair: liquidityPair,
            didSubmitTransactionClosure: didSubmitTransactionClosure
        )?.view.controller else {
            return
        }

        view?.controller.navigationController?.pushViewController(controller, animated: true)
    }
}
