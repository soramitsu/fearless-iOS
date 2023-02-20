import UIKit
import SoraFoundation
import SoraKeystore

final class PolkaswapDisclaimerAssembly {
    static func configureModule(
        moduleOutput: PolkaswapDisclaimerModuleOutput? = nil
    ) -> PolkaswapDisclaimerModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let interactor = PolkaswapDisclaimerInteractor(
            userDefaultsStorage: SettingsManager.shared
        )
        let router = PolkaswapDisclaimerRouter()

        let presenter = PolkaswapDisclaimerPresenter(
            interactor: interactor,
            router: router,
            viewModelFactory: PolkaswapDisclaimerViewModelFactory(),
            moduleOutput: moduleOutput,
            localizationManager: localizationManager
        )

        let view = PolkaswapDisclaimerViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
