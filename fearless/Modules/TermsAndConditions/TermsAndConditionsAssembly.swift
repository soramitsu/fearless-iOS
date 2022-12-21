import UIKit
import SoraFoundation

final class TermsAndConditionsAssembly {
    static func configureModule() -> TermsAndConditionsModuleCreationResult? {
        let localizationManager = LocalizationManager.shared
            
        let interactor = TermsAndConditionsInteractor()
        let router = TermsAndConditionsRouter()
        
        let presenter = TermsAndConditionsPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )
        
        let view = TermsAndConditionsViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
