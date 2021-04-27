import SoraFoundation
import SoraKeystore
import RobinHood
import FearlessUtils

struct StakingBondMoreViewFactory {
    static func createView() -> StakingBondMoreViewProtocol? {
        let interactor = StakingBondMoreInteractor()
        let wireframe = StakingBondMoreWireframe()
        let viewModelFactory = StakingBondMoreViewModelFactory()

        let presenter = StakingBondMorePresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory
        )
        let viewController = StakingBondMoreViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )
        presenter.view = viewController
        interactor.presenter = presenter

        return viewController
    }
}
