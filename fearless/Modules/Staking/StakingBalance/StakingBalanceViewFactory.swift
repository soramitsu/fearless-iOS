import SoraFoundation

struct StakingBalanceViewFactory {
    static func createView() -> StakingBalanceViewProtocol? {
        let interactor = StakingBalanceInteractor()
        let wireframe = StakingBalanceWireframe()
        let presenter = StakingBalancePresenter(
            interactor: interactor,
            wireframe: wireframe
        )
        interactor.presenter = presenter

        let viewController = StakingBalanceViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )
        presenter.view = viewController

        return viewController
    }
}
