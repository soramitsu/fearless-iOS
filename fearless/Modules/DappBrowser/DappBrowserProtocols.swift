import SSFModels

typealias DappBrowserModuleCreationResult = (
    view: DappBrowserViewInput,
    input: DappBrowserModuleInput
)

protocol DappBrowserRouterInput: AccountManagementPresentable {
    func showWalletManagment(
        from view: ControllerBackedProtocol?,
        moduleOutput: WalletsManagmentModuleOutput?
    )
    func showSelectNetwork(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        chains: [ChainModel],
        delegate: NetworkManagmentModuleOutput?,
        initialFilter: NetworkManagmentFilter
    )
    func showDapp(
        from view: ControllerBackedProtocol?,
        dapp: TonDapp,
        wallet: MetaAccountModel,
        moduleOutput: TonWebBridgeModuleOutput?
    )
    func showList(
        from view: ControllerBackedProtocol?,
        dapps: [TonDapp],
        title: String,
        wallet: MetaAccountModel
    )
}

protocol DappBrowserModuleInput: AnyObject {}

protocol DappBrowserModuleOutput: AnyObject {}
