import Foundation

final class StakingRewardPayoutsPresenter {
    weak var view: StakingRewardPayoutsViewProtocol?
    var wireframe: StakingRewardPayoutsWireframeProtocol!
    var interactor: StakingRewardPayoutsInteractorInputProtocol!
}

extension StakingRewardPayoutsPresenter: StakingRewardPayoutsPresenterProtocol {
    func setup() {}

    func handleSelectedHistory() {
        wireframe.showRewardDetails(from: view)
    }

    func handlePayoutAction() {
        wireframe.showRewardDetails(from: view)
    }
}

extension StakingRewardPayoutsPresenter: StakingRewardPayoutsInteractorOutputProtocol {

}
