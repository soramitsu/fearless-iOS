import Foundation

struct CrowdloanContributionConfirmViewFactory {
    static func createView() -> CrowdloanContributionConfirmViewProtocol? {
        let interactor = CrowdloanContributionConfirmInteractor()
        let wireframe = CrowdloanContributionConfirmWireframe()

        let presenter = CrowdloanContributionConfirmPresenter(interactor: interactor, wireframe: wireframe)

        let view = CrowdloanContributionConfirmViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
