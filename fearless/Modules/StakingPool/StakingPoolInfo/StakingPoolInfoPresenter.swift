import Foundation
import SoraFoundation

final class StakingPoolInfoPresenter {
    // MARK: Private properties

    private weak var view: StakingPoolInfoViewInput?
    private let router: StakingPoolInfoRouterInput
    private let interactor: StakingPoolInfoInteractorInput
    private let viewModelFactory: StakingPoolInfoViewModelFactoryProtocol
    private let stakingPool: StakingPool
    private let chainAsset: ChainAsset
    private let logger: LoggerProtocol?

    private var priceData: PriceData?

    // MARK: - Constructors

    init(
        interactor: StakingPoolInfoInteractorInput,
        router: StakingPoolInfoRouterInput,
        viewModelFactory: StakingPoolInfoViewModelFactoryProtocol,
        stakingPool: StakingPool,
        chainAsset: ChainAsset,
        logger: LoggerProtocol?,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.viewModelFactory = viewModelFactory
        self.chainAsset = chainAsset
        self.logger = logger
        self.stakingPool = stakingPool
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        let viewModel = viewModelFactory.buildViewModel(
            stakingPool: stakingPool,
            priceData: priceData,
            locale: selectedLocale
        )
        view?.didReceive(viewModel: viewModel)
    }
}

// MARK: - StakingPoolInfoViewOutput

extension StakingPoolInfoPresenter: StakingPoolInfoViewOutput {
    func didLoad(view: StakingPoolInfoViewInput) {
        self.view = view
        interactor.setup(with: self)

        provideViewModel()
    }

    func didTapCloseButton() {
        router.dismiss(view: view)
    }
}

// MARK: - StakingPoolInfoInteractorOutput

extension StakingPoolInfoPresenter: StakingPoolInfoInteractorOutput {
    func didReceivePriceData(result: Result<PriceData?, Error>) {
        switch result {
        case let .success(priceData):
            self.priceData = priceData

            provideViewModel()
        case let .failure(error):
            logger?.error("StakingPoolJoinConfigPresenter.didReceivePriceData.error: \(error)")
        }
    }
}

// MARK: - Localizable

extension StakingPoolInfoPresenter: Localizable {
    func applyLocalization() {
        provideViewModel()
    }
}

extension StakingPoolInfoPresenter: StakingPoolInfoModuleInput {}
