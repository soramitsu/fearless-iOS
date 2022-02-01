import Foundation

final class SearchPeopleWireframe: SearchPeopleWireframeProtocol {
    func presentSend(
        from view: ControllerBackedProtocol?,
        to receiverAddress: String,
        asset: AssetModel,
        chain: ChainModel
    ) {
        guard let controller = WalletSendViewFactory.createView(
            receiverAddress: receiverAddress,
            asset: asset,
            chain: chain
        )?.controller else {
            return
        }

        view?.controller.navigationController?.pushViewController(controller, animated: true)
    }

    func presentScan(
        from view: ControllerBackedProtocol?,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel,
        moduleOutput: WalletScanQRModuleOutput?
    ) {
        guard let controller = WalletScanQRViewFactory.createView(
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount,
            moduleOutput: moduleOutput
        )?.controller else {
            return
        }

        view?.controller.present(controller, animated: true, completion: nil)
    }

    func close(_ view: ControllerBackedProtocol?) {
        view?.controller.dismiss(animated: true)
    }
}
