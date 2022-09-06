final class ChooseRecipientRouter: ChooseRecipientRouterProtocol {
    private let flow: SendFlow
    private let transferFinishBlock: WalletTransferFinishBlock?

    init(flow: SendFlow, transferFinishBlock: WalletTransferFinishBlock?) {
        self.flow = flow
        self.transferFinishBlock = transferFinishBlock
    }

    func presentSendAmount(
        from _: ControllerBackedProtocol?,
        to _: String,
        asset _: AssetModel,
        chain _: ChainModel,
        wallet _: MetaAccountModel
    ) {
        // TODO: Send amount transition
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

    func presentHistory(from _: ControllerBackedProtocol?) {
        // TODO: Contact list transition
    }

    func close(_ view: ControllerBackedProtocol?) {
        view?.controller.dismiss(animated: true)
    }
}
