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
    func didTapBackButton()
    func searchTextDidChanged(_ text: String?)
    func didAppearView()
    func handleRefreshControlEvent()
}

protocol LiquidityPoolsListInteractorInput: AnyObject {
    func setup(with output: AvailableLiquidityPoolsListInteractorOutput)
    func fetchPools()
}

protocol LiquidityPoolsListRouterInput: AnyObject, AnyDismissable {
    func showPoolDetails(
        assetIdPair: AssetIdPair,
        chain: ChainModel,
        wallet: MetaAccountModel,
        input: LiquidityPoolDetailsInput,
        didSubmitTransactionClosure: @escaping (String) -> Void,
        from view: ControllerBackedProtocol?
    )
}

protocol LiquidityPoolsListModuleInput: AnyObject {
    func resetTasks()
    func refreshData()
}

protocol LiquidityPoolsListModuleOutput: AnyObject {
    func didTapMoreUserPools()
    func didTapMoreAvailablePools()
    func shouldShowUserPools(_ shouldShow: Bool)
    func didReceiveUserPoolCount(_ userPoolsCount: Int)
    func didSubmitTransaction(transactionHash: String)
}
