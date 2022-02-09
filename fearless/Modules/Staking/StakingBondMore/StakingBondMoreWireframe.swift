import Foundation

final class StakingBondMoreWireframe: StakingBondMoreWireframeProtocol {
    func showConfirmation(
        from view: ControllerBackedProtocol?,
        amount: Decimal,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    ) {
        guard let confirmation = StakingBondMoreConfirmViewFactory.createView(chain: chain, asset: asset, selectedAccount: selectedAccount, amount: amount) else {
            return
        }

        view?.controller
            .navigationController?
            .pushViewController(confirmation.controller, animated: true)
    }

    func close(view: ControllerBackedProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: nil)
    }
}
