import Foundation

final class StakingConfirmViewFactory: StakingConfirmViewFactoryProtocol {
    static func createView() -> StakingConfirmViewProtocol? {
        let view = StakingConfirmViewController(nib: R.nib.stakingConfirmViewController)
        let presenter = StakingConfirmPresenter()
        let interactor = StakingConfirmInteractor()
        let wireframe = StakingConfirmWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
