import SSFPools
import SSFModels

typealias LiquidityPoolDetailsModuleCreationResult = (view: LiquidityPoolDetailsViewInput, input: LiquidityPoolDetailsModuleInput)

protocol LiquidityPoolDetailsRouterInput: AnyObject, AnyDismissable, SheetAlertPresentable {
    func showSupplyFlow(liquidityPair: LiquidityPair, chain: ChainModel, wallet: MetaAccountModel, availablePairs: [LiquidityPair]?, from view: ControllerBackedProtocol?)
    func showRemoveFlow(liquidityPair: LiquidityPair, chain: ChainModel, wallet: MetaAccountModel, from view: ControllerBackedProtocol?)
}

protocol LiquidityPoolDetailsModuleInput: AnyObject {}

protocol LiquidityPoolDetailsModuleOutput: AnyObject {}
