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
    private let selectedCurrency: Currency

    private var nominationPoolLocks: NoneStateOptional<StakingLocks?> = .none
    private var stakingLocks: NoneStateOptional<StakingLocks?> = .none
    private var governanceLocks: NoneStateOptional<Decimal?> = .none
    private var crowdloanLocks: NoneStateOptional<Decimal?> = .none
    private var vestingLocks: NoneStateOptional<Decimal?> = .none
    private var totalLocks: NoneStateOptional<Decimal?> = .none
    private var assetFrozen: NoneStateOptional<Decimal?> = .none
    private var assetBlocked: NoneStateOptional<Decimal?> = .none

    // MARK: - Constructors

    init(
        interactor: BalanceLocksDetailInteractorInput,
        router: BalanceLocksDetailRouterInput,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol?,
        viewModelFactory: BalanceLockDetailViewModelFactory,
        chainAsset: ChainAsset,
        selectedCurrency: Currency
    ) {
        self.interactor = interactor
        self.router = router
        self.logger = logger
        self.viewModelFactory = viewModelFactory
        self.chainAsset = chainAsset
        self.selectedCurrency = selectedCurrency
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
            priceData: chainAsset.asset.getPrice(for: selectedCurrency)
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
            priceData: chainAsset.asset.getPrice(for: selectedCurrency)
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
            priceData: chainAsset.asset.getPrice(for: selectedCurrency)
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
            priceData: chainAsset.asset.getPrice(for: selectedCurrency)
        )

        await view?.didReceiveCrowdloanLocksViewModel(viewModel)
    }

    private func provideGovernanceViewModel() async {
        guard let governanceLocks = governanceLocks.value else {
            return
        }
        let viewModel = viewModelFactory.buildGovernanceLocksViewModel(
            governanceLocks: governanceLocks,
            priceData: chainAsset.asset.getPrice(for: selectedCurrency)
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
            priceData: chainAsset.asset.getPrice(for: selectedCurrency)
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
            await view?.didReceiveAssetFrozenViewModel(nil)
            await view?.didReceiveAssetBlockedViewModel(nil)
        }
    }

    private func provideAssetFrozenViewModel() async {
        guard
            let assetFrozen = assetFrozen.value
        else {
            return
        }

        let viewModel = viewModelFactory.buildAssetFrozenViewModel(
            assetFrozen: assetFrozen,
            priceData: chainAsset.asset.getPrice(for: selectedCurrency)
        )

        await view?.didReceiveAssetFrozenViewModel(viewModel)
    }

    private func provideAssetBlockedViewModel() async {
        guard
            let assetBlocked = assetBlocked.value
        else {
            return
        }

        let viewModel = viewModelFactory.buildAssetBlockedViewModel(
            assetBlocked: assetBlocked,
            priceData: chainAsset.asset.getPrice(for: selectedCurrency)
        )

        await view?.didReceiveAssetBlockedViewModel(viewModel)
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

    func didReceiveAssetFrozen(_ frozen: Decimal?) async {
        assetFrozen = .value(frozen)
        await provideAssetFrozenViewModel()
    }

    func didReceiveAssetBlocked(_ blocked: Decimal?) async {
        assetBlocked = .value(blocked)
        await provideAssetBlockedViewModel()
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

    func didReceiveAssetFrozenError(_ error: Error) async {
        assetFrozen = .value(nil)
        await provideAssetFrozenViewModel()

        logger?.customError(error)
    }

    func didReceiveAssetBlockedError(_ error: Error) async {
        assetBlocked = .value(nil)
        await provideAssetBlockedViewModel()

        logger?.customError(error)
    }
}

// MARK: - Localizable

extension BalanceLocksDetailPresenter: Localizable {
    func applyLocalization() {}
}

extension BalanceLocksDetailPresenter: BalanceLocksDetailModuleInput {}
