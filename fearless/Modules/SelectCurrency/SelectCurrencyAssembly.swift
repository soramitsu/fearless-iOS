import UIKit
import SoraFoundation
import SoraKeystore

final class SelectCurrencyAssembly {
    static func configureModule() -> SelectCurrencyModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let settings = SettingsManager.shared
        let interactor = SelectCurrencyInteractor(settings: settings)
        let router = SelectCurrencyRouter()

        let presenter = SelectCurrencyPresenter(
            interactor: interactor,
            router: router,
            viewModelFactory: SelectCurrencyViewModelFactory(),
            localizationManager: localizationManager
        )

        let view = SelectCurrencyViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
