typealias AssetManagementModuleCreationResult = (
    view: AssetManagementViewInput,
    input: AssetManagementModuleInput
)

protocol AssetManagementRouterInput: PresentDismissable {
    func showSelectNetwork(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        delegate: NetworkManagmentModuleOutput?
    )
}

protocol AssetManagementModuleInput: AnyObject {}

protocol AssetManagementModuleOutput: AnyObject {}
