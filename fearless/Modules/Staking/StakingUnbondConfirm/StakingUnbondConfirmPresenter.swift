import Foundation

final class StakingUnbondConfirmPresenter {
    weak var view: StakingUnbondConfirmViewProtocol?
    let wireframe: StakingUnbondConfirmWireframeProtocol
    let interactor: StakingUnbondConfirmInteractorInputProtocol

    init(
        interactor: StakingUnbondConfirmInteractorInputProtocol,
        wireframe: StakingUnbondConfirmWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension StakingUnbondConfirmPresenter: StakingUnbondConfirmPresenterProtocol {
    func setup() {}
}

extension StakingUnbondConfirmPresenter: StakingUnbondConfirmInteractorOutputProtocol {}
