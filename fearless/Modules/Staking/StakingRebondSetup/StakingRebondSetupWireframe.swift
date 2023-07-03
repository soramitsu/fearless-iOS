import Foundation
import SSFModels

final class StakingRebondSetupWireframe: StakingRebondSetupWireframeProtocol {
    func proceed(
        view: StakingRebondSetupViewProtocol?,
        amount _: Decimal,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: StakingRebondConfirmationFlow
    ) {
        guard let rebondView = StakingRebondConfirmationViewFactory.createView(
            chainAsset: chainAsset,
            wallet: wallet,
            flow: flow
        ) else {
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
