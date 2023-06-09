import Foundation
import SoraFoundation
import SSFModels

final class ControllerAccountWireframe: ControllerAccountWireframeProtocol {
    func showConfirmation(
        from view: ControllerBackedProtocol?,
        controllerAccountItem: ChainAccountResponse,
        asset: AssetModel,
        chain: ChainModel,
        selectedAccount: MetaAccountModel
    ) {
        guard let confirmation = ControllerAccountConfirmationViewFactory.createView(
            controllerAccountItem: controllerAccountItem,
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount
        ) else { return }
        view?.controller.navigationController?.pushViewController(confirmation.controller, animated: true)
    }

    func close(view: ControllerBackedProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: nil)
    }
}
