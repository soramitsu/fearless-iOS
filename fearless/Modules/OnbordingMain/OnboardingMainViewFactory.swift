import Foundation
import SoraKeystore
import SoraFoundation

final class OnboardingMainViewFactory: OnboardingMainViewFactoryProtocol {
    static func createView() -> OnboardingMainViewProtocol? {
        let applicationConfig: ApplicationConfigProtocol = ApplicationConfig.shared

        let locale: Locale = LocalizationManager.shared.selectedLocale

        let legalData = LegalData(termsUrl: applicationConfig.termsURL,
                              privacyPolicyUrl: applicationConfig.privacyPolicyURL)

        let view = OnboardingMainViewController(nib: R.nib.onbordingMain)
        view.termDecorator = CompoundAttributedStringDecorator.legal(for: locale)
        view.locale = locale

        let presenter = OnboardingMainPresenter(legalData: legalData, locale: locale)
        let wireframe = OnboardingMainWireframe()

        let interactor = createInteractor()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe

        interactor.presenter = presenter

        return view
    }

    private static func createInteractor() -> OnboardingMainInteractor {
        let accountOperationFactory = AccountOperationFactory(keystore: Keychain(),
                                                              settings: SettingsManager.shared)
        let interactor = OnboardingMainInteractor(accountOperationFactory: accountOperationFactory,
                                                  settings: SettingsManager.shared,
                                                  operationManager: OperationManagerFacade.sharedManager)
        return interactor
    }
}
