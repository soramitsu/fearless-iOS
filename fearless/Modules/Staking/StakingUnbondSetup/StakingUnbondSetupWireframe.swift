import Foundation

final class StakingUnbondSetupWireframe: StakingUnbondSetupWireframeProtocol {
    func close(view: StakingUnbondSetupViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: nil)
    }

    func proceed(view: StakingUnbondSetupViewProtocol?, amount: Decimal) {
        guard let confirmationView = StakingUnbondConfirmViewFactory.createView(from: amount) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            confirmationView.controller,
            animated: true
        )
    }
}
