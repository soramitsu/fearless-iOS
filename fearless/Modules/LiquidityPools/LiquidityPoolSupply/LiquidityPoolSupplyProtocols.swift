import SSFModels
import SSFPools

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

    func showConfirmation(
        chain: ChainModel,
        wallet: MetaAccountModel,
        liquidityPair: LiquidityPair,
        inputData: LiquidityPoolSupplyConfirmInputData,
        didSubmitTransactionClosure: @escaping (String) -> Void,
        from view: ControllerBackedProtocol?
    )
}

protocol LiquidityPoolSupplyModuleInput: AnyObject {}

protocol LiquidityPoolSupplyModuleOutput: AnyObject {}
