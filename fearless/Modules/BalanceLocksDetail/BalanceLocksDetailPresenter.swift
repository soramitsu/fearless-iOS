import Foundation
import SSFModels
import SoraFoundation

enum NoneStateOptional<T> {
    case none
    case value(T)

    var value: T? {
        switch self {
        case .none:
            return nil
        case let .value(t):
            return t
        }
    }
}

final class BalanceLocksDetailPresenter {
    // MARK: Private properties

    private weak var view: BalanceLocksDetailViewInput?
    private let router: BalanceLocksDetailRouterInput
    private let interactor: BalanceLocksDetailInteractorInput
    private let logger: LoggerProtocol?
    private let viewModelFactory: BalanceLockDetailViewModelFactory
    private let chainAsset: ChainAsset

    private var stakingLocks: NoneStateOptional<StakingLocks?> = .none
    private var nominationPoolLocks: NoneStateOptional<StakingLocks?> = .none
    private var governanceLocks: NoneStateOptional<Decimal?> = .none
    private var crowdloanLocks: NoneStateOptional<Decimal?> = .none
    private var vestingLocks: NoneStateOptional<Decimal?> = .none
    private var totalLocks: NoneStateOptional<Decimal?> = .none
    private var priceData: PriceData?

    // MARK: - Constructors

    init(
        interactor: BalanceLocksDetailInteractorInput,
        router: BalanceLocksDetailRouterInput,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol?,
        viewModelFactory: BalanceLockDetailViewModelFactory,
        chainAsset: ChainAsset
    ) {
        self.interactor = interactor
        self.router = router
        self.logger = logger
        self.viewModelFactory = viewModelFactory
        self.chainAsset = chainAsset
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideStakingViewModel() {
        guard
            let stakingLocks = stakingLocks.value
        else {
            return
        }

        let viewModel = viewModelFactory.buildStakingLocksViewModel(
            stakingLocks: stakingLocks,
            priceData: priceData
        )

        Task {
            await view?.didReceiveStakingLocksViewModel(viewModel)
        }
    }

    private func providePoolsViewModel() {
        guard
            let nominationPoolLocks = nominationPoolLocks.value
        else {
            return
        }

        let viewModel = viewModelFactory.buildNominationPoolLocksViewModel(
            nominationPoolLocks: nominationPoolLocks,
            priceData: priceData
        )

        Task {
            await view?.didReceivePoolLocksViewModel(viewModel)
        }
    }

    private func provideLiquidityPoolsViewModel() {}

    private func provideCrowdloanViewModel() {
        guard
            chainAsset.chain.isRelaychain,
            let crowdloanLocks = crowdloanLocks.value
        else {
            return
        }

        let viewModel = viewModelFactory.buildCrowdloanLocksViewModel(
            crowdloanLocks: crowdloanLocks,
            priceData: priceData
        )

        Task {
            await view?.didReceiveCrowdloanLocksViewModel(viewModel)
        }
    }

    private func provideVestingViewModel() {
        guard
            !chainAsset.chain.isRelaychain,
            let vestingLocks = vestingLocks.value
        else {
            return
        }

        let viewModel = viewModelFactory.buildVestingLocksViewModel(
            vestingLocks: vestingLocks,
            priceData: priceData
        )

        Task {
            await view?.didReceiveCrowdloanLocksViewModel(viewModel)
        }
    }

    private func provideGovernanceViewModel() {
        guard let governanceLocks = governanceLocks.value else {
            return
        }
        let viewModel = viewModelFactory.buildGovernanceLocksViewModel(
            governanceLocks: governanceLocks,
            priceData: priceData
        )

        Task {
            await view?.didReceiveGovernanceLocksViewModel(viewModel)
        }
    }

    private func provideTotalViewModel() {
        guard
            let stakingLocks = stakingLocks.value,
            let nominationPoolLocks = nominationPoolLocks.value,
            let governanceLocks = governanceLocks.value,
            let crowdloanLocks = crowdloanLocks.value,
            let vestingLocks = vestingLocks.value
        else {
            return
        }

        let viewModel = viewModelFactory.buildTotalLocksViewModel(
            stakingLocks: stakingLocks,
            nominationPoolLocks: nominationPoolLocks,
            governanceLocks: governanceLocks,
            crowdloanLocks: crowdloanLocks,
            vestingLocks: vestingLocks,
            priceData: priceData
        )

        Task {
            await view?.didReceiveTotalLocksViewModel(viewModel)
        }
    }

    private func provideLoadingViewState() {
        Task {
            await view?.didReceiveStakingLocksViewModel(nil)
            await view?.didReceivePoolLocksViewModel(nil)
            await view?.didReceiveLiquidityPoolLocksViewModel(nil)
            await view?.didReceiveCrowdloanLocksViewModel(nil)
            await view?.didReceiveGovernanceLocksViewModel(nil)
            await view?.didReceiveTotalLocksViewModel(nil)
        }
    }
}

// MARK: - BalanceLocksDetailViewOutput

extension BalanceLocksDetailPresenter: BalanceLocksDetailViewOutput {
    func didLoad(view: BalanceLocksDetailViewInput) {
        self.view = view
        provideLoadingViewState()
        interactor.setup(with: self)
    }

    func didTapCloseButton() {
        router.dismiss(view: view)
    }
}

// MARK: - BalanceLocksDetailInteractorOutput

extension BalanceLocksDetailPresenter: BalanceLocksDetailInteractorOutput {
    func didReceivePrice(_ price: PriceData?) {
        priceData = price

        provideStakingViewModel()
        providePoolsViewModel()
        provideGovernanceViewModel()
        provideCrowdloanViewModel()
        provideVestingViewModel()
        provideTotalViewModel()
    }

    func didReceivePriceError(_ error: Error) {
        logger?.error(error.localizedDescription)
    }

    func didReceiveStakingLocks(_ stakingLocks: StakingLocks?) {
        self.stakingLocks = .value(stakingLocks)
        provideStakingViewModel()
        provideTotalViewModel()
    }

    func didReceiveNominationPoolLocks(_ nominationPoolLocks: StakingLocks?) {
        self.nominationPoolLocks = .value(nominationPoolLocks)
        providePoolsViewModel()
        provideTotalViewModel()
    }

    func didReceiveGovernanceLocks(_ governanceLocks: Decimal?) {
        self.governanceLocks = .value(governanceLocks)
        provideGovernanceViewModel()
        provideTotalViewModel()
    }

    func didReceiveCrowdloanLocks(_ crowdloanLocks: Decimal?) {
        self.crowdloanLocks = .value(crowdloanLocks)
        provideCrowdloanViewModel()
        provideTotalViewModel()
    }

    func didReceiveVestingLocks(_ vestingLocks: Decimal?) {
        self.vestingLocks = .value(vestingLocks)
        provideVestingViewModel()
        provideTotalViewModel()
    }

    func didReceiveStakingLocksError(_ error: Error) {
        stakingLocks = .value(nil)
        provideStakingViewModel()
        provideTotalViewModel()

        logger?.error(error.localizedDescription)
    }

    func didReceiveNominationPoolLocksError(_ error: Error) {
        nominationPoolLocks = .value(nil)
        providePoolsViewModel()
        provideTotalViewModel()

        logger?.error(error.localizedDescription)
    }

    func didReceiveGovernanceLocksError(_ error: Error) {
        governanceLocks = .value(nil)
        provideGovernanceViewModel()
        provideTotalViewModel()

        logger?.error(error.localizedDescription)
    }

    func didReceiveCrowdloanLocksError(_ error: Error) {
        crowdloanLocks = .value(nil)
        provideCrowdloanViewModel()
        provideTotalViewModel()

        logger?.error(error.localizedDescription)
    }

    func didReceiveVestingLocksError(_ error: Error) {
        vestingLocks = .value(nil)
        provideVestingViewModel()
        provideTotalViewModel()

        logger?.error(error.localizedDescription)
    }
}

// MARK: - Localizable

extension BalanceLocksDetailPresenter: Localizable {
    func applyLocalization() {}
}

extension BalanceLocksDetailPresenter: BalanceLocksDetailModuleInput {}
