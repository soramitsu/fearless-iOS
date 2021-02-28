import Foundation

final class StakingConfirmPresenter {
    weak var view: StakingConfirmViewProtocol?
    var wireframe: StakingConfirmWireframeProtocol!
    var interactor: StakingConfirmInteractorInputProtocol!
}

extension StakingConfirmPresenter: StakingConfirmPresenterProtocol {
    func setup() {}
}

extension StakingConfirmPresenter: StakingConfirmInteractorOutputProtocol {}