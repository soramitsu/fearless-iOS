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

    private var stakingLedger: NoneStateOptional<StakingLedger?> = .none
    private var stakingPoolMember: NoneStateOptional<StakingPoolMember?> = .none
    private var balanceLocks: NoneStateOptional<BalanceLocks?> = .none
    private var contributions: NoneStateOptional<CrowdloanContributionDict?> = .none
    private var vestingSchedule: NoneStateOptional<VestingSchedule?> = .none
    private var vesting: NoneStateOptional<VestingVesting?> = .none
    private var priceData: PriceData?
    private var currentEra: NoneStateOptional<EraIndex?> = .none

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
            let stakingLedger = stakingLedger.value,
            let currentEra = currentEra.value
        else {
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
        guard
            let stakingPoolMember = stakingPoolMember.value,
            let currentEra = currentEra.value
        else {
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
        guard
            chainAsset.chain.isRelaychain,
            let contributions = contributions.value
        else {
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
        guard
            !chainAsset.chain.isRelaychain,
            let vesting = vesting.value,
            let vestingSchedule = vestingSchedule.value
        else {
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
        guard let balanceLocks = balanceLocks.value else {
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

    private func provideTotalViewModel() {
        guard
            let stakingLedger = stakingLedger.value,
            let stakingPoolMember = stakingPoolMember.value,
            let balanceLocks = balanceLocks.value,
            let vesting = vesting.value,
            let vestingSchedule = vestingSchedule.value,
            let activeEra = currentEra.value,
            let contributions = contributions.value
        else {
            return
        }

        let viewModel = viewModelFactory.buildTotalLocksViewModel(
            stakingLedger: stakingLedger,
            stakingPoolMember: stakingPoolMember,
            balanceLocks: balanceLocks,
            crowdloanConbibutions: contributions,
            vesting: vesting,
            vestingSchedule: vestingSchedule,
            activeEra: activeEra,
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
    func didReceiveCurrentEra(_ era: EraIndex?) {
        currentEra = .value(era)

        provideStakingViewModel()
        providePoolsViewModel()
        provideTotalViewModel()
    }

    func didReceiveCurrentEraError(_ error: Error) {
        currentEra = .value(nil)

        logger?.error(error.localizedDescription)
    }

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

    func didReceiveStakingLedger(_ stakingLedger: StakingLedger?) {
        self.stakingLedger = .value(stakingLedger)
        provideStakingViewModel()
        provideTotalViewModel()
    }

    func didReceiveStakingPoolMember(_ stakingPoolMember: StakingPoolMember?) {
        self.stakingPoolMember = .value(stakingPoolMember)
        providePoolsViewModel()
        provideTotalViewModel()
    }

    func didReceiveBalanceLocks(_ balanceLocks: BalanceLocks?) {
        self.balanceLocks = .value(balanceLocks)
        provideGovernanceViewModel()
        provideTotalViewModel()
    }

    func didReceiveCrowdloanContributions(_ contributions: CrowdloanContributionDict?) {
        self.contributions = .value(contributions)
        provideCrowdloanViewModel()
        provideTotalViewModel()
    }

    func didReceiveVestingVesting(_ vesting: VestingVesting?) {
        self.vesting = .value(vesting)
        provideVestingViewModel()
        provideTotalViewModel()
    }

    func didReceiveVestingSchedule(_ vestingSchedule: VestingSchedule?) {
        self.vestingSchedule = .value(vestingSchedule)
        provideVestingViewModel()
        provideTotalViewModel()
    }

    func didReceiveStakingLedgerError(_ error: Error) {
        stakingLedger = .value(nil)
        provideStakingViewModel()
        provideTotalViewModel()

        logger?.error(error.localizedDescription)
    }

    func didReceiveStakingPoolError(_ error: Error) {
        stakingPoolMember = .value(nil)
        providePoolsViewModel()
        provideTotalViewModel()

        logger?.error(error.localizedDescription)
    }

    func didReceiveBalanceLocksError(_ error: Error) {
        balanceLocks = .value(nil)
        provideGovernanceViewModel()
        provideTotalViewModel()

        logger?.error(error.localizedDescription)
    }

    func didReceiveCrowdloanContributionsError(_ error: Error) {
        contributions = .value(nil)
        provideCrowdloanViewModel()
        provideTotalViewModel()

        logger?.error(error.localizedDescription)
    }

    func didReceiveVestingScheduleError(_ error: Error) {
        vestingSchedule = .value(nil)
        provideVestingViewModel()
        provideTotalViewModel()

        logger?.error(error.localizedDescription)
    }

    func didReceiveVestingVestingError(_ error: Error) {
        vesting = .value(nil)
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
