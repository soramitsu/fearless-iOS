typealias LiquidityPoolSupplyModuleCreationResult = (
    view: LiquidityPoolSupplyViewInput,
    input: LiquidityPoolSupplyModuleInput
)

protocol LiquidityPoolSupplyRouterInput: AnyObject, AnyDismissable, SheetAlertPresentable {
    func showSelectAsset(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        chainAssets: [ChainAsset]?,
        selectedAssetId: AssetModel.Id?,
        contextTag: Int?,
        output: SelectAssetModuleOutput
    )
}

protocol LiquidityPoolSupplyModuleInput: AnyObject {}

protocol LiquidityPoolSupplyModuleOutput: AnyObject {}
