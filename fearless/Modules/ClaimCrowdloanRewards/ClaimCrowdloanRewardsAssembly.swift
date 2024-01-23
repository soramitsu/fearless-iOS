import UIKit
import SoraFoundation

final class ClaimCrowdloanRewardsAssembly {
    static func configureModule() -> ClaimCrowdloanRewardsModuleCreationResult? {
        let localizationManager = LocalizationManager.shared
            
        let interactor = ClaimCrowdloanRewardsInteractor()
        let router = ClaimCrowdloanRewardsRouter()
        
        let presenter = ClaimCrowdloanRewardsPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )
        
        let view = ClaimCrowdloanRewardsViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
