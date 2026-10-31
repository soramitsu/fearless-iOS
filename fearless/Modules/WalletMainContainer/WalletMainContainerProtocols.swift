import SSFModels

typealias WalletMainContainerModuleCreationResult = (
    view: WalletMainContainerViewInput,
    input: WalletMainContainerModuleInput
)

protocol WalletMainContainerViewInput: ControllerBackedProtocol, HiddableBarWhenPushed {
    func didReceiveViewModel(_ viewModel: WalletMainContainerViewModel)
    func didReceiveNftAvailability(isNftAvailable: Bool)
}

protocol WalletMainContainerViewOutput: AnyObject {
    func didLoad(view: WalletMainContainerViewInput)
    func didTapOnSwitchWallet()
    func didTapOnQR()
    func didTapSearch()
    func didTapSelectNetwork()
    func didTapOnBalance()
    func addressDidCopied()
    func didTapAccountScore()
}

protocol WalletMainContainerInteractorInput: AnyObject {
    func setup(with output: WalletMainContainerInteractorOutput)
    func walletConnect(uri: String) async throws
    func acknowledge(_ notice: StoredWalletRecordsNotice)
    func acknowledgeUniversalWalletPasswordNotice()
    func switchNoPasswordAccounts(_ accounts: [UniversalWalletNoPasswordAccount])
}

protocol WalletMainContainerInteractorOutput: AnyObject {
    func didReceiveAccount(_ account: MetaAccountModel)
    func didReceiveSelected(tuple: (select: NetworkManagmentFilter, chains: [ChainModel]))
    func didReceiveError(_ error: Error)
    func didReceiveControllerAccountIssue(issue: ControllerAccountIssue, hasStashItem: Bool)
    func didReceiveStashAccountIssue(address: String)
    func didReceiveNftAvailability(isNftAvailable: Bool)
    func didReceiveStoredWalletRecordsNotices(_ notices: [StoredWalletRecordsNotice])
    /// The selected wallet has a password that some of its universal accounts do not use.
    func didReceiveUniversalWalletNoPasswordAccounts(_ accounts: [UniversalWalletNoPasswordAccount])
    func didReceiveUniversalWalletSwitchOutcomes(
        _ outcomes: [UniversalWalletSlot: UniversalWalletSwitchOutcome],
        for accounts: [UniversalWalletNoPasswordAccount]
    )
}

protocol WalletMainContainerRouterInput: SheetAlertPresentable, ErrorPresentable, ApplicationStatusPresentable, AccountManagementPresentable, AccountScorePresentable {
    func showWalletManagment(
        from view: WalletMainContainerViewInput?,
        moduleOutput: WalletsManagmentModuleOutput?
    )
    func showScanQr(from view: WalletMainContainerViewInput?, moduleOutput: ScanQRModuleOutput)
    func showSearch(from view: WalletMainContainerViewInput?, wallet: MetaAccountModel)
    func showSelectNetwork(
        from view: WalletMainContainerViewInput?,
        wallet: MetaAccountModel,
        delegate: NetworkManagmentModuleOutput?
    )
    func showSelectCurrency(
        from view: WalletMainContainerViewInput?,
        wallet: MetaAccountModel
    )

    func showSendFlow(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        initialData: SendFlowInitialData
    )

    func showControllerAccountFlow(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    )

    func showMainStaking(from view: WalletMainContainerViewInput?)
    func showWalletDetails(from view: WalletMainContainerViewInput?, wallet: MetaAccountModel)
}

protocol WalletMainContainerModuleInput: AnyObject {}

protocol WalletMainContainerModuleOutput: AnyObject {}
