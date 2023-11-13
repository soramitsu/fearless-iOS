import Foundation
import SSFModels

final class StakingMainWireframe: StakingMainWireframeProtocol {
    func showSetupAmount(
        from view: StakingMainViewProtocol?,
        amount: Decimal?,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel,
        rewardChainAsset: ChainAsset?
    ) {
        guard let amountView = StakingAmountViewFactory.createView(
            with: amount,
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount,
            rewardChainAsset: rewardChainAsset
        ) else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(from: amountView.controller)

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showManageStaking(
        from view: StakingMainViewProtocol?,
        items: [StakingManageOption],
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    ) {
        let maybeManageView = ModalPickerFactory.createPickerForList(
            items,
            delegate: delegate,
            context: context
        )
        guard let manageView = maybeManageView else { return }

        view?.controller.present(manageView, animated: true, completion: nil)
    }

    func proceedToSelectValidatorsStart(
        from view: StakingMainViewProtocol?,
        existingBonding: ExistingBonding,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    ) {
        guard let recommendedView = SelectValidatorsStartViewFactory
            .createView(
                wallet: selectedAccount,
                chainAsset: ChainAsset(chain: chain, asset: asset),
                flow: .relaychainExisting(state: existingBonding)
            )
        else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(
            from: recommendedView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showStories(from view: ControllerBackedProtocol?, startingFrom index: Int, chainAsset: ChainAsset) {
        guard let storiesView = StoriesViewFactory.createView(with: index, chainAsset: chainAsset) else {
            return
        }

        storiesView.controller.modalPresentationStyle = .overFullScreen
        view?.controller.present(storiesView.controller, animated: true, completion: nil)
    }

    func showRewardDetails(
        from view: ControllerBackedProtocol?,
        maxReward: (title: String, amount: Decimal),
        avgReward: (title: String, amount: Decimal)
    ) {
        let infoVew = ModalInfoFactory.createRewardDetails(for: maxReward, avgReward: avgReward)

        view?.controller.present(infoVew, animated: true, completion: nil)
    }

    func showRewardPayoutsForNominator(
        from view: ControllerBackedProtocol?,
        stashAddress: AccountAddress,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) {
        guard let rewardPayoutsView = StakingRewardPayoutsViewFactory
            .createViewForNominator(
                chainAsset: chainAsset,
                wallet: wallet,
                stashAddress: stashAddress
            ) else { return }

        let navigationController = ImportantFlowViewFactory.createNavigation(
            from: rewardPayoutsView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showRewardPayoutsForValidator(
        from view: ControllerBackedProtocol?,
        stashAddress: AccountAddress,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) {
        guard let rewardPayoutsView = StakingRewardPayoutsViewFactory
            .createViewForValidator(
                chainAsset: chainAsset,
                wallet: wallet,
                stashAddress: stashAddress
            ) else { return }

        let navigationController = ImportantFlowViewFactory.createNavigation(
            from: rewardPayoutsView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showStakingBalance(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: StakingBalanceFlow
    ) {
        guard let stakingBalance = StakingBalanceViewFactory.createView(
            chainAsset: chainAsset,
            wallet: wallet,
            flow: flow
        ) else { return }
        let controller = stakingBalance.controller
        controller.hidesBottomBarWhenPushed = true

        view?.controller
            .navigationController?
            .pushViewController(controller, animated: true)
    }

    func showNominatorValidators(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) {
        guard let validatorsView = YourValidatorListViewFactory.createView(
            chainAsset: chainAsset,
            wallet: wallet,
            flow: .relaychain
        ) else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(
            from: validatorsView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showControllerAccount(
        from view: ControllerBackedProtocol?,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    ) {
        guard let controllerAccount = ControllerAccountViewFactory.createView(
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount
        ) else {
            return
        }
        let navigationController = ImportantFlowViewFactory.createNavigation(
            from: controllerAccount.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showAccountsSelection(
        from view: StakingMainViewProtocol?,
        moduleOutput: WalletsManagmentModuleOutput
    ) {
        guard
            let module = WalletsManagmentAssembly.configureModule(
                shouldSaveSelected: true,
                moduleOutput: moduleOutput
            )
        else {
            return
        }

        view?.controller.present(module.view.controller, animated: true)
    }

    func showRewardDestination(
        from view: ControllerBackedProtocol?,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel,
        rewardChainAsset: ChainAsset?
    ) {
        guard let displayView = StakingRewardDestSetupViewFactory.createView(
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount,
            rewardChainAsset: rewardChainAsset
        ) else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(
            from: displayView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showBondMore(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: StakingBondMoreFlow
    ) {
        guard let bondMoreView = StakingBondMoreViewFactory.createView(
            chainAsset: chainAsset,
            wallet: wallet,
            flow: flow
        ) else { return }
        let navigationController = ImportantFlowViewFactory.createNavigation(
            from: bondMoreView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showRedeem(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: StakingRedeemConfirmationFlow
    ) {
        guard let redeemView = StakingRedeemConfirmationViewFactory.createView(
            chainAsset: chainAsset,
            wallet: wallet,
            flow: flow,
            redeemCompletion: nil
        ) else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(
            from: redeemView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showAnalytics(
        from view: ControllerBackedProtocol?,
        mode: AnalyticsContainerViewMode,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: AnalyticsRewardsFlow
    ) {
        let analyticsView = AnalyticsContainerViewFactory.createView(
            mode: mode,
            chainAsset: chainAsset,
            wallet: wallet,
            flow: flow
        )
        analyticsView.controller.hidesBottomBarWhenPushed = true
        view?.controller.navigationController?.pushViewController(analyticsView.controller, animated: true)
    }

    func showYourValidatorInfo(
        chainAsset: ChainAsset,
        selectedAccount: MetaAccountModel,
        flow: ValidatorInfoFlow,
        from view: ControllerBackedProtocol?
    ) {
        guard let validatorInfoView = ValidatorInfoViewFactory.createView(
            chainAsset: chainAsset,
            wallet: selectedAccount,
            flow: flow
        ) else {
            return
        }
        let navigationController = FearlessNavigationController(rootViewController: validatorInfoView.controller)
        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showChainAssetSelection(
        from view: StakingMainViewProtocol?,
        selectedChainAsset: ChainAsset?,
        delegate: AssetSelectionDelegate
    ) {
        let stakingFilter: AssetSelectionFilter = { chainAsset in chainAsset.staking != nil }

        guard let selectedMetaAccount = SelectedWalletSettings.shared.value,
              let selectionView = AssetSelectionViewFactory.createView(
                  delegate: delegate,
                  type: .normal(chainAsset: selectedChainAsset),
                  selectedMetaAccount: selectedMetaAccount,
                  assetFilter: stakingFilter,
                  assetSelectionType: .staking
              ) else {
            return
        }

        let navigationController = FearlessNavigationController(
            rootViewController: selectionView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }
}
