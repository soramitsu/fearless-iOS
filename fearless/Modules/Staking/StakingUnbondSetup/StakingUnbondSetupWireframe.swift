import Foundation

final class StakingUnbondSetupWireframe: StakingUnbondSetupWireframeProtocol {
    func close(view: StakingUnbondSetupViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: nil)
    }

    func proceed(view _: StakingUnbondSetupViewProtocol?, amount _: Decimal) {
        // TODO: FLW-786
    }
}
