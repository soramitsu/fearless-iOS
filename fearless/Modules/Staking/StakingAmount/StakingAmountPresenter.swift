import Foundation

final class StakingAmountPresenter {
    weak var view: StakingAmountViewProtocol?
    var wireframe: StakingAmountWireframeProtocol!
    var interactor: StakingAmountInteractorInputProtocol!
}

extension StakingAmountPresenter: StakingAmountPresenterProtocol {
    func setup() {}

    func close() {
        wireframe.close(view: view)
    }
}

extension StakingAmountPresenter: StakingAmountInteractorOutputProtocol {}
