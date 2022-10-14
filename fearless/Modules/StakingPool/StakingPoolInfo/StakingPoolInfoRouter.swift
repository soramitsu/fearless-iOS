import Foundation

final class StakingPoolInfoRouter: StakingPoolInfoRouterInput {
    func proceedToSelectValidatorsStart(
        from view: ControllerBackedProtocol?,
        poolId: UInt32,
        state: ExistingBonding,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) {
        guard let recommendedView = SelectValidatorsStartViewFactory
            .createView(
                wallet: wallet,
                chainAsset: chainAsset,
                flow: .poolExisting(poolId: poolId, state: state)
            )
        else {
            return
        }

        view?.controller.navigationController?.pushViewController(recommendedView.controller, animated: true)
    }
}
