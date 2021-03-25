import Foundation

final class StakingRewardPayoutsViewFactory: StakingRewardPayoutsViewFactoryProtocol {
    static func createView() -> StakingRewardPayoutsViewProtocol? {
        let presenter = StakingRewardPayoutsPresenter()
        let view = StakingRewardPayoutsViewController(presenter: presenter)
        let interactor = StakingRewardPayoutsInteractor()
        let wireframe = StakingRewardPayoutsWireframe()

        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
