import SSFModels
import SSFPools

typealias LiquidityPoolRemoveLiquidityModuleCreationResult = (
    view: LiquidityPoolRemoveLiquidityViewInput,
    input: LiquidityPoolRemoveLiquidityModuleInput
)

protocol LiquidityPoolRemoveLiquidityRouterInput: AnyObject, ErrorPresentable, SheetAlertPresentable, AnyDismissable, AllDonePresentable {
    func showConfirmation(
        chain: ChainModel,
        wallet: MetaAccountModel,
        liquidityPair: LiquidityPair,
        info: RemoveLiquidityInfo,
        didSubmitTransactionClosure: @escaping (String) -> Void,
        from view: ControllerBackedProtocol?
    )

    func complete(
        on view: ControllerBackedProtocol?,
        title: String,
        chainAsset: ChainAsset
    )
}

protocol LiquidityPoolRemoveLiquidityModuleInput: AnyObject {}

protocol LiquidityPoolRemoveLiquidityModuleOutput: AnyObject {}
