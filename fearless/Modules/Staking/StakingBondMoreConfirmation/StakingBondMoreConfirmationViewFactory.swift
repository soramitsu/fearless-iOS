import SoraFoundation
import SoraKeystore
import RobinHood
import FearlessUtils
import CommonWallet

struct StakingBMConfirmationViewFactory {
    static func createView() -> StakingBondMoreConfirmationViewProtocol? {
        let interactor = StakingBondMoreConfirmationInteractor()
        let wireframe = StakingBondMoreConfirmationWireframe()
        let presenter = StakingBondMoreConfirmationPresenter(
            interactor: interactor,
            wireframe: wireframe
        )
        let viewController = StakingBMConfirmationVC(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )
        presenter.view = viewController
        interactor.presenter = presenter

        return viewController
    }
}
