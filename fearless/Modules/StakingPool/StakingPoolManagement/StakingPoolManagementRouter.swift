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
        status: NominationViewStatus?,
        from view: ControllerBackedProtocol?
    ) -> StakingPoolInfoModuleInput? {
        guard let module = StakingPoolInfoAssembly.configureModule(
            poolId: stakingPool.id,
            chainAsset: chainAsset,
            wallet: wallet,
            status: status
        ) else {
            return nil
        }

        let navigationController = FearlessNavigationController(rootViewController: module.view.controller)

        view?.controller.present(navigationController, animated: true)

        return module.input
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
        poolId _: UInt32,
        state _: InitiatedBonding,
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

        let navigationController = ImportantFlowViewFactory.createNavigation(
            from: validatorsView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }
}
