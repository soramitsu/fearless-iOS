import SSFModels

typealias TransferModuleCreationResult = (
    view: TransferViewInput,
    input: TransferModuleInput
)

@MainActor
protocol TransferRouterInput: SheetAlertPresentable, ErrorPresentable, BaseErrorPresentable, PresentDismissable {
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

    func showSelectNetwork(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        selectedChainId: ChainModel.Id?,
        chainModels: [ChainModel]?,
        delegate: SelectNetworkDelegate?
    )

    func showSelectAsset(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        selectedAssetId: AssetModel.Id?,
        chainAssets: [ChainAsset]?,
        output: SelectAssetModuleOutput
    )
    func showManageAsset(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel
    )
    func presentConfirm(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        useCase: TransferFlowUseCase,
        sendFlow: SendFlowInitialData,
        scamInfo: ScamInfo?
    )
}

protocol TransferModuleInput: AnyObject {}

protocol TransferModuleOutput: AnyObject {}
