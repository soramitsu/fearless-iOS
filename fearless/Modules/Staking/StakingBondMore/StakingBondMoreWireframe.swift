import Foundation

final class StakingBondMoreWireframe: StakingBondMoreWireframeProtocol {
    func showConfirmation(from view: ControllerBackedProtocol?, amount: Decimal) {
        guard let confirmation = StakingBondMoreConfirmViewFactory.createView(from: amount) else {
            return
        }

        view?.controller
            .navigationController?
            .pushViewController(confirmation.controller, animated: true)
    }

    func close(view: ControllerBackedProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: nil)
    }
}
