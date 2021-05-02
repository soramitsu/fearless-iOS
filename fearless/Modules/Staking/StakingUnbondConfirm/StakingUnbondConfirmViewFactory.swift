import Foundation
import SoraFoundation

struct StakingUnbondConfirmViewFactory: StakingUnbondConfirmViewFactoryProtocol {
    static func createView(from _: Decimal) -> StakingUnbondConfirmViewProtocol? {
        let interactor = StakingUnbondConfirmInteractor()
        let wireframe = StakingUnbondConfirmWireframe()

        let presenter = StakingUnbondConfirmPresenter(interactor: interactor, wireframe: wireframe)

        let view = StakingUnbondConfirmViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
