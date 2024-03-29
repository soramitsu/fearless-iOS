typealias LiquidityPoolsListModuleCreationResult = (view: LiquidityPoolsListViewInput, input: LiquidityPoolsListModuleInput)

protocol LiquidityPoolsListViewInput: ControllerBackedProtocol {}

protocol LiquidityPoolsListViewOutput: AnyObject {
    func didLoad(view: LiquidityPoolsListViewInput)
}

protocol LiquidityPoolsListInteractorInput: AnyObject {
    func setup(with output: LiquidityPoolsListInteractorOutput)
}

protocol LiquidityPoolsListInteractorOutput: AnyObject {}

protocol LiquidityPoolsListRouterInput: AnyObject {}

protocol LiquidityPoolsListModuleInput: AnyObject {}

protocol LiquidityPoolsListModuleOutput: AnyObject {}
