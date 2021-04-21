import SoraFoundation

final class StakingBalancePresenter {
    let interactor: StakingBalanceInteractorInputProtocol
    let wireframe: StakingBalanceWireframeProtocol
    weak var view: StakingBalanceViewProtocol?

    init(
        interactor: StakingBalanceInteractorInputProtocol,
        wireframe: StakingBalanceWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
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
