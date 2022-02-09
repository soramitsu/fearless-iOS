import Foundation

final class StakingRebondSetupWireframe: StakingRebondSetupWireframeProtocol {
    func proceed(
        view: StakingRebondSetupViewProtocol?,
        amount: Decimal,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    ) {
        guard let rebondView = StakingRebondConfirmationViewFactory.createView(
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount,
            variant: .custom(amount: amount)
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
