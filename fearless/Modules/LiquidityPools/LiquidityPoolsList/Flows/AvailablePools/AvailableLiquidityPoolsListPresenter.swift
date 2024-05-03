import Foundation
import SSFPolkaswap
import SSFPools
import SSFModels
import SoraFoundation
import SSFStorageQueryKit

protocol AvailableLiquidityPoolsListInteractorInput {
    func setup(with output: AvailableLiquidityPoolsListInteractorOutput)

    func fetchPools()
    func fetchApy()
}

final class AvailableLiquidityPoolsListPresenter {
    private let logger: Logger
    private let interactor: AvailableLiquidityPoolsListInteractorInput
    private let chain: ChainModel
    private let wallet: MetaAccountModel
    private let viewModelFactory: AvailableLiquidityPoolsListViewModelFactory
    private weak var view: LiquidityPoolsListViewInput?

    private var pairs: [LiquidityPair]?
    private var reserves: CachedStorageResponse<[PolkaswapPoolReservesInfo]>?
    private var apy: [PoolApyInfo]?
    private var prices: [PriceData]?

    init(
        logger: Logger,
        interactor: AvailableLiquidityPoolsListInteractorInput,
        chain: ChainModel,
        wallet: MetaAccountModel,
        viewModelFactory: AvailableLiquidityPoolsListViewModelFactory,
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
            pairs: pairs,
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

extension AvailableLiquidityPoolsListPresenter: LiquidityPoolsListViewOutput {
    func didLoad(view: LiquidityPoolsListViewInput) {
        self.view = view

        interactor.setup(with: self)
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

extension AvailableLiquidityPoolsListPresenter: LiquidityPoolsListModuleInput {}

extension AvailableLiquidityPoolsListPresenter: Localizable {
    func applyLocalization() {}
}
