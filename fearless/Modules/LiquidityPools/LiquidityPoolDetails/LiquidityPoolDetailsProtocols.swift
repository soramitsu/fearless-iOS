typealias LiquidityPoolDetailsModuleCreationResult = (view: LiquidityPoolDetailsViewInput, input: LiquidityPoolDetailsModuleInput)

protocol LiquidityPoolDetailsViewInput: ControllerBackedProtocol {}

protocol LiquidityPoolDetailsViewOutput: AnyObject {
    func didLoad(view: LiquidityPoolDetailsViewInput)
}

protocol LiquidityPoolDetailsInteractorInput: AnyObject {
    func setup(with output: LiquidityPoolDetailsInteractorOutput)
}

protocol LiquidityPoolDetailsInteractorOutput: AnyObject {}

protocol LiquidityPoolDetailsRouterInput: AnyObject {}

protocol LiquidityPoolDetailsModuleInput: AnyObject {}

protocol LiquidityPoolDetailsModuleOutput: AnyObject {}
