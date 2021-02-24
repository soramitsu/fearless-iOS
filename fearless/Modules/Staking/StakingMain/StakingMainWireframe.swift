import Foundation

final class StakingMainWireframe: StakingMainWireframeProtocol {
    func showSetupAmount(from view: StakingMainViewProtocol?) {
        guard let amountView = StakingAmountViewFactory.createView() else {
            return
        }

        let navigationController = FearlessNavigationController(rootViewController: amountView.controller)

        view?.controller.present(navigationController, animated: true, completion: nil)
    }
}
