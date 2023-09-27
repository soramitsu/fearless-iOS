import SSFModels

typealias ReceiveAndRequestAssetModuleCreationResult = (
    view: ReceiveAndRequestAssetViewInput,
    input: ReceiveAndRequestAssetModuleInput
)

protocol ReceiveAndRequestAssetRouterInput:
    SheetAlertPresentable,
    ErrorPresentable,
    SharingPresentable,
    AddressOptionsPresentable,
    PresentDismissable {
    func showSelectAsset(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        selectedAssetId: AssetModel.Id?,
        chainAssets: [ChainAsset]?,
        output: SelectAssetModuleOutput
    )
}

protocol ReceiveAndRequestAssetModuleInput: AnyObject {}

protocol ReceiveAndRequestAssetModuleOutput: AnyObject {}
