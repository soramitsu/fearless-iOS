import Foundation
import SSFModels
import SoraFoundation

final class BalanceLocksDetailPresenter {
    // MARK: Private properties

    private weak var view: BalanceLocksDetailViewInput?
    private let router: BalanceLocksDetailRouterInput
    private let interactor: BalanceLocksDetailInteractorInput
    private let logger: LoggerProtocol?
    private let viewModelFactory: BalanceLockDetailViewModelFactory
    private let chainAsset: ChainAsset

    private var stakingLedger: StakingLedger?
    private var stakingPoolMember: StakingPoolMember?
    private var balanceLocks: BalanceLocks?
    private var contributions: CrowdloanContributionDict?
    private var vestingSchedule: VestingSchedule?
    private var vesting: VestingVesting?
    private var priceData: PriceData?
    private var currentEra: EraIndex?

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
        guard let stakingLedger, let currentEra else {
            return
        }

        let viewModel = viewModelFactory.buildStakingLocksViewModel(
            stakingLedger: stakingLedger,
            priceData: priceData,
            activeEra: currentEra
        )

        Task {
            await view?.didReceiveStakingLocksViewModel(viewModel)
        }
    }

    private func providePoolsViewModel() {
        guard let stakingPoolMember, let currentEra else {
            return
        }

        let viewModel = viewModelFactory.buildPoolLocksViewModel(
            stakingPoolMember: stakingPoolMember,
            priceData: priceData,
            activeEra: currentEra
        )

        Task {
            await view?.didReceivePoolLocksViewModel(viewModel)
        }
    }

    private func provideLiquidityPoolsViewModel() {}

    private func provideCrowdloanViewModel() {
        guard chainAsset.chain.isRelaychain, let contributions else {
            return
        }

        let viewModel = viewModelFactory.buildCrowdloanLocksViewModel(
            crowdloanConbibutions: contributions,
            priceData: priceData
        )

        Task {
            await view?.didReceiveCrowdloanLocksViewModel(viewModel)
        }
    }

    private func provideVestingViewModel() {
        guard !chainAsset.chain.isRelaychain else {
            return
        }

        let viewModel = viewModelFactory.buildVestingLocksViewModel(
            vesting: vesting,
            vestingSchedule: vestingSchedule,
            priceData: priceData
        )

        Task {
            await view?.didReceiveCrowdloanLocksViewModel(viewModel)
        }
    }

    private func provideGovernanceViewModel() {
        guard let balanceLocks else {
            return
        }
        let viewModel = viewModelFactory.buildGovernanceLocksViewModel(
            balanceLocks: balanceLocks,
            priceData: priceData
        )

        Task {
            await view?.didReceiveGovernanceLocksViewModel(viewModel)
        }
    }
}

// MARK: - BalanceLocksDetailViewOutput

extension BalanceLocksDetailPresenter: BalanceLocksDetailViewOutput {
    func didLoad(view: BalanceLocksDetailViewInput) {
        self.view = view
        interactor.setup(with: self)
    }
}

// MARK: - BalanceLocksDetailInteractorOutput

extension BalanceLocksDetailPresenter: BalanceLocksDetailInteractorOutput {
    func didReceiveCurrentEra(_ era: EraIndex?) {
        currentEra = era
        provideStakingViewModel()
        providePoolsViewModel()
    }

    func didReceiveCurrentEraError(_ error: Error) {
        logger?.error(error.localizedDescription)
    }

    func didReceivePrice(_ price: PriceData?) {
        priceData = price

        provideStakingViewModel()
        providePoolsViewModel()
        provideGovernanceViewModel()
        provideCrowdloanViewModel()
        provideVestingViewModel()
    }

    func didReceivePriceError(_ error: Error) {
        logger?.error(error.localizedDescription)
    }

    func didReceiveStakingLedger(_ stakingLedger: StakingLedger?) {
        self.stakingLedger = stakingLedger
        provideStakingViewModel()
    }

    func didReceiveStakingPoolMember(_ stakingPoolMember: StakingPoolMember?) {
        self.stakingPoolMember = stakingPoolMember
        providePoolsViewModel()
    }

    func didReceiveBalanceLocks(_ balanceLocks: BalanceLocks?) {
        self.balanceLocks = balanceLocks
        provideGovernanceViewModel()
    }

    func didReceiveCrowdloanContributions(_ contributions: CrowdloanContributionDict?) {
        self.contributions = contributions
        provideCrowdloanViewModel()
    }

    func didReceiveVestingVesting(_ vesting: VestingVesting?) {
        self.vesting = vesting
        provideVestingViewModel()
    }

    func didReceiveVestingSchedule(_ vestingSchedule: VestingSchedule?) {
        self.vestingSchedule = vestingSchedule
        provideVestingViewModel()
    }

    func didReceiveStakingLedgerError(_ error: Error) {
        logger?.error(error.localizedDescription)
    }

    func didReceiveStakingPoolError(_ error: Error) {
        logger?.error(error.localizedDescription)
    }

    func didReceiveBalanceLocksError(_ error: Error) {
        logger?.error(error.localizedDescription)
    }

    func didReceiveCrowdloanContributionsError(_ error: Error) {
        logger?.error(error.localizedDescription)
    }

    func didReceiveVestingScheduleError(_ error: Error) {
        logger?.error(error.localizedDescription)
    }

    func didReceiveVestingVestingError(_ error: Error) {
        logger?.error(error.localizedDescription)
    }
}

// MARK: - Localizable

extension BalanceLocksDetailPresenter: Localizable {
    func applyLocalization() {}
}

extension BalanceLocksDetailPresenter: BalanceLocksDetailModuleInput {}
