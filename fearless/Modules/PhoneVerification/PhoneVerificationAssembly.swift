import UIKit
import SoraFoundation

final class PhoneVerificationAssembly {
    static func configureModule() -> PhoneVerificationModuleCreationResult? {
        let localizationManager = LocalizationManager.shared
            
        let interactor = PhoneVerificationInteractor()
        let router = PhoneVerificationRouter()
        
        let presenter = PhoneVerificationPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )
        
        let view = PhoneVerificationViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
