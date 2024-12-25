import SSFModels

typealias ConnectedAccountsModuleCreationResult = (
    view: ConnectedAccountsViewInput,
    input: ConnectedAccountsModuleInput
)

protocol ConnectedAccountsRouterInput:
    AnyDismissable,
    AuthorizationPresentable,
    AccountScorePresentable,
    SheetAlertPresentable {
    func showAccountDetails(
        from view: ControllerBackedProtocol?,
        metaAccount: MetaAccountModel
    )

    func showOptions(
        from view: ControllerBackedProtocol?,
        ecosystem: Ecosystem,
        wallet: MetaAccountModel,
        chains: [ChainModel],
        moduleOutput: EcosystemOptionsModuleOutput?
    )
    func showWalletDetails(
        view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        chains: [ChainModel]?
    )
    func showMnemonicExport(
        flow: ExportFlow,
        from view: ControllerBackedProtocol?
    )
    func showKeystoreExport(
        flow: ExportFlow,
        from view: ControllerBackedProtocol?
    )
    func showSeedExport(
        flow: ExportFlow,
        from view: ControllerBackedProtocol?
    )
    func showUniqueChainSourceSelection(
        from view: ControllerBackedProtocol?,
        items: [ReplaceChainOption],
        callback: @escaping ModalPickerSelectionCallback
    )
    func showCreate(
        wallet: MetaAccountModel,
        chains: [ChainModel],
        from view: ControllerBackedProtocol?
    )
    func showImport(
        wallet: MetaAccountModel,
        chains: [ChainModel],
        defaultSource: AccountImportSource,
        from view: ControllerBackedProtocol?
    )
}

protocol ConnectedAccountsModuleInput: AnyObject {}

protocol ConnectedAccountsModuleOutput: AnyObject {}
