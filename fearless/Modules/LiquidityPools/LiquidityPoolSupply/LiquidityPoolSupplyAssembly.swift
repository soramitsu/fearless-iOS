import UIKit
import SoraFoundation

final class LiquidityPoolSupplyAssembly {
    static func configureModule() -> LiquidityPoolSupplyModuleCreationResult? {
        let localizationManager = LocalizationManager.shared
            
        let interactor = LiquidityPoolSupplyInteractor()
        let router = LiquidityPoolSupplyRouter()
        
        let presenter = LiquidityPoolSupplyPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )
        
        let view = LiquidityPoolSupplyViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
