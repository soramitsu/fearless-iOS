typealias CrossChainModuleCreationResult = (
    view: CrossChainViewInput,
    input: CrossChainModuleInput
)

protocol CrossChainRouterInput: PresentDismissable {
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
        chainAssets: [ChainAsset]?,
        selectedAssetId: AssetModel.Id?,
        output: SelectAssetModuleOutput
    )

    func showConfirmation(
        from view: ControllerBackedProtocol?,
        data: CrossChainConfirmationData
    )
}

protocol CrossChainModuleInput: AnyObject {}

protocol CrossChainModuleOutput: AnyObject {}
