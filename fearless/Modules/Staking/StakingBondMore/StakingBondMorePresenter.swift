import SoraFoundation

final class StakingBondMorePresenter {
    let interactor: StakingBondMoreInteractorInputProtocol
    let wireframe: StakingBondMoreWireframeProtocol
    let viewModelFactory: StakingBondMoreViewModelFactoryProtocol
    weak var view: StakingBondMoreViewProtocol?

    init(
        interactor: StakingBondMoreInteractorInputProtocol,
        wireframe: StakingBondMoreWireframeProtocol,
        viewModelFactory: StakingBondMoreViewModelFactoryProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
    }
}

extension StakingBondMorePresenter: StakingBondMorePresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func handleContinueAction() {
        wireframe.showConfirmation(from: view)
    }
}

extension StakingBondMorePresenter: StakingBondMoreInteractorOutputProtocol {
    // TODO:
}
