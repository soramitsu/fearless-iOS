import Foundation

final class StakingUnbondSetupPresenter {
    weak var view: StakingUnbondSetupViewProtocol?
    let wireframe: StakingUnbondSetupWireframeProtocol
    let interactor: StakingUnbondSetupInteractorInputProtocol

    init(
        interactor: StakingUnbondSetupInteractorInputProtocol,
        wireframe: StakingUnbondSetupWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension StakingUnbondSetupPresenter: StakingUnbondSetupPresenterProtocol {
    func setup() {}
}

extension StakingUnbondSetupPresenter: StakingUnbondSetupInteractorOutputProtocol {}
