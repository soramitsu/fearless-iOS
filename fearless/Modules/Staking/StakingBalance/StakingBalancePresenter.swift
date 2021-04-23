import SoraFoundation

final class StakingBalancePresenter {
    let interactor: StakingBalanceInteractorInputProtocol
    let wireframe: StakingBalanceWireframeProtocol
    weak var view: StakingBalanceViewProtocol?

    private var priceData: PriceData?

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
}
