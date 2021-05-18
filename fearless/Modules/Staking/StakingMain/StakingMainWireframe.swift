import Foundation

final class StakingMainWireframe: StakingMainWireframeProtocol {
    func showSetupAmount(from view: StakingMainViewProtocol?, amount: Decimal?) {
        guard let amountView = StakingAmountViewFactory.createView(with: amount) else {
            return
        }

        let navigationController = FearlessNavigationController(rootViewController: amountView.controller)

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

    func showRecommendedValidators(
        from view: StakingMainViewProtocol?,
        existingBonding: ExistingBonding
    ) {
        guard let recommendedView = RecommendedValidatorsViewFactory
            .createChangeTargetsView(with: existingBonding)
        else {
            return
        }

        let rootController = recommendedView.controller
        let navigationController = FearlessNavigationController(rootViewController: rootController)

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

    func showRewardPayoutsForNominator(from view: ControllerBackedProtocol?, stashAddress: AccountAddress) {
        guard let rewardPayoutsView = StakingRewardPayoutsViewFactory
            .createViewForNominator(stashAddress: stashAddress) else { return }

        let navigationController = FearlessNavigationController(rootViewController: rewardPayoutsView.controller)
        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showRewardPayoutsForValidator(from view: ControllerBackedProtocol?, stashAddress: AccountAddress) {
        guard let rewardPayoutsView = StakingRewardPayoutsViewFactory
            .createViewForValidator(stashAddress: stashAddress) else { return }

        let navigationController = FearlessNavigationController(rootViewController: rewardPayoutsView.controller)
        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showStakingBalance(from view: ControllerBackedProtocol?) {
        guard let stakingBalance = StakingBalanceViewFactory.createView() else { return }
        let controller = stakingBalance.controller
        controller.hidesBottomBarWhenPushed = true

        view?.controller
            .navigationController?
            .pushViewController(controller, animated: true)
    }

    func showNominatorValidators(from view: ControllerBackedProtocol?) {
        guard let validatorsView = YourValidatorsViewFactory.createView() else {
            return
        }

        let navigationController = FearlessNavigationController(rootViewController: validatorsView.controller)
        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showControllerAccount(from view: ControllerBackedProtocol?) {
        guard let controllerAccount = ControllerAccountViewFactory.createView() else {
            return
        }
        let navigationController = FearlessNavigationController(rootViewController: controllerAccount.controller)
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

    func showBondMore(from view: ControllerBackedProtocol?) {
        guard let bondMoreView = StakingBondMoreViewFactory.createView() else { return }
        let navigationController = FearlessNavigationController(rootViewController: bondMoreView.controller)
        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showRedeem(from view: ControllerBackedProtocol?) {
        guard let redeemView = StakingRedeemViewFactory.createView() else {
            return
        }

        let navigationController = FearlessNavigationController(rootViewController: redeemView.controller)

        view?.controller.present(navigationController, animated: true, completion: nil)
    }
}
