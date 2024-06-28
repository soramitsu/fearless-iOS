import SSFModels

typealias LiquidityPoolsOverviewModuleCreationResult = (view: LiquidityPoolsOverviewViewInput, input: LiquidityPoolsOverviewModuleInput)

protocol LiquidityPoolsOverviewViewInput: ControllerBackedProtocol {
    func changeUserPoolsVisibility(visible: Bool)
    func didReceiveUserPoolsCount(count: Int)
}

protocol LiquidityPoolsOverviewViewOutput: AnyObject {
    func didLoad(view: LiquidityPoolsOverviewViewInput)
    func backButtonClicked()
    func handleRefreshControlEvent()
}

protocol LiquidityPoolsOverviewInteractorInput: AnyObject {
    func setup(with output: LiquidityPoolsOverviewInteractorOutput)
}

protocol LiquidityPoolsOverviewInteractorOutput: AnyObject {}

protocol LiquidityPoolsOverviewRouterInput: AnyObject, AnyDismissable {
    func showAllAvailablePools(
        chain: ChainModel,
        wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?,
        moduleOutput: LiquidityPoolsListModuleOutput?
    )
    func showAllUserPools(
        chain: ChainModel,
        wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?,
        moduleOutput: LiquidityPoolsListModuleOutput?
    )
}

protocol LiquidityPoolsOverviewModuleInput: AnyObject {}

protocol LiquidityPoolsOverviewModuleOutput: AnyObject {}
