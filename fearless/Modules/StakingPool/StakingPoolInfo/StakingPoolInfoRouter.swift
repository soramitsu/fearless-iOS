import Foundation

final class StakingPoolInfoRouter: StakingPoolInfoRouterInput {
    func proceedToSelectValidatorsStart(
        from view: ControllerBackedProtocol?,
        poolId _: UInt32,
        state _: ExistingBonding,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) {
        guard let validatorsView = YourValidatorListViewFactory.createView(
            chainAsset: chainAsset,
            wallet: wallet,
            flow: .pool
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(validatorsView.controller, animated: true)
    }
}
