import SSFModels

typealias ConnectedAccountsModuleCreationResult = (
    view: ConnectedAccountsViewInput,
    input: ConnectedAccountsModuleInput
)

protocol ConnectedAccountsRouterInput: AnyDismissable, AuthorizationPresentable {
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
}

protocol ConnectedAccountsModuleInput: AnyObject {}

protocol ConnectedAccountsModuleOutput: AnyObject {}
