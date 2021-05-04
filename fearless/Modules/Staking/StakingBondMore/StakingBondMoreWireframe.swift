import Foundation

final class StakingBondMoreWireframe: StakingBondMoreWireframeProtocol {
    func showConfirmation(from view: ControllerBackedProtocol?, amount _: Decimal) {
        guard let confirmation = StakingBMConfirmationViewFactory.createView() else {
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
