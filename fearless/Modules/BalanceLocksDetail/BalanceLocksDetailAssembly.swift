import UIKit
import SoraFoundation

final class BalanceLocksDetailAssembly {
    static func configureModule() -> BalanceLocksDetailModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let interactor = BalanceLocksDetailInteractor()
        let router = BalanceLocksDetailRouter()

        let presenter = BalanceLocksDetailPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        let view = BalanceLocksDetailViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
