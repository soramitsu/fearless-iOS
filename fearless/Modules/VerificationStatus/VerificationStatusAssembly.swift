import UIKit
import SoraFoundation

final class VerificationStatusAssembly {
    static func configureModule() -> VerificationStatusModuleCreationResult? {
        let localizationManager = LocalizationManager.shared
            
        let interactor = VerificationStatusInteractor()
        let router = VerificationStatusRouter()
        
        let presenter = VerificationStatusPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )
        
        let view = VerificationStatusViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
