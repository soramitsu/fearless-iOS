import Foundation

final class StakingPoolStartRouter: StakingPoolStartRouterInput {
    func presentJoinFlow(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?
    ) {
        let module = StakingPoolJoinConfigAssembly.configureModule(chainAsset: chainAsset, wallet: wallet)

        guard let controller = module?.view.controller else {
            return
        }

        view?.controller.navigationController?.pushViewController(controller, animated: true)
    }
}
