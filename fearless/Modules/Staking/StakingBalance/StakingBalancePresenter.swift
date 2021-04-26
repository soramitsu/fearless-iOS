import SoraFoundation

final class StakingBalancePresenter {
    let interactor: StakingBalanceInteractorInputProtocol
    let wireframe: StakingBalanceWireframeProtocol
    let viewModelFactory: StakingBalanceViewModelFactoryProtocol
    weak var view: StakingBalanceViewProtocol?
    private let accountAddress: AccountAddress

    private var stashItem: StashItem?
    private var activeEra: EraIndex?
    private var stakingLedger: DyStakingLedger?
    private var priceData: PriceData?
    private var electionStatus: ElectionStatus?

    init(
        interactor: StakingBalanceInteractorInputProtocol,
        wireframe: StakingBalanceWireframeProtocol,
        viewModelFactory: StakingBalanceViewModelFactoryProtocol,
        accountAddress: AccountAddress
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.accountAddress = accountAddress
    }

    private func updateView() {
        guard
            let stakingLedger = stakingLedger,
            let activeEra = activeEra
        else { return }
        let balanceData = StakingBalanceData(stakingLedger: stakingLedger, activeEra: activeEra, priceData: priceData)
        let viewModel = viewModelFactory.createViewModel(from: balanceData)
        view?.reload(with: viewModel)
    }

    var electionPeriodIsClosed: Bool {
        switch electionStatus {
        case .close:
            return true
        case .open:
            return false
        case .none:
            return false
        }
    }

    var controllerAccountIsAvailable: Bool {
        stashItem != nil
    }

    var unbondingRequestsLimitExceeded: Bool {
        guard let stakingLedger = stakingLedger else { return false }
        return stakingLedger.unlocking.count >= SubstrateConstants.maxUnbondingRequests
    }
}

extension StakingBalancePresenter: StakingBalancePresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func handleAction(_ action: StakingBalanceAction) {
        guard let view = view else { return }
        let selectedLocale = view.localizationManager?.selectedLocale

        guard electionPeriodIsClosed else {
            wireframe.presentElectionPeriodIsNotClosed(from: view, locale: selectedLocale)
            return
        }

        guard controllerAccountIsAvailable else {
            wireframe.presentMissingController(
                from: view,
                address: accountAddress,
                locale: selectedLocale
            )
            return
        }

        switch action {
        case .bondMore:
            wireframe.showBondMore(from: view)
        case .unbond:
            guard !unbondingRequestsLimitExceeded else {
                wireframe.presentUnbondingLimitReached(from: view, locale: selectedLocale)
                return
            }
            wireframe.showUnbond(from: view)
        case .redeem:
            wireframe.showRedeem(from: view)
        }
    }
}

extension StakingBalancePresenter: StakingBalanceInteractorOutputProtocol {
    func didReceive(ledgerResult: Result<DyStakingLedger?, Error>) {
        switch ledgerResult {
        case let .success(ledger):
            stakingLedger = ledger
            updateView()
        case let .failure(error):
            stakingLedger = nil
            updateView()
        }
    }

    func didReceive(activeEraResult: Result<EraIndex?, Error>) {
        switch activeEraResult {
        case let .success(activeEra):
            self.activeEra = activeEra
            updateView()
        case let .failure(error):
            activeEra = nil
            updateView()
        }
    }

    func didReceive(priceResult: Result<PriceData?, Error>) {
        switch priceResult {
        case let .success(priceData):
            self.priceData = priceData
            updateView()
        case .failure:
            priceData = nil
            updateView()
        }
    }

    func didReceive(electionStatusResult: Result<ElectionStatus?, Error>) {
        switch electionStatusResult {
        case let .success(electionStatus):
            self.electionStatus = electionStatus
        case .failure:
            electionStatus = nil
        }
    }

    func didReceive(stashItemResult: Result<StashItem?, Error>) {
        switch stashItemResult {
        case let .success(stashItem):
            self.stashItem = stashItem
        case let .failure(error):
            stashItem = nil
        }
    }
}
