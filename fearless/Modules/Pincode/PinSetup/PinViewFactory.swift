import Foundation
import SoraKeystore
import SoraFoundation

class PinViewFactory: PinViewFactoryProtocol {
    static func createPinSetupView() -> PinSetupViewProtocol? {
        let pinSetupView = PinSetupViewController(nib: R.nib.pinSetupViewController)

        pinSetupView.mode = .create

        pinSetupView.localizableTopTitle = LocalizableResource { locale in
            R.string.localizable.pincodeSetupTopTitle(preferredLanguages: locale.rLanguages)
        }
        let interactor = PinSetupInteractor(
            secretManager: KeychainManager.shared(with: .userInteractive),
            settingsManager: SettingsManager.shared,
            biometryAuth: BiometryAuth(),
            locale: LocalizationManager.shared.selectedLocale
        )
        let wireframe = PinSetupWireframe()

        let presenter = PinSetupPresenter(
            interactor: interactor,
            wireframe: wireframe
        )

        pinSetupView.presenter = presenter
        interactor.presenter = presenter

        pinSetupView.localizationManager = LocalizationManager.shared

        return pinSetupView
    }

    static func createPinChangeView() -> PinSetupViewProtocol? {
        let pinChangeView = PinSetupViewController(nib: R.nib.pinSetupViewController)

        pinChangeView.mode = .create

        pinChangeView.localizableTopTitle = LocalizableResource { locale in
            R.string.localizable.profilePincodeChangeTitle(preferredLanguages: locale.rLanguages)
        }

        let interactor = PinChangeInteractor(secretManager: KeychainManager.shared(with: .userInteractive))
        let wireframe = PinChangeWireframe(localizationManager: LocalizationManager.shared)
        let presenter = PinSetupPresenter(
            interactor: interactor,
            wireframe: wireframe
        )

        pinChangeView.presenter = presenter
        interactor.presenter = presenter

        pinChangeView.localizationManager = LocalizationManager.shared

        return pinChangeView
    }

    static func createSecuredPinView() -> PinSetupViewProtocol? {
        let pinVerifyView = PinSetupViewController(nib: R.nib.pinSetupViewController)
        let wireframe = PinSetupWireframe()

        pinVerifyView.modalPresentationStyle = .fullScreen

        pinVerifyView.mode = .securedInput

        let interactor = LocalAuthInteractor(
            secretManager: KeychainManager.shared(with: .userInteractive),
            settingsManager: SettingsManager.shared,
            biometryAuth: BiometryAuth(),
            locale: LocalizationManager.shared.selectedLocale
        )
        let presenter = LocalAuthPresenter(
            wireframe: wireframe,
            interactor: interactor,
            userDefaultsStorage: SettingsManager.shared
        )

        pinVerifyView.presenter = presenter
        pinVerifyView.localizationManager = LocalizationManager.shared

        return pinVerifyView
    }

    static func createScreenAuthorizationView(
        with wireframe: ScreenAuthorizationWireframeProtocol,
        cancellable: Bool
    ) -> PinSetupViewProtocol? {
        let pinVerifyView = PinSetupViewController(nib: R.nib.pinSetupViewController)
        pinVerifyView.cancellable = cancellable

        pinVerifyView.mode = .securedInput

        let interactor = LocalAuthInteractor(
            secretManager: KeychainManager.shared(with: .userInteractive),
            settingsManager: SettingsManager.shared,
            biometryAuth: BiometryAuth(),
            locale: LocalizationManager.shared.selectedLocale
        )
        let presenter = ScreenAuthorizationPresenter(
            wireframe: wireframe,
            interactor: interactor
        )

        pinVerifyView.presenter = presenter
        pinVerifyView.localizationManager = LocalizationManager.shared

        return pinVerifyView
    }

    static func createPinCheckView() -> PinSetupViewProtocol? {
        let pinVerifyView = PinSetupViewController(nib: R.nib.pinSetupViewController)
        let wireframe = CheckPincodeWireframe()

        pinVerifyView.modalPresentationStyle = .fullScreen

        pinVerifyView.mode = .securedInput

        let interactor = LocalAuthInteractor(
            secretManager: KeychainManager.shared(with: .userInteractive),
            settingsManager: SettingsManager.shared,
            biometryAuth: BiometryAuth(),
            locale: LocalizationManager.shared.selectedLocale
        )
        let presenter = LocalAuthPresenter(
            wireframe: wireframe,
            interactor: interactor,
            userDefaultsStorage: SettingsManager.shared
        )

        pinVerifyView.presenter = presenter
        pinVerifyView.localizationManager = LocalizationManager.shared

        return pinVerifyView
    }
}
