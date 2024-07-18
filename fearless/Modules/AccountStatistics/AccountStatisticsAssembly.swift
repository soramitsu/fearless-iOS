import UIKit
import SoraFoundation

final class AccountStatisticsAssembly {
    static func configureModule() -> AccountStatisticsModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let interactor = AccountStatisticsInteractor()
        let router = AccountStatisticsRouter()

        let presenter = AccountStatisticsPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        let view = AccountStatisticsViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
