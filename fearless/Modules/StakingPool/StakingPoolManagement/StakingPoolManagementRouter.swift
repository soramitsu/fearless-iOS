import Foundation

final class StakingPoolManagementRouter: StakingPoolManagementRouterInput {
    func presentStakeMoreFlow(
        flow: StakingBondMoreFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?
    ) {
        guard let bondMoreView = StakingBondMoreViewFactory.createView(
            chainAsset: chainAsset,
            wallet: wallet,
            flow: flow
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(bondMoreView.controller, animated: true)
    }

    func presentUnbondFlow(
        flow: StakingUnbondSetupFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?
    ) {
        guard let unbondView = StakingUnbondSetupViewFactory.createView(
            chainAsset: chainAsset,
            wallet: wallet,
            flow: flow
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(unbondView.controller, animated: true)
    }

    func presentPoolInfo(
        stakingPool: StakingPool,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?
    ) {
        guard let module = StakingPoolInfoAssembly.configureModule(
            stakingPool: stakingPool,
            chainAsset: chainAsset,
            wallet: wallet
        ) else {
            return
        }

        let navigationController = FearlessNavigationController(rootViewController: module.view.controller)

        view?.controller.present(navigationController, animated: true)
    }

    func presentOptions(
        viewModels: [TitleWithSubtitleViewModel],
        callback: ModalPickerSelectionCallback?,
        from view: ControllerBackedProtocol?
    ) {
        guard let picker = ModalPickerFactory.createPicker(viewModels: viewModels, callback: callback) else {
            return
        }

        view?.controller.present(picker, animated: true)
    }

    func presentClaim(
        rewardAmount: Decimal,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?
    ) {
        guard
            let module = StakingPayoutConfirmationViewFactory.createView(
                chainAsset: chainAsset,
                wallet: wallet,
                flow: .pool(rewardAmount: rewardAmount)
            )
        else {
            return
        }

        view?.controller.navigationController?.pushViewController(module.controller, animated: true)
    }

    func presentRedeemFlow(
        flow: StakingRedeemConfirmationFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?
    ) {
        guard
            let redeemModule = StakingRedeemConfirmationViewFactory.createView(
                chainAsset: chainAsset,
                wallet: wallet,
                flow: flow,
                redeemCompletion: {
                    view?.controller.navigationController?.popViewController(animated: true)
                }
            )
        else {
            return
        }

        view?.controller.navigationController?.pushViewController(redeemModule.controller, animated: true)
    }

    func proceedToSelectValidatorsStart(
        from view: ControllerBackedProtocol?,
        poolId: UInt32,
        state: InitiatedBonding,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) {
        guard let recommendedView = SelectValidatorsStartViewFactory
            .createView(
                wallet: wallet,
                chainAsset: chainAsset,
                flow: .poolInitiated(poolId: poolId, state: state)
            )
        else {
            return
        }

        view?.controller.navigationController?.pushViewController(recommendedView.controller, animated: true)
    }
}
