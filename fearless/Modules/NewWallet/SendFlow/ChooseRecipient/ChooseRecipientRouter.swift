final class ChooseRecipientRouter: ChooseRecipientRouterProtocol {
    private let flow: SendFlow
    private let transferFinishBlock: WalletTransferFinishBlock?

    init(flow: SendFlow, transferFinishBlock: WalletTransferFinishBlock?) {
        self.flow = flow
        self.transferFinishBlock = transferFinishBlock
    }

    func presentSendAmount(
        from view: ControllerBackedProtocol?,
        to receiverAddress: String,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        scamInfo: ScamInfo?
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

    func presentHistory(from _: ControllerBackedProtocol?) {
        // TODO: Contact list transition
    }

    func close(_ view: ControllerBackedProtocol?) {
        view?.controller.dismiss(animated: true)
    }
}
