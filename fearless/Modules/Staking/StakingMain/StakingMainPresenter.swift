import Foundation

final class StakingMainPresenter {
    weak var view: StakingMainViewProtocol?
    var wireframe: StakingMainWireframeProtocol!
    var interactor: StakingMainInteractorInputProtocol!
}

extension StakingMainPresenter: StakingMainPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func performMainAction() {
        wireframe.showStartStaking()
    }
}

extension StakingMainPresenter: StakingMainInteractorOutputProtocol {
    func didReceive(selectedAddress: String) {
        let viewModel = StakingMainViewModel(address: selectedAddress)
        view?.didReceive(viewModel: viewModel)
    }
}
