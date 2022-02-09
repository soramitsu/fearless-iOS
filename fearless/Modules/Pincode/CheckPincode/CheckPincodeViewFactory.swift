import SoraKeystore
import SoraFoundation

final class CheckPincodeViewFactory {
    static func createView(
        moduleOutput: CheckPincodeModuleOutput
    ) -> PinSetupViewProtocol {
        let pinVerifyView = PinSetupViewController(nib: R.nib.pinSetupViewController)

        pinVerifyView.mode = .securedInput

        let interactor = LocalAuthInteractor(
            secretManager: KeychainManager.shared,
            settingsManager: SettingsManager.shared,
            biometryAuth: BiometryAuth(),
            locale: LocalizationManager.shared.selectedLocale
        )
        let presenter = CheckPincodePresenter(
            interactor: interactor,
            moduleOutput: moduleOutput
        )

        pinVerifyView.presenter = presenter
        presenter.view = pinVerifyView

        interactor.presenter = presenter

        pinVerifyView.localizationManager = LocalizationManager.shared

        return pinVerifyView
    }
}
