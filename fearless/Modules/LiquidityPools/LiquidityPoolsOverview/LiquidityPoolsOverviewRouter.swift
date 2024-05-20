import Foundation
import SSFModels

final class LiquidityPoolsOverviewRouter: LiquidityPoolsOverviewRouterInput {
    func showAllAvailablePools(
        chain: ChainModel,
        wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?,
        moduleOutput: LiquidityPoolsListModuleOutput?
    ) {
        guard let controller = LiquidityPoolsListAssembly.configureAvailablePoolsModule(
            chain: chain,
            wallet: wallet,
            moduleOutput: moduleOutput,
            type: .full
        )?.view.controller else {
            return
        }

        view?.controller.navigationController?.pushViewController(controller, animated: true)
    }

    func showAllUserPools(
        chain: ChainModel,
        wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?,
        moduleOutput: LiquidityPoolsListModuleOutput?
    ) {
        guard let controller = LiquidityPoolsListAssembly.configureUserPoolsModule(
            chain: chain,
            wallet: wallet,
            moduleOutput: moduleOutput,
            type: .full
        )?.view.controller else {
            return
        }

        view?.controller.navigationController?.pushViewController(controller, animated: true)
    }
}
