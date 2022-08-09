import UIKit
import SoraFoundation

final class ChainAssetListAssembly {
    static func configureModule() -> ChainAssetListModuleCreationResult? {
        let localizationManager = LocalizationManager.shared
            
        let interactor = ChainAssetListInteractor()
        let router = ChainAssetListRouter()
        
        let presenter = ChainAssetListPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )
        
        let view = ChainAssetListViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
