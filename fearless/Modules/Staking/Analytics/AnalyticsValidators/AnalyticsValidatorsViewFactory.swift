import Foundation
import SoraFoundation

struct AnalyticsValidatorsViewFactory {
    static func createView() -> AnalyticsValidatorsViewProtocol? {
        let interactor = AnalyticsValidatorsInteractor()
        let wireframe = AnalyticsValidatorsWireframe()
        let viewModelFactory = AnalyticsValidatorsViewModelFactory()
        let presenter = AnalyticsValidatorsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = AnalyticsValidatorsViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
