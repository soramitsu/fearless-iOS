import Foundation
import SoraFoundation

final class StakingPayoutConfirmationViewFactory: StakingPayoutConfirmationViewFactoryProtocol {
    static func createView() -> StakingPayoutConfirmationViewProtocol? {
        let presenter = StakingPayoutConfirmationPresenter()
        let view = StakingPayoutConfirmationViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        let interactor = StakingPayoutConfirmationInteractor()
        let wireframe = StakingPayoutConfirmationWireframe()

        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
