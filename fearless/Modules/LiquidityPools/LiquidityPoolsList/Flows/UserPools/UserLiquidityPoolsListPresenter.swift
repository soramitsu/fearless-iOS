import Foundation
import SSFPolkaswap
import SSFPools
import SSFModels
import SoraFoundation
import SSFStorageQueryKit

protocol UserLiquidityPoolsListInteractorInput {
    func setup(with output: UserLiquidityPoolsListInteractorOutput)

    func fetchPools()
    func fetchApy()
}

final class UserLiquidityPoolsListPresenter {
    private let logger: Logger
    private let interactor: UserLiquidityPoolsListInteractorInput
    private let chain: ChainModel
    private let wallet: MetaAccountModel
    private let viewModelFactory: UserLiquidityPoolsListViewModelFactory
    private weak var view: LiquidityPoolsListViewInput?

    private var pools: [LiquidityPair]?
    private var reserves: CachedStorageResponse<[PolkaswapPoolReservesInfo]>?
    private var apy: [PoolApyInfo]?
    private var prices: [PriceData]?

    init(
        logger: Logger,
        interactor: UserLiquidityPoolsListInteractorInput,
        chain: ChainModel,
        wallet: MetaAccountModel,
        viewModelFactory: UserLiquidityPoolsListViewModelFactory,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.logger = logger
        self.interactor = interactor
        self.chain = chain
        self.wallet = wallet
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }

    private func provideViewModel() {
        let viewModel = viewModelFactory.buildViewModel(
            pools: pools,
            reserves: reserves,
            apyInfos: apy,
            chain: chain,
            prices: prices,
            locale: selectedLocale,
            wallet: wallet
        )

        view?.didReceive(viewModel: viewModel)
    }
}

extension UserLiquidityPoolsListPresenter: LiquidityPoolsListViewOutput {
    func didLoad(view: LiquidityPoolsListViewInput) {
        self.view = view

        interactor.setup(with: self)
    }
}

extension UserLiquidityPoolsListPresenter: UserLiquidityPoolsListInteractorOutput {
    func didReceiveUserPools(pools: [LiquidityPair]?) {
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
}

extension UserLiquidityPoolsListPresenter: LiquidityPoolsListModuleInput {}

extension UserLiquidityPoolsListPresenter: Localizable {
    func applyLocalization() {}
}
