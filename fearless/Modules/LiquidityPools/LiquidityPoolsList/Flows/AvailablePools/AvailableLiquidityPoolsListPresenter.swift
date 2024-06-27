import Foundation
import SSFPolkaswap
import SSFPools
import SSFModels
import SoraFoundation
import SSFStorageQueryKit

protocol AvailableLiquidityPoolsListInteractorInput {
    func setup(with output: AvailableLiquidityPoolsListInteractorOutput)

    func fetchPools()
    func cancelTasks()
}

final class AvailableLiquidityPoolsListPresenter {
    private let logger: Logger
    private let interactor: AvailableLiquidityPoolsListInteractorInput
    private let chain: ChainModel
    private let wallet: MetaAccountModel
    private let viewModelFactory: AvailableLiquidityPoolsListViewModelFactory
    private weak var view: LiquidityPoolsListViewInput?
    private let router: LiquidityPoolsListRouterInput
    private weak var moduleOutput: LiquidityPoolsListModuleOutput?
    private let type: LiquidityPoolListType

    private var pairs: [LiquidityPair]?
    private var reserves: CachedStorageResponse<[PolkaswapPoolReservesInfo]>?
    private var apy: [PoolApyInfo]?
    private var prices: [PriceData]?
    private var searchText: String?

    init(
        logger: Logger,
        interactor: AvailableLiquidityPoolsListInteractorInput,
        router: LiquidityPoolsListRouterInput,
        chain: ChainModel,
        wallet: MetaAccountModel,
        viewModelFactory: AvailableLiquidityPoolsListViewModelFactory,
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
        guard let pairs, pairs.isNotEmpty else {
            return
        }

        let viewModel = viewModelFactory.buildViewModel(
            pairs: pairs,
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
    }
}

extension AvailableLiquidityPoolsListPresenter: LiquidityPoolsListViewOutput {
    func didLoad(view: LiquidityPoolsListViewInput) {
        self.view = view

        interactor.setup(with: self)
    }

    func didTapOn(viewModel: LiquidityPoolListCellModel) {
        guard let liquidityPair = viewModel.liquidityPair else {
            return
        }

        let reserves = reserves?.value?.first(where: { $0.poolId == liquidityPair.pairId })
        let reservesAddress = liquidityPair.reservesId.map { try? AddressFactory.address(for: Data(hex: $0), chain: chain) }
        let apyInfo = apy?.first(where: { $0.poolId == reservesAddress })

        let assetIdPair = AssetIdPair(baseAssetIdCode: liquidityPair.baseAssetId, targetAssetIdCode: liquidityPair.targetAssetId)
        let input = LiquidityPoolDetailsInput.availablePool(liquidityPair: liquidityPair, reserves: reserves, apyInfo: apyInfo, availablePairs: pairs)

        router.showPoolDetails(assetIdPair: assetIdPair, chain: chain, wallet: wallet, input: input, from: view)
    }

    func didTapMoreButton() {
        moduleOutput?.didTapMoreAvailablePools()
    }

    func didTapBackButton() {
        interactor.cancelTasks()
        router.dismiss(view: view)
    }

    func searchTextDidChanged(_ text: String?) {
        searchText = text
        provideViewModel()
    }

    func didAppearView() {
        let viewModel = viewModelFactory.buildLoadingViewModel(type: type)
        view?.didReceive(viewModel: viewModel)
    }
}

extension AvailableLiquidityPoolsListPresenter: AvailableLiquidityPoolsListInteractorOutput {
    func didReceiveLiquidityPairs(pairs: [LiquidityPair]?) {
        self.pairs = pairs
        provideViewModel()
    }

    func didReceivePoolsReserves(reserves: CachedStorageResponse<[PolkaswapPoolReservesInfo]>) {
        self.reserves = reserves.merge(with: self.reserves, priorityType: .remote)
        provideViewModel()
    }

    func didReceivePoolsAPY(apy: [PoolApyInfo]?) {
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
}

extension AvailableLiquidityPoolsListPresenter: LiquidityPoolsListModuleInput {
    func resetTasks() {
        interactor.cancelTasks()
    }
}

extension AvailableLiquidityPoolsListPresenter: Localizable {
    func applyLocalization() {}
}
