import Foundation

final class StakingBondMoreWireframe: StakingBondMoreWireframeProtocol {
    func showConfirmation(
        from view: ControllerBackedProtocol?,
        flow: StakingBondMoreConfirmationFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) {
        guard let confirmation = StakingBondMoreConfirmViewFactory.createView(
            chainAsset: chainAsset,
            wallet: wallet,
            flow: flow
        ) else {
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
