import Foundation

final class StakingMainPresenter {
    weak var view: StakingMainViewProtocol?
    var wireframe: StakingMainWireframeProtocol!
    var interactor: StakingMainInteractorInputProtocol!

    let logger: LoggerProtocol

    init(logger: LoggerProtocol) {
        self.logger = logger
    }
}

extension StakingMainPresenter: StakingMainPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func performMainAction() {
        wireframe.showStartStaking()
    }

    func performAccountAction() {
        logger.debug("Did select account")
    }
}

extension StakingMainPresenter: StakingMainInteractorOutputProtocol {
    func didReceive(selectedAddress: String) {
        let viewModel = StakingMainViewModel(address: selectedAddress)
        view?.didReceive(viewModel: viewModel)
    }
}
