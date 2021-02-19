import Foundation

final class StakingAmountWireframe: StakingAmountWireframeProtocol {
    func close(view: StakingAmountViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: nil)
    }
}
