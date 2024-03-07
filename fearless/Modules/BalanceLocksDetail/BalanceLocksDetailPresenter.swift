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

    private var nominationPoolLocks: NoneStateOptional<StakingLocks?> = .none
    private var stakingLocks: NoneStateOptional<StakingLocks?> = .none
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

    private func provideStakingViewModel() async {
        guard
            let stakingLocks = stakingLocks.value
        else {
            return
        }

        let viewModel = viewModelFactory.buildStakingLocksViewModel(
            stakingLocks: stakingLocks,
            priceData: priceData
        )

        await view?.didReceiveStakingLocksViewModel(viewModel)
    }

    private func providePoolsViewModel() async {
        guard
            let nominationPoolLocks = nominationPoolLocks.value
        else {
            return
        }

        let viewModel = viewModelFactory.buildNominationPoolLocksViewModel(
            nominationPoolLocks: nominationPoolLocks,
            priceData: priceData
        )

        await view?.didReceivePoolLocksViewModel(viewModel)
    }

    private func provideLiquidityPoolsViewModel() {}

    private func provideCrowdloanViewModel() async {
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

        await view?.didReceiveCrowdloanLocksViewModel(viewModel)
    }

    private func provideVestingViewModel() async {
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

        await view?.didReceiveCrowdloanLocksViewModel(viewModel)
    }

    private func provideGovernanceViewModel() async {
        guard let governanceLocks = governanceLocks.value else {
            return
        }
        let viewModel = viewModelFactory.buildGovernanceLocksViewModel(
            governanceLocks: governanceLocks,
            priceData: priceData
        )

        await view?.didReceiveGovernanceLocksViewModel(viewModel)
    }

    private func provideTotalViewModel() async {
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

        await view?.didReceiveTotalLocksViewModel(viewModel)
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

        Task {
            await provideStakingViewModel()
            await providePoolsViewModel()
            await provideGovernanceViewModel()
            await provideCrowdloanViewModel()
            await provideVestingViewModel()
            await provideTotalViewModel()
        }
    }

    func didReceivePriceError(_ error: Error) {
        logger?.error(error.localizedDescription)
    }

    func didReceiveStakingLocks(_ stakingLocks: StakingLocks?) async {
        self.stakingLocks = .value(stakingLocks)
        await provideStakingViewModel()
        await provideTotalViewModel()
    }

    func didReceiveNominationPoolLocks(_ nominationPoolLocks: StakingLocks?) async {
        self.nominationPoolLocks = .value(nominationPoolLocks)
        await providePoolsViewModel()
        await provideTotalViewModel()
    }

    func didReceiveGovernanceLocks(_ governanceLocks: Decimal?) async {
        self.governanceLocks = .value(governanceLocks)
        await provideGovernanceViewModel()
        await provideTotalViewModel()
    }

    func didReceiveCrowdloanLocks(_ crowdloanLocks: Decimal?) async {
        self.crowdloanLocks = .value(crowdloanLocks)
        await provideCrowdloanViewModel()
        await provideTotalViewModel()
    }

    func didReceiveVestingLocks(_ vestingLocks: Decimal?) async {
        self.vestingLocks = .value(vestingLocks)
        await provideVestingViewModel()
        await provideTotalViewModel()
    }

    func didReceiveStakingLocksError(_ error: Error) async {
        stakingLocks = .value(nil)
        await provideStakingViewModel()
        await provideTotalViewModel()

        logger?.error(error.localizedDescription)
    }

    func didReceiveNominationPoolLocksError(_ error: Error) async {
        nominationPoolLocks = .value(nil)
        await providePoolsViewModel()
        await provideTotalViewModel()

        logger?.error(error.localizedDescription)
    }

    func didReceiveGovernanceLocksError(_ error: Error) async {
        governanceLocks = .value(nil)
        await provideGovernanceViewModel()
        await provideTotalViewModel()

        logger?.error(error.localizedDescription)
    }

    func didReceiveCrowdloanLocksError(_ error: Error) async {
        crowdloanLocks = .value(nil)
        await provideCrowdloanViewModel()
        await provideTotalViewModel()

        logger?.error(error.localizedDescription)
    }

    func didReceiveVestingLocksError(_ error: Error) async {
        vestingLocks = .value(nil)
        await provideVestingViewModel()
        await provideTotalViewModel()

        logger?.error(error.localizedDescription)
    }
}

// MARK: - Localizable

extension BalanceLocksDetailPresenter: Localizable {
    func applyLocalization() {}
}

extension BalanceLocksDetailPresenter: BalanceLocksDetailModuleInput {}
