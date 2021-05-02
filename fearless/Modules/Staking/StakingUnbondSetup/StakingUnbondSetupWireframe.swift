import Foundation

final class StakingUnbondSetupWireframe: StakingUnbondSetupWireframeProtocol {
    func close(view: StakingUnbondSetupViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: nil)
    }

    func proceed(view: StakingUnbondSetupViewProtocol?, amount: Decimal) {
        // TODO: FLW-786
    }
}
