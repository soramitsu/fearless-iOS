import Foundation

final class StakingRewardPayoutsPresenter {
    weak var view: StakingRewardPayoutsViewProtocol?
    var wireframe: StakingRewardPayoutsWireframeProtocol!
    var interactor: StakingRewardPayoutsInteractorInputProtocol!
}

extension StakingRewardPayoutsPresenter: StakingRewardPayoutsPresenterProtocol {

    func setup() {}

    func handleSelectedHistory(at indexPath: IndexPath) {
        // TODO get model by indexPath -> pass to wireframe
        wireframe.showRewardDetails(from: view)
    }

    func handlePayoutAction() {
        wireframe.showRewardDetails(from: view)
    }
}

extension StakingRewardPayoutsPresenter: StakingRewardPayoutsInteractorOutputProtocol {

}
