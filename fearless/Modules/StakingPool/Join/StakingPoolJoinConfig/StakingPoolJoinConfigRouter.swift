import Foundation
import SSFModels

final class StakingPoolJoinConfigRouter: StakingPoolJoinConfigRouterInput {
    func presentPoolsList(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        inputAmount: Decimal
    ) {
        guard let module = StakingPoolJoinChoosePoolAssembly.configureModule(
            chainAsset: chainAsset,
            wallet: wallet,
            inputAmount: inputAmount
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            module.view.controller,
            animated: true
        )
    }

    func dismiss(view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
