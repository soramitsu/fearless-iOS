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
        items: [ManageStakingItem],
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    ) {
        let maybeManageView = ModalPickerFactory.createPickerForList(
            items,
            delegate: delegate,
            context: context)
        guard let manageView = maybeManageView else { return }

        view?.controller.present(manageView, animated: true, completion: nil)
    }

    func showRecommendedValidators(from view: StakingMainViewProtocol?,
                                   existingBonding: ExistingBonding) {
        guard let recommendedView = RecommendedValidatorsViewFactory
                .createChangeTargetsView(with: existingBonding) else {
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

    func showRewardPayouts(from view: ControllerBackedProtocol?) {
        view?.controller.dismiss(animated: false, completion: nil)

        guard let rewardPayoutsView = StakingRewardPayoutsViewFactory.createView() else { return }

        let navigationController = FearlessNavigationController(rootViewController: rewardPayoutsView.controller)
        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showAccountsSelection(from view: StakingMainViewProtocol?) {
        guard let accountsView = AccountManagementViewFactory.createViewForSwitch() else {
            return
        }

        accountsView.controller.hidesBottomBarWhenPushed = true

        view?.controller.navigationController?.pushViewController(accountsView.controller,
                                                                  animated: true)
    }
}
