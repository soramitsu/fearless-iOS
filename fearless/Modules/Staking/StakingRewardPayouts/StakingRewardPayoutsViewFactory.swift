import Foundation

final class StakingRewardPayoutsViewFactory: StakingRewardPayoutsViewFactoryProtocol {
    static func createView() -> StakingRewardPayoutsViewProtocol? {
        let view = StakingRewardPayoutsViewController()
        let presenter = StakingRewardPayoutsPresenter()
        let interactor = StakingRewardPayoutsInteractor()
        let wireframe = StakingRewardPayoutsWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
