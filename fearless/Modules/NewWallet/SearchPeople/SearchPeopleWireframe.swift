import Foundation

final class SearchPeopleWireframe: SearchPeopleWireframeProtocol {
    func presentSend(
        from view: ControllerBackedProtocol?,
        to receiverAddress: String,
        asset: AssetModel,
        chain: ChainModel
    ) {
        guard let controller = WalletSendViewFactory.createView(receiverAddress: receiverAddress, asset: asset, chain: chain)?.controller else {
            return
        }

        view?.controller.navigationController?.pushViewController(controller, animated: true)
    }

    func close(_ view: ControllerBackedProtocol?) {
        view?.controller.dismiss(animated: true)
    }
}
