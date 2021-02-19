import Foundation

final class StakingAmountViewFactory: StakingAmountViewFactoryProtocol {
    static func createView() -> StakingAmountViewProtocol? {
        let view = StakingAmountViewController(nib: R.nib.stakingAmountViewController)
        let presenter = StakingAmountPresenter()
        let interactor = StakingAmountInteractor()
        let wireframe = StakingAmountWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
