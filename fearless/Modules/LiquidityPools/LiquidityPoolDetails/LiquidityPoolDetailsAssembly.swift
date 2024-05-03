import UIKit
import SoraFoundation

final class LiquidityPoolDetailsAssembly {
    static func configureModule() -> LiquidityPoolDetailsModuleCreationResult? {
        let localizationManager = LocalizationManager.shared
            
        let interactor = LiquidityPoolDetailsInteractor()
        let router = LiquidityPoolDetailsRouter()
        
        let presenter = LiquidityPoolDetailsPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )
        
        let view = LiquidityPoolDetailsViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
