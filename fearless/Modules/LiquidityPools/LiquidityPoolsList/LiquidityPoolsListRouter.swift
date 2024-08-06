import Foundation
import SSFModels
import SSFPolkaswap

final class LiquidityPoolsListRouter: LiquidityPoolsListRouterInput {
    func showPoolDetails(
        assetIdPair: AssetIdPair,
        chain: ChainModel,
        wallet: MetaAccountModel,
        input: LiquidityPoolDetailsInput,
        didSubmitTransactionClosure: @escaping (String) -> Void,
        from view: ControllerBackedProtocol?
    ) {
        let module = LiquidityPoolDetailsAssembly.configureModule(
            assetIdPair: assetIdPair,
            chain: chain,
            wallet: wallet,
            input: input,
            didSubmitTransactionClosure: didSubmitTransactionClosure
        )

        guard let viewController = module?.view.controller else {
            return
        }

        view?.controller.navigationController?.pushViewController(viewController, animated: true)
    }
}
