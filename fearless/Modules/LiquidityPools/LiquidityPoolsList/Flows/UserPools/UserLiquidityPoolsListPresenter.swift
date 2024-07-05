import Foundation
import SSFPolkaswap
import SSFPools
import SSFModels
import SoraFoundation
import SSFStorageQueryKit

protocol UserLiquidityPoolsListInteractorInput {
    func setup(with output: UserLiquidityPoolsListInteractorOutput)

    func fetchPools()
    func cancelTasks()
}

final class UserLiquidityPoolsListPresenter {
    private let logger: Logger
    private let interactor: UserLiquidityPoolsListInteractorInput
    private let router: LiquidityPoolsListRouterInput
    private let chain: ChainModel
    private let wallet: MetaAccountModel
    private let viewModelFactory: UserLiquidityPoolsListViewModelFactory
    private weak var view: LiquidityPoolsListViewInput?
    private weak var moduleOutput: LiquidityPoolsListModuleOutput?
    private let type: LiquidityPoolListType

    private var pools: [LiquidityPair]?
    private var reserves: CachedStorageResponse<[PolkaswapPoolReservesInfo]>?
    private var apy: [PoolApyInfo]?
    private var accountPools: [AccountPool]?
    private var prices: [PriceData]?
    private var searchText: String?

    init(
        logger: Logger,
        interactor: UserLiquidityPoolsListInteractorInput,
        router: LiquidityPoolsListRouterInput,
        chain: ChainModel,
        wallet: MetaAccountModel,
        viewModelFactory: UserLiquidityPoolsListViewModelFactory,
        localizationManager: LocalizationManagerProtocol,
        moduleOutput: LiquidityPoolsListModuleOutput?,
        type: LiquidityPoolListType
    ) {
        self.logger = logger
        self.interactor = interactor
        self.router = router
        self.chain = chain
        self.wallet = wallet
        self.viewModelFactory = viewModelFactory
        self.moduleOutput = moduleOutput
        self.type = type

        self.localizationManager = localizationManager
    }

    private func provideViewModel() {
        let viewModel = viewModelFactory.buildViewModel(
            accountPools: accountPools,
            reserves: reserves,
            apyInfos: apy,
            chain: chain,
            prices: prices,
            locale: selectedLocale,
            wallet: wallet,
            type: type,
            searchText: searchText
        )

        view?.didReceive(viewModel: viewModel)

        moduleOutput?.didReceiveUserPoolCount((viewModel.poolViewModels?.count).or(0))
    }
}

extension UserLiquidityPoolsListPresenter: LiquidityPoolsListViewOutput {
    func didLoad(view: LiquidityPoolsListViewInput) {
        self.view = view

        interactor.setup(with: self)
    }

    func didAppearView() {}

    func didTapOn(viewModel: LiquidityPoolListCellModel) {
        guard let liquidityPair = viewModel.liquidityPair else {
            return
        }

        let reserves = reserves?.value?.first(where: { $0.poolId == liquidityPair.pairId })
        let reservesAddress = liquidityPair.reservesId.map { try? AddressFactory.address(for: Data(hex: $0), chain: chain) }
        let apyInfo = apy?.first(where: { $0.poolId == reservesAddress })
        let accountPool = accountPools?.first(where: { $0.poolId == liquidityPair.pairId })
        let assetIdPair = AssetIdPair(baseAssetIdCode: liquidityPair.baseAssetId, targetAssetIdCode: liquidityPair.targetAssetId)
        let input = LiquidityPoolDetailsInput.userPool(
            liquidityPair: liquidityPair,
            reserves: reserves,
            apyInfo: apyInfo,
            accountPool: accountPool,
            availablePairs: accountPools?.compactMap { $0.liquidityPair }
        )
        router.showPoolDetails(
            assetIdPair: assetIdPair,
            chain: chain,
            wallet: wallet,
            input: input,
            didSubmitTransactionClosure: { [weak self] hash in self?.moduleOutput?.didSubmitTransaction(transactionHash: hash) },
            from: view
        )
    }

    func didTapMoreButton() {
        moduleOutput?.didTapMoreUserPools()
    }

    func didTapBackButton() {
        interactor.cancelTasks()
        router.dismiss(view: view)
    }

    func searchTextDidChanged(_ text: String?) {
        searchText = text
        provideViewModel()
    }

    func handleRefreshControlEvent() {
        interactor.fetchPools()
    }
}

extension UserLiquidityPoolsListPresenter: UserLiquidityPoolsListInteractorOutput {
    func didReceiveUserPools(accountPools: [AccountPool]?) {
        self.accountPools = accountPools
        moduleOutput?.shouldShowUserPools(accountPools?.isNotEmpty == true)

        provideViewModel()
    }

    func didReceiveLiquidityPairs(pools: [LiquidityPair]?) {
        self.pools = pools
        provideViewModel()
    }

    func didReceivePoolsReserves(reserves: CachedStorageResponse<[PolkaswapPoolReservesInfo]>?) {
        self.reserves = reserves
        provideViewModel()
    }

    func didReceivePoolsAPY(apy: [PoolApyInfo]) {
        self.apy = apy
        provideViewModel()
    }

    func didReceivePrices(result: Result<[PriceData], Error>) {
        switch result {
        case let .success(prices):
            self.prices = prices
            provideViewModel()
        case let .failure(error):
            logger.customError(error)
        }
    }

    func didReceiveLiquidityPairsError(error: Error) {
        logger.customError(error)
    }

    func didReceivePoolsReservesError(error: Error) {
        logger.customError(error)
    }

    func didReceivePoolsApyError(error: Error) {
        logger.customError(error)
    }

    func didReceiveUserPoolsError(error: Error) {
        logger.customError(error)
    }
}

extension UserLiquidityPoolsListPresenter: LiquidityPoolsListModuleInput {
    func resetTasks() {
        interactor.cancelTasks()
    }

    func refreshData() {
        interactor.fetchPools()
    }
}

extension UserLiquidityPoolsListPresenter: Localizable {
    func applyLocalization() {}
}
