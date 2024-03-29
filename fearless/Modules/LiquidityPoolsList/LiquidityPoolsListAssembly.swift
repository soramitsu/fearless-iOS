import UIKit
import SoraFoundation

final class LiquidityPoolsListAssembly {
    static func configureModule() -> LiquidityPoolsListModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let interactor = LiquidityPoolsListInteractor()
        let router = LiquidityPoolsListRouter()

        let presenter = LiquidityPoolsListPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        let view = LiquidityPoolsListViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
