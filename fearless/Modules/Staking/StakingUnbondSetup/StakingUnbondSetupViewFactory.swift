import Foundation
import SoraFoundation

final class StakingUnbondSetupViewFactory: StakingUnbondSetupViewFactoryProtocol {
    static func createView() -> StakingUnbondSetupViewProtocol? {
        let interactor = StakingUnbondSetupInteractor()
        let wireframe = StakingUnbondSetupWireframe()

        let presenter = StakingUnbondSetupPresenter(interactor: interactor, wireframe: wireframe)

        let view = StakingUnbondSetupViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
