import Foundation

final class StakingPayoutConfirmationViewFactory: StakingPayoutConfirmationViewFactoryProtocol {

    static func createView() -> StakingPayoutConfirmationViewProtocol? {
        let presenter = StakingPayoutConfirmationPresenter()
        let view = StakingPayoutConfirmationViewController(presenter: presenter)

        let interactor = StakingPayoutConfirmationInteractor()
        let wireframe = StakingPayoutConfirmationWireframe()

        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
