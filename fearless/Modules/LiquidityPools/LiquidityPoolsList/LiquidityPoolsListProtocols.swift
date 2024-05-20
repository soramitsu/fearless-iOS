import SSFPolkaswap
import SSFModels
import SSFPools

typealias LiquidityPoolsListModuleCreationResult = (view: LiquidityPoolsListViewInput, input: LiquidityPoolsListModuleInput)

protocol LiquidityPoolsListViewInput: ControllerBackedProtocol {
    func didReceive(viewModel: LiquidityPoolListViewModel)
}

protocol LiquidityPoolsListViewOutput: AnyObject {
    func didLoad(view: LiquidityPoolsListViewInput)
    func didTapOn(viewModel: LiquidityPoolListCellModel)
    func didTapMoreButton()
}

protocol LiquidityPoolsListInteractorInput: AnyObject {
    func setup(with output: AvailableLiquidityPoolsListInteractorOutput)
    func fetchPools()
}

protocol LiquidityPoolsListRouterInput: AnyObject {
    func showPoolDetails(
        assetIdPair: AssetIdPair,
        chain: ChainModel,
        wallet: MetaAccountModel,
        input: LiquidityPoolDetailsInput,
        from view: ControllerBackedProtocol?
    )
}

protocol LiquidityPoolsListModuleInput: AnyObject {}

protocol LiquidityPoolsListModuleOutput: AnyObject {
    func didTapMoreUserPools()
    func didTapMoreAvailablePools()
}
