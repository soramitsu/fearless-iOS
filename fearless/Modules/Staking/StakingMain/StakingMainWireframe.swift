import Foundation

final class StakingMainWireframe: StakingMainWireframeProtocol {
    func showSetupAmount(from view: StakingMainViewProtocol?, amount: Decimal?) {
        guard let amountView = StakingAmountViewFactory.createView(with: amount) else {
            return
        }

        let navigationController = FearlessNavigationController(rootViewController: amountView.controller)

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showStories(from view: StakingMainViewProtocol?, startingFrom index: Int) {
        guard let storiesView = StoriesViewFactory.createView() else {
            return
        }

        storiesView.controller.modalPresentationStyle = .fullScreen
        view?.controller.present(storiesView.controller, animated: true, completion: nil)
    }
}
