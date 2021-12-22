import Foundation

final class StakingMainWireframe: StakingMainWireframeProtocol {
    func showSetupAmount(
        from view: StakingMainViewProtocol?,
        amount: Decimal?,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    ) {
        guard let amountView = StakingAmountViewFactory.createView(
            with: amount,
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount
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
            .createChangeTargetsView(
                selectedAccount: selectedAccount,
                asset: asset,
                chain: chain,
                state: existingBonding
            )
        else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(
            from: recommendedView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showStories(from view: ControllerBackedProtocol?, startingFrom index: Int) {
        guard let storiesView = StoriesViewFactory.createView(with: index) else {
            return
        }

        storiesView.controller.modalPresentationStyle = .overFullScreen
        view?.controller.present(storiesView.controller, animated: true, completion: nil)
    }

    func showRewardDetails(from view: ControllerBackedProtocol?, maxReward: Decimal, avgReward: Decimal) {
        let infoVew = ModalInfoFactory.createRewardDetails(for: maxReward, avgReward: avgReward)

        view?.controller.present(infoVew, animated: true, completion: nil)
    }

    func showRewardPayoutsForNominator(
        from view: ControllerBackedProtocol?,
        stashAddress: AccountAddress,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    ) {
        guard let rewardPayoutsView = StakingRewardPayoutsViewFactory
            .createViewForNominator(
                chain: chain,
                asset: asset,
                selectedAccount: selectedAccount,
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
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    ) {
        guard let rewardPayoutsView = StakingRewardPayoutsViewFactory
            .createViewForValidator(
                chain: chain,
                asset: asset,
                selectedAccount: selectedAccount,
                stashAddress: stashAddress
            ) else { return }

        let navigationController = ImportantFlowViewFactory.createNavigation(
            from: rewardPayoutsView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showStakingBalance(
        from view: ControllerBackedProtocol?,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    ) {
        guard let stakingBalance = StakingBalanceViewFactory.createView(
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount
        ) else { return }
        let controller = stakingBalance.controller
        controller.hidesBottomBarWhenPushed = true

        view?.controller
            .navigationController?
            .pushViewController(controller, animated: true)
    }

    func showNominatorValidators(
        from view: ControllerBackedProtocol?,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    ) {
        guard let validatorsView = YourValidatorListViewFactory.createView(
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount
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

    func showAccountsSelection(from view: StakingMainViewProtocol?) {
        guard let accountsView = AccountManagementViewFactory.createViewForSwitch() else {
            return
        }

        accountsView.controller.hidesBottomBarWhenPushed = true

        view?.controller.navigationController?.pushViewController(
            accountsView.controller,
            animated: true
        )
    }

    func showRewardDestination(
        from view: ControllerBackedProtocol?,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    ) {
        guard let displayView = StakingRewardDestSetupViewFactory.createView(
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount
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
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    ) {
        guard let bondMoreView = StakingBondMoreViewFactory.createView(
            asset: asset,
            chain: chain,
            selectedAccount: selectedAccount
        ) else { return }
        let navigationController = ImportantFlowViewFactory.createNavigation(
            from: bondMoreView.controller
        )
        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showRedeem(
        from view: ControllerBackedProtocol?,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    ) {
        guard let redeemView = StakingRedeemViewFactory.createView(
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount
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
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    ) {
        let analyticsView = AnalyticsContainerViewFactory.createView(
            mode: mode,
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount
        )
        analyticsView.controller.hidesBottomBarWhenPushed = true
        view?.controller.navigationController?.pushViewController(analyticsView.controller, animated: true)
    }

    func showYourValidatorInfo(
        _ stashAddress: AccountAddress,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel,
        from view: ControllerBackedProtocol?
    ) {
        guard let validatorInfoView = ValidatorInfoViewFactory.createView(
            address: stashAddress,
            asset: asset,
            chain: chain,
            selectedAccount: selectedAccount
        ) else { return }
        let navigationController = FearlessNavigationController(rootViewController: validatorInfoView.controller)
        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showChainAssetSelection(
        from view: StakingMainViewProtocol?,
        selectedChainAssetId: ChainAssetId?,
        delegate: AssetSelectionDelegate
    ) {
        let stakingFilter: AssetSelectionFilter = { _, asset in asset.staking != nil }

        guard let selectionView = AssetSelectionViewFactory.createView(
            delegate: delegate,
            selectedChainId: selectedChainAssetId,
            assetFilter: stakingFilter
        ) else {
            return
        }

        let navigationController = FearlessNavigationController(
            rootViewController: selectionView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }
}
