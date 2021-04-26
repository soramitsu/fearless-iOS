import SoraFoundation

final class StakingBalancePresenter {
    let interactor: StakingBalanceInteractorInputProtocol
    let wireframe: StakingBalanceWireframeProtocol
    weak var view: StakingBalanceViewProtocol?

    private var activeEra: EraIndex?
    private var stakingLedger: DyStakingLedger?
    private var priceData: PriceData?
    private var electionStatus: ElectionStatus?

    init(
        interactor: StakingBalanceInteractorInputProtocol,
        wireframe: StakingBalanceWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }

    private func updateView() {}
}

extension StakingBalancePresenter: StakingBalancePresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func handleBondMoreAction() {
        wireframe.showBondMore(from: view)
    }

    func handleUnbondAction() {
        wireframe.showUnbond(from: view)
    }

    func handleRedeemAction() {
        wireframe.showRedeem(from: view)
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

    func didReceive(balanceResult: Result<StakingBalanceData, Error>) {
        switch balanceResult {
        case let .success(balance):
            print(balance)
        case let .failure(error):
            print(error)
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
            updateView()
        case .failure:
            electionStatus = nil
            updateView()
        }
    }
}
