import Foundation
import SoraFoundation

struct CrowdloanAgreementViewFactory {
    static func createView() -> CrowdloanAgreementViewProtocol? {
        let localizationManager = LocalizationManager.shared

        let interactor = CrowdloanAgreementInteractor()
        let wireframe = CrowdloanAgreementWireframe()

        let presenter = CrowdloanAgreementPresenter(
            interactor: interactor,
            wireframe: wireframe
        )

        let view = CrowdloanAgreementViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
