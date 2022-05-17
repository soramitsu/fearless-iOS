import Foundation

final class StakingUnbondSetupWireframe: StakingUnbondSetupWireframeProtocol {
    func close(view: StakingUnbondSetupViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: nil)
    }

    func proceed(
        view: StakingUnbondSetupViewProtocol?,
        amount: Decimal,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    ) {
        guard let confirmationView = StakingUnbondConfirmViewFactory.createView(
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount,
            amount: amount
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            confirmationView.controller,
            animated: true
        )
    }
}
