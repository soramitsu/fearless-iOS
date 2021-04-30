import SoraFoundation
import CommonWallet
import BigInt

final class StakingBondMoreConfirmationPresenter {
    weak var view: StakingBondMoreConfirmationViewProtocol?
    let interactor: StakingBondMoreConfirmationInteractorInputProtocol
    let wireframe: StakingBondMoreConfirmationWireframeProtocol

    init(
        interactor: StakingBondMoreConfirmationInteractorInputProtocol,
        wireframe: StakingBondMoreConfirmationWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension StakingBondMoreConfirmationPresenter: StakingBondMoreConfirmationPresenterProtocol {
    func setup() {}
}

extension StakingBondMoreConfirmationPresenter: StakingBondMoreConfirmationOutputProtocol {}
