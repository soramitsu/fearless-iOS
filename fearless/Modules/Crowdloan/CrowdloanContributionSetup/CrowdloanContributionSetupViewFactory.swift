import Foundation

struct CrowdloanContributionSetupViewFactory {
    static func createView() -> CrowdloanContributionSetupViewProtocol? {
        let interactor = CrowdloanContributionSetupInteractor()
        let wireframe = CrowdloanContributionSetupWireframe()

        let presenter = CrowdloanContributionSetupPresenter(interactor: interactor, wireframe: wireframe)

        let view = CrowdloanContributionSetupViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
