import Foundation

final class StakingRebondSetupWireframe: StakingRebondSetupWireframeProtocol {
    func proceed(view: StakingRebondSetupViewProtocol?, amount: Decimal) {
        guard let rebondView = StakingRebondConfirmationViewFactory
            .createView(for: .custom(amount: amount)) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            rebondView.controller,
            animated: true
        )
    }

    func close(view: StakingRebondSetupViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: nil)
    }
}
