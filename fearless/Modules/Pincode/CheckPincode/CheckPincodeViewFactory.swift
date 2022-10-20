import SoraKeystore
import SoraFoundation

final class CheckPincodeViewFactory {
    static func createView(
        moduleOutput: CheckPincodeModuleOutput
    ) -> PinSetupViewProtocol {
        let interactor = LocalAuthInteractor(
            secretManager: FWKeychainManager.shared,
            settingsManager: SettingsManager.shared,
            biometryAuth: BiometryAuth(),
            locale: LocalizationManager.shared.selectedLocale
        )
        let presenter = CheckPincodePresenter(
            interactor: interactor,
            moduleOutput: moduleOutput
        )

        let pinVerifyView = CheckPincodeViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        return pinVerifyView
    }
}
