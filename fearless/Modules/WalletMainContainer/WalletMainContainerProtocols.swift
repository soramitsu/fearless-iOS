typealias WalletMainContainerModuleCreationResult = (
    view: WalletMainContainerViewInput,
    input: WalletMainContainerModuleInput
)

protocol WalletMainContainerViewInput: ControllerBackedProtocol, HiddableBarWhenPushed {
    func didReceiveViewModel(_ viewModel: WalletMainContainerViewModel)
}

protocol WalletMainContainerViewOutput: AnyObject {
    func didLoad(view: WalletMainContainerViewInput)
    func didTapOnSwitchWallet()
    func didTapOnQR()
    func didTapSearch()
    func didTapSelectNetwork()
}

protocol WalletMainContainerInteractorInput: AnyObject {
    func setup(with output: WalletMainContainerInteractorOutput)
    func saveChainIdForFilter(_ chainId: ChainModel.Id?)
}

protocol WalletMainContainerInteractorOutput: AnyObject {
    func didReceiveAccount(_ account: MetaAccountModel)
    func didReceiveSelectedChain(_ chain: ChainModel?)
    func didReceiveError(_ error: Error)
}

protocol WalletMainContainerRouterInput: AlertPresentable, ErrorPresentable {
    func showWalletManagment(
        from view: WalletMainContainerViewInput?,
        moduleOutput: WalletsManagmentModuleOutput?
    )
    func showScanQr(from view: WalletMainContainerViewInput?)
    func showSearch(from view: WalletMainContainerViewInput?)
    func showSelectNetwork(
        from view: WalletMainContainerViewInput?,
        wallet: MetaAccountModel,
        selectedChainId: ChainModel.Id?,
        chainModels: [ChainModel]?,
        delegate: SelectNetworkDelegate?
    )
    func showCreateNewWallet(from view: WalletMainContainerViewInput?)
    func showImportWallet(from view: WalletMainContainerViewInput?)
    func showSendFlow(
        from view: WalletMainContainerViewInput?,
        chainAsset: ChainAsset,
        selectedMetaAccount: MetaAccountModel,
        transferFinishBlock: WalletTransferFinishBlock?
    )

    func showReceiveFlow(
        from view: WalletMainContainerViewInput?,
        chainAsset: ChainAsset,
        selectedMetaAccount: MetaAccountModel
    )
}

protocol WalletMainContainerModuleInput: AnyObject {}

protocol WalletMainContainerModuleOutput: AnyObject {}
