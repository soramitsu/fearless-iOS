import UIKit
import SoraFoundation

final class StakingPoolMainAssembly {
    static func configureModule() -> StakingPoolMainModuleCreationResult? {
        let localizationManager = LocalizationManager.shared
            
        let interactor = StakingPoolMainInteractor()
        let router = StakingPoolMainRouter()
        
        let presenter = StakingPoolMainPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )
        
        let view = StakingPoolMainViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
