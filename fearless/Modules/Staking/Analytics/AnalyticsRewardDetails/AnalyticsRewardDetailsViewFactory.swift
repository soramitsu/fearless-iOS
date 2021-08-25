import Foundation
import SoraFoundation

struct AnalyticsRewardDetailsViewFactory {
    static func createView() -> AnalyticsRewardDetailsViewProtocol? {
        let interactor = AnalyticsRewardDetailsInteractor()
        let wireframe = AnalyticsRewardDetailsWireframe()

        let presenter = AnalyticsRewardDetailsPresenter(interactor: interactor, wireframe: wireframe)

        let view = AnalyticsRewardDetailsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
