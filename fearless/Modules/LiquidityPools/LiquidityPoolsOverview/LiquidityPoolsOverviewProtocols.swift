typealias LiquidityPoolsOverviewModuleCreationResult = (view: LiquidityPoolsOverviewViewInput, input: LiquidityPoolsOverviewModuleInput)

protocol LiquidityPoolsOverviewViewInput: ControllerBackedProtocol {}

protocol LiquidityPoolsOverviewViewOutput: AnyObject {
    func didLoad(view: LiquidityPoolsOverviewViewInput)
}

protocol LiquidityPoolsOverviewInteractorInput: AnyObject {
    func setup(with output: LiquidityPoolsOverviewInteractorOutput)
}

protocol LiquidityPoolsOverviewInteractorOutput: AnyObject {}

protocol LiquidityPoolsOverviewRouterInput: AnyObject {}

protocol LiquidityPoolsOverviewModuleInput: AnyObject {}

protocol LiquidityPoolsOverviewModuleOutput: AnyObject {}
