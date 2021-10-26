import Foundation

struct CrowdloanAgreementConfirmViewFactory {
    static func createView() -> CrowdloanAgreementConfirmViewProtocol? {
        let interactor = CrowdloanAgreementConfirmInteractor()
        let wireframe = CrowdloanAgreementConfirmWireframe()

        let presenter = CrowdloanAgreementConfirmPresenter(interactor: interactor, wireframe: wireframe)

        let view = CrowdloanAgreementConfirmViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
