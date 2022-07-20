import Foundation

final class StakingUnbondSetupWireframe: StakingUnbondSetupWireframeProtocol {
    func close(view: StakingUnbondSetupViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: nil)
    }

    func proceed(
        view: StakingUnbondSetupViewProtocol?,
        flow: StakingUnbondConfirmFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) {
        guard let confirmationView = StakingUnbondConfirmViewFactory.createView(
            chainAsset: chainAsset,
            wallet: wallet,
            flow: flow
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            confirmationView.controller,
            animated: true
        )
    }
}
