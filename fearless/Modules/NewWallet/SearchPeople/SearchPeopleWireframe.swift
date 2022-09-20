import Foundation

final class SearchPeopleWireframe: SearchPeopleWireframeProtocol {
    func presentSend(
        from view: ControllerBackedProtocol?,
        to receiverAddress: String,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        scamInfo: ScamInfo?,
        transferFinishBlock: WalletTransferFinishBlock?
    ) {
        guard let controller = WalletSendViewFactory.createView(
            receiverAddress: receiverAddress,
            chainAsset: chainAsset,
            wallet: wallet,
            scamInfo: scamInfo,
            transferFinishBlock: transferFinishBlock
        )?.controller else {
            return
        }

        view?.controller.navigationController?.pushViewController(controller, animated: true)
    }

    func presentScan(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        moduleOutput: WalletScanQRModuleOutput?
    ) {
        guard let controller = WalletScanQRViewFactory.createView(
            chainAsset: chainAsset,
            wallet: wallet,
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
