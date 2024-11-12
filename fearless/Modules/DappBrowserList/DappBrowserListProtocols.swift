import SSFModels

typealias DappBrowserListModuleCreationResult = (
    view: DappBrowserListViewInput,
    input: DappBrowserListModuleInput
)

protocol DappBrowserListRouterInput: PresentDismissable {
    func showDapp(
        from view: ControllerBackedProtocol?,
        dapp: TonDapp,
        wallet: MetaAccountModel
    )
}

protocol DappBrowserListModuleInput: AnyObject {}

protocol DappBrowserListModuleOutput: AnyObject {}
