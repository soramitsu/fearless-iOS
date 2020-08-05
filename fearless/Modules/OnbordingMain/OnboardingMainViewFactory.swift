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

        view.presenter = presenter
        presenter.view = view
        presenter.wireframe = wireframe

        return view
    }
}
