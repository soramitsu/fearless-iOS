import Foundation

final class StakingMainWireframe: StakingMainWireframeProtocol {
    func showSetupAmount(from view: StakingMainViewProtocol?, amount: Decimal?) {
        guard let amountView = StakingAmountViewFactory.createView(with: amount) else {
            return
        }

        let navigationController = FearlessNavigationController(rootViewController: amountView.controller)

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showManageStaking(from view: StakingMainViewProtocol?) {
        guard let manageView = ModalPickerFactory.createPickerForList(
            [.rewardPayouts],
            delegate: nil,
            context: nil) else { return }
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
}
