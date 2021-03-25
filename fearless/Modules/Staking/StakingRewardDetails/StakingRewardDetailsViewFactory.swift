import Foundation

final class StakingRewardDetailsViewFactory: StakingRewardDetailsViewFactoryProtocol {

    static func createView() -> StakingRewardDetailsViewProtocol? {
        let view = StakingRewardDetailsViewController()
        let presenter = StakingRewardDetailsPresenter()
        let interactor = StakingRewardDetailsInteractor()
        let wireframe = StakingRewardDetailsWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
