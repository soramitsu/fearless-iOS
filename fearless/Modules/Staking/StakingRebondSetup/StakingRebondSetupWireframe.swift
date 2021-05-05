import Foundation

final class StakingRebondSetupWireframe: StakingRebondSetupWireframeProtocol {
    func proceed(view _: StakingRebondSetupViewProtocol?, amount _: Decimal) {
        // TODO: FLW-795 https://soramitsu.atlassian.net/browse/FLW-795
    }

    func close(view: StakingRebondSetupViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: nil)
    }
}
