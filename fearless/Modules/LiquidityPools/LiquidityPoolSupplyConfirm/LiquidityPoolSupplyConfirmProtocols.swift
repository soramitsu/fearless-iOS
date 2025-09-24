import SSFModels

typealias LiquidityPoolSupplyConfirmModuleCreationResult = (
    view: LiquidityPoolSupplyConfirmViewInput,
    input: LiquidityPoolSupplyConfirmModuleInput
)

protocol LiquidityPoolSupplyConfirmRouterInput: AnyObject, BaseErrorPresentable, SheetAlertPresentable, AnyDismissable, AllDonePresentable {
    func complete(
        on view: ControllerBackedProtocol?,
        title: String,
        chainAsset: ChainAsset
    )
}

protocol LiquidityPoolSupplyConfirmModuleInput: AnyObject {}

protocol LiquidityPoolSupplyConfirmModuleOutput: AnyObject {}
