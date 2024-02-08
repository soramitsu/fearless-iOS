import Foundation
import SSFModels
import SoraFoundation

final class BalanceLocksDetailPresenter {
    // MARK: Private properties

    private weak var view: BalanceLocksDetailViewInput?
    private let router: BalanceLocksDetailRouterInput
    private let interactor: BalanceLocksDetailInteractorInput
    private let logger: LoggerProtocol?

    private var stakingLedger: StakingLedger?
    private var stakingPoolMember: StakingPoolMember?
    private var balanceLocks: BalanceLocks?
    private var contributions: CrowdloanContributionDict?
    private var vestingSchedule: VestingSchedule?
    private var vesting: VestingVesting?
    private var priceData: PriceData?

    // MARK: - Constructors

    init(
        interactor: BalanceLocksDetailInteractorInput,
        router: BalanceLocksDetailRouterInput,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol?
    ) {
        self.interactor = interactor
        self.router = router
        self.logger = logger
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideStakingViewModel() {}

    private func providePoolsViewModel() {}

    private func provideLiquidityPoolsViewModel() {}

    private func provideCrowdloanViewModel() {}

    private func provideGovernanceViewModel() {}
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
    func didReceivePrice(_ price: SSFModels.PriceData?) {
        priceData = price
    }

    func didReceivePriceError(_ error: Error) {
        logger?.error(error.localizedDescription)
    }

    func didReceiveStakingLedger(_ stakingLedger: StakingLedger?) {
        self.stakingLedger = stakingLedger
    }

    func didReceiveStakingPoolMember(_ stakingPoolMember: StakingPoolMember?) {
        self.stakingPoolMember = stakingPoolMember
    }

    func didReceiveBalanceLocks(_ balanceLocks: BalanceLocks?) {
        self.balanceLocks = balanceLocks
    }

    func didReceiveCrowdloanContributions(_ contributions: CrowdloanContributionDict?) {
        self.contributions = contributions
    }

    func didReceiveVestingVesting(_ vesting: VestingVesting?) {
        self.vesting = vesting
    }

    func didReceiveVestingSchedule(_ vestingSchedule: VestingSchedule?) {
        self.vestingSchedule = vestingSchedule
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
