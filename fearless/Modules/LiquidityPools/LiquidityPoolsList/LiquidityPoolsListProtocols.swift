typealias LiquidityPoolsListModuleCreationResult = (view: LiquidityPoolsListViewInput, input: LiquidityPoolsListModuleInput)

protocol LiquidityPoolsListViewInput: ControllerBackedProtocol {
    func didReceive(viewModel: LiquidityPoolListViewModel)
}

protocol LiquidityPoolsListViewOutput: AnyObject {
    func didLoad(view: LiquidityPoolsListViewInput)
}

protocol LiquidityPoolsListInteractorInput: AnyObject {
    func setup(with output: AvailableLiquidityPoolsListInteractorOutput)
    func fetchPools()
}

protocol LiquidityPoolsListRouterInput: AnyObject {}

protocol LiquidityPoolsListModuleInput: AnyObject {}

protocol LiquidityPoolsListModuleOutput: AnyObject {}
