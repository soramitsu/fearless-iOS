import Foundation

final class StakingBondMoreWireframe: StakingBondMoreWireframeProtocol {
    func showConfirmation(from _: ControllerBackedProtocol?, amount _: Decimal) {
        // TODO: FLW-772
    }

    func close(view: ControllerBackedProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: nil)
    }
}
