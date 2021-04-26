import SoraFoundation

final class StakingBalancePresenter {
    let interactor: StakingBalanceInteractorInputProtocol
    let wireframe: StakingBalanceWireframeProtocol
    let viewModelFactory: StakingBalanceViewModelFactoryProtocol
    weak var view: StakingBalanceViewProtocol?

    private var activeEra: EraIndex?
    private var stakingLedger: DyStakingLedger?
    private var priceData: PriceData?
    private var electionStatus: ElectionStatus?

    init(
        interactor: StakingBalanceInteractorInputProtocol,
        wireframe: StakingBalanceWireframeProtocol,
        viewModelFactory: StakingBalanceViewModelFactoryProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
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
}

extension StakingBalancePresenter: StakingBalancePresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func handleAction(_ action: StakingBalanceAction) {
        guard electionPeriodIsClosed else {
            wireframe.presentElectionPeriodIsNotClosed(from: view, locale: view?.localizationManager?.selectedLocale)
            return
        }

        switch action {
        case .bondMore:
            wireframe.showBondMore(from: view)
        case .unbond:
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
}
