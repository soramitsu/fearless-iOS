import SSFModels

typealias WalletMainContainerModuleCreationResult = (
    view: WalletMainContainerViewInput,
    input: WalletMainContainerModuleInput
)

protocol WalletMainContainerViewInput: ControllerBackedProtocol, HiddableBarWhenPushed {
    func didReceiveViewModel(_ viewModel: WalletMainContainerViewModel)
    func didReceiveAccountScoreViewModel(_ viewModel: AccountScoreViewModel)
}

protocol WalletMainContainerViewOutput: AnyObject {
    func didLoad(view: WalletMainContainerViewInput)
    func didTapOnSwitchWallet()
    func didTapOnQR()
    func didTapSearch()
    func didTapSelectNetwork()
    func didTapOnBalance()
    func addressDidCopied()
}

protocol WalletMainContainerInteractorInput: AnyObject {
    func setup(with output: WalletMainContainerInteractorOutput)
    func walletConnect(uri: String) async throws
}

protocol WalletMainContainerInteractorOutput: AnyObject {
    func didReceiveAccount(_ account: MetaAccountModel)
    func didReceiveSelected(tuple: (select: NetworkManagmentFilter, chains: [ChainModel]))
    func didReceiveError(_ error: Error)
    func didReceiveControllerAccountIssue(issue: ControllerAccountIssue, hasStashItem: Bool)
    func didReceiveStashAccountIssue(address: String)
    func didReceiveAccountStatistics(_ accountStatistics: AccountStatistics)
    func didReceiveAccountStatisticsError(_ error: Error)
}

protocol WalletMainContainerRouterInput: SheetAlertPresentable, ErrorPresentable, ApplicationStatusPresentable, AccountManagementPresentable {
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

    func showMainStaking()
}

protocol WalletMainContainerModuleInput: AnyObject {}

protocol WalletMainContainerModuleOutput: AnyObject {}
