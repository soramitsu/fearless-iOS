import Foundation
import SoraFoundation

struct CrowdloanContributionConfirmViewFactory {
    static func createView(with _: ParaId, inputAmount _: Decimal) -> CrowdloanContributionConfirmViewProtocol? {
        let interactor = CrowdloanContributionConfirmInteractor()
        let wireframe = CrowdloanContributionConfirmWireframe()

        let presenter = CrowdloanContributionConfirmPresenter(interactor: interactor, wireframe: wireframe)

        let localizationManager = LocalizationManager.shared

        let view = CrowdloanContributionConfirmVC(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
