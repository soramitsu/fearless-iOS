import Foundation

final class StakingRewardPayoutsPresenter {
    weak var view: StakingRewardPayoutsViewProtocol?
    var wireframe: StakingRewardPayoutsWireframeProtocol!
    var interactor: StakingRewardPayoutsInteractorInputProtocol!
}

extension StakingRewardPayoutsPresenter: StakingRewardPayoutsPresenterProtocol {
    func setup() {
        view?.hideEmptyView()
        view?.startLoading()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak view] in
            view?.stopLoading()
            view?.showEmptyView()
        }
    }

    func handleSelectedHistory(at _: IndexPath) {
        // TODO: get model by indexPath -> pass to wireframe
        wireframe.showRewardDetails(from: view)
    }

    func handlePayoutAction() {
        wireframe.showRewardDetails(from: view)
    }
}

extension StakingRewardPayoutsPresenter: StakingRewardPayoutsInteractorOutputProtocol {}
