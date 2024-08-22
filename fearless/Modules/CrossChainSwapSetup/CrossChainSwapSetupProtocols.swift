import SSFModels

typealias CrossChainSwapSetupModuleCreationResult = (
    view: CrossChainSwapSetupViewInput,
    input: CrossChainSwapSetupModuleInput
)

protocol CrossChainSwapSetupRouterInput: AnyObject, PresentDismissable, SheetAlertPresentable, ErrorPresentable, BaseErrorPresentable {
    func showSelectNetwork(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        selectedChainId: ChainModel.Id?,
        chainModels: [ChainModel]?,
        contextTag: Int?,
        delegate: SelectNetworkDelegate?
    )

    func showSelectAsset(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        output: SelectAssetModuleOutput
    )

    func presentScan(
        from view: ControllerBackedProtocol?,
        moduleOutput: ScanQRModuleOutput
    )

    func presentHistory(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        moduleOutput: ContactsModuleOutput
    )

    func showWalletManagment(
        selectedWalletId: MetaAccountId?,
        from view: ControllerBackedProtocol?,
        moduleOutput: WalletsManagmentModuleOutput?
    )
}

protocol CrossChainSwapSetupModuleInput: AnyObject {}

protocol CrossChainSwapSetupModuleOutput: AnyObject {}
