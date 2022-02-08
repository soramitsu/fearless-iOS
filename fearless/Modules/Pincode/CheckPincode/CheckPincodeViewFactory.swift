import SoraKeystore
import SoraFoundation

final class CheckPincodeViewFactory {
    static func createView(
        moduleOutput: CheckPincodeModuleOutput,
        targetView: UIViewController? = nil,
        presentationStyle: PresentationStyle
    ) -> PinSetupViewProtocol {
        let pinVerifyView = PinSetupViewController(nib: R.nib.pinSetupViewController)

        pinVerifyView.mode = .securedInput

        let interactor = LocalAuthInteractor(
            secretManager: KeychainManager.shared,
            settingsManager: SettingsManager.shared,
            biometryAuth: BiometryAuth(),
            locale: LocalizationManager.shared.selectedLocale
        )
        let wireframe = CheckPincodeWireframe(
            targetView: targetView,
            presentationStyle: presentationStyle
        )
        let presenter = CheckPincodePresenter(
            wireframe: wireframe,
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
