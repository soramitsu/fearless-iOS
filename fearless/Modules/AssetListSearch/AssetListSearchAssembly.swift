import UIKit
import SoraFoundation

final class AssetListSearchAssembly {
    static func configureModule() -> AssetListSearchModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let interactor = AssetListSearchInteractor()
        let router = AssetListSearchRouter()

        let presenter = AssetListSearchPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        let view = AssetListSearchViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
