import Foundation
import SoraKeystore
import SoraFoundation

final class OnboardingMainViewFactory: OnboardingMainViewFactoryProtocol {
    static func createViewForOnboarding() -> OnboardingMainViewProtocol? {
        let wireframe = OnboardingMainWireframe()
        return createView(for: wireframe)
    }

    static func createViewForAdding() -> OnboardingMainViewProtocol? {
        let wireframe = AddAccount.OnboardingMainWireframe()
        return createView(for: wireframe)
    }

    // TODO: Remove with connection refactoring
    static func createViewForConnection(item _: ConnectionItem) -> OnboardingMainViewProtocol? {
        nil
    }

    static func createViewForAccountSwitch() -> OnboardingMainViewProtocol? {
        let wireframe = SwitchAccount.OnboardingMainWireframe()
        return createView(for: wireframe)
    }

    private static func createView(
        for wireframe: OnboardingMainWireframeProtocol
    ) -> OnboardingMainViewProtocol? {
        guard let kestoreImportService: KeystoreImportServiceProtocol =
            URLHandlingService.shared.findService()
        else {
            Logger.shared.error("Can't find required keystore import service")
            return nil
        }

        let applicationConfig: ApplicationConfigProtocol = ApplicationConfig.shared

        let locale: Locale = LocalizationManager.shared.selectedLocale

        let legalData = LegalData(
            termsUrl: applicationConfig.termsURL,
            privacyPolicyUrl: applicationConfig.privacyPolicyURL
        )

        let view = OnboardingMainViewController(nib: R.nib.onbordingMain)
        view.termDecorator = CompoundAttributedStringDecorator.legal(for: locale)
        view.locale = locale

        let presenter = OnboardingMainPresenter(legalData: legalData, locale: locale)

        let interactor = OnboardingMainInteractor(keystoreImportService: kestoreImportService)

        view.presenter = presenter
        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor

        interactor.presenter = presenter

        return view
    }
}
