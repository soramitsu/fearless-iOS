import UIKit
import SoraFoundation

final class IntroduceAssembly {
    static func configureModule() -> IntroduceModuleCreationResult? {
        let localizationManager = LocalizationManager.shared
            
        let interactor = IntroduceInteractor()
        let router = IntroduceRouter()
        
        let presenter = IntroducePresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )
        
        let view = IntroduceViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
