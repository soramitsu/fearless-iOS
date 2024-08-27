import UIKit
import SoraFoundation

final class FeatureToggleListAssembly {
    static func configureModule() -> FeatureToggleListModuleCreationResult? {
        let localizationManager = LocalizationManager.shared
            
        let interactor = FeatureToggleListInteractor()
        let router = FeatureToggleListRouter()
        
        let presenter = FeatureToggleListPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )
        
        let view = FeatureToggleListViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
