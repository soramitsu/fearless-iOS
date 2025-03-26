import SSFModels

typealias AssetManagementModuleCreationResult = (
    view: AssetManagementViewInput,
    input: AssetManagementModuleInput
)

protocol AssetManagementRouterInput: PresentDismissable, ErrorPresentable, SheetAlertPresentable {
    func showSelectNetwork(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        delegate: NetworkManagmentModuleOutput?
    )
    
    func showAddERC20Token(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        moduleOutput: AddERC20TokenModuleOutput?
    )
}

protocol AssetManagementModuleInput: AnyObject {}

protocol AssetManagementModuleOutput: AnyObject {}
