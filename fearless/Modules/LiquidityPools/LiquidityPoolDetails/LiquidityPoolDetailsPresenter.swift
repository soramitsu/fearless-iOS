import Foundation
import SoraFoundation
import SSFPolkaswap
import SSFModels
import SSFPools
import SSFStorageQueryKit

enum LiquidityPoolDetailsInput {
    case initial
    case userPool(liquidityPair: LiquidityPair?, reserves: PolkaswapPoolReservesInfo?, apyInfo: PoolApyInfo?, accountPool: AccountPool?)
    case availablePool(liquidityPair: LiquidityPair?, reserves: PolkaswapPoolReservesInfo?, apyInfo: PoolApyInfo?)

    var liquidityPair: LiquidityPair? {
        switch self {
        case .initial:
            return nil
        case let .userPool(liquidityPair, _, _, _):
            return liquidityPair
        case let .availablePool(liquidityPair, _, _):
            return liquidityPair
        }
    }

    var reserves: PolkaswapPoolReservesInfo? {
        switch self {
        case .initial:
            return nil
        case let .userPool(_, reserves, _, _):
            return reserves
        case let .availablePool(_, reserves, _):
            return reserves
        }
    }

    var apyInfo: PoolApyInfo? {
        switch self {
        case .initial:
            return nil
        case let .userPool(_, _, apyInfo, _):
            return apyInfo
        case let .availablePool(_, _, apyInfo):
            return apyInfo
        }
    }

    var accountPool: AccountPool? {
        switch self {
        case .initial:
            return nil
        case let .userPool(_, _, _, accountPool):
            return accountPool
        case .availablePool:
            return nil
        }
    }

    var isUserPool: Bool {
        switch self {
        case .userPool:
            return true
        default:
            return false
        }
    }
}

protocol LiquidityPoolDetailsViewInput: ControllerBackedProtocol {
    func bind(viewModel: LiquidityPoolDetailsViewModel?)
}

protocol LiquidityPoolDetailsInteractorInput: AnyObject {
    func setup(with output: LiquidityPoolDetailsInteractorOutput)
}

final class LiquidityPoolDetailsPresenter {
    // MARK: Private properties

    private weak var view: LiquidityPoolDetailsViewInput?
    private let router: LiquidityPoolDetailsRouterInput
    private let interactor: LiquidityPoolDetailsInteractorInput
    private let assetIdPair: AssetIdPair
    private let logger: LoggerProtocol
    private let viewModelFactory: LiquidityPoolDetailsViewModelFactory
    private let chain: ChainModel
    private let wallet: MetaAccountModel
    private let input: LiquidityPoolDetailsInput

    private var liquidityPair: LiquidityPair?
    private var accountPoolInfo: AccountPool?
    private var reserves: CachedStorageResponse<PolkaswapPoolReservesInfo>?
    private var apyInfo: PoolApyInfo?
    private var priceData: [PriceData]?

    // MARK: - Constructors

    init(
        interactor: LiquidityPoolDetailsInteractorInput,
        router: LiquidityPoolDetailsRouterInput,
        localizationManager: LocalizationManagerProtocol,
        assetIdPair: AssetIdPair,
        logger: LoggerProtocol,
        viewModelFactory: LiquidityPoolDetailsViewModelFactory,
        chain: ChainModel,
        wallet: MetaAccountModel,
        input: LiquidityPoolDetailsInput
    ) {
        self.interactor = interactor
        self.router = router
        self.assetIdPair = assetIdPair
        self.logger = logger
        self.viewModelFactory = viewModelFactory
        self.chain = chain
        self.wallet = wallet
        self.input = input

        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        let liquidityPair = self.liquidityPair ?? input.liquidityPair
        guard let liquidityPair else {
            return
        }

        let reserves = reserves ?? CachedStorageResponse(value: input.reserves, type: .remote)
        let apy = apyInfo ?? input.apyInfo
        let accountPoolInfo = accountPoolInfo ?? input.accountPool

        let viewModel = viewModelFactory.buildViewModel(
            liquidityPair: liquidityPair,
            reserves: reserves,
            apyInfo: apy,
            chain: chain,
            prices: priceData,
            locale: selectedLocale,
            wallet: wallet,
            accountPoolInfo: accountPoolInfo,
            input: input
        )

        view?.bind(viewModel: viewModel)
    }
}

// MARK: - LiquidityPoolDetailsViewOutput

extension LiquidityPoolDetailsPresenter: LiquidityPoolDetailsViewOutput {
    func didLoad(view: LiquidityPoolDetailsViewInput) {
        self.view = view
        interactor.setup(with: self)
    }

    func backButtonClicked() {
        router.dismiss(view: view)
    }

    func supplyButtonClicked() {
        guard let liquidityPair else {
            return
        }

        router.showSupplyFlow(liquidityPair: liquidityPair, chain: chain, wallet: wallet, from: view)
    }

    func removeButtonClicked() {}
}

// MARK: - LiquidityPoolDetailsInteractorOutput

extension LiquidityPoolDetailsPresenter: LiquidityPoolDetailsInteractorOutput {
    func didReceiveLiquidityPair(liquidityPair: SSFPools.LiquidityPair?) {
        self.liquidityPair = liquidityPair
        provideViewModel()
    }

    func didReceiveUserPool(pool: AccountPool?) {
        accountPoolInfo = pool
        provideViewModel()
    }

    func didReceivePoolReserves(reserves: CachedStorageResponse<PolkaswapPoolReservesInfo>?) {
        self.reserves = reserves
        provideViewModel()
    }

    func didReceivePoolAPY(apy: PoolApyInfo?) {
        apyInfo = apy
        provideViewModel()
    }

    func didReceivePrices(result: Result<[PriceData], Error>) {
        switch result {
        case let .success(prices):
            priceData = prices
            provideViewModel()
        case let .failure(error):
            logger.customError(error)
        }
    }

    func didReceiveLiquidityPairError(error: Error) {
        logger.customError(error)
    }

    func didReceiveUserPoolError(error: Error) {
        logger.customError(error)
    }

    func didReceivePoolReservesError(error: Error) {
        logger.customError(error)
    }

    func didReceivePoolApyError(error: Error) {
        logger.customError(error)
    }
}

// MARK: - Localizable

extension LiquidityPoolDetailsPresenter: Localizable {
    func applyLocalization() {}
}

extension LiquidityPoolDetailsPresenter: LiquidityPoolDetailsModuleInput {}
