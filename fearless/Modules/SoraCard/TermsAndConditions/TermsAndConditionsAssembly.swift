import UIKit
import SoraFoundation

final class TermsAndConditionsAssembly {
    static func configureModule() -> TermsAndConditionsModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let router = TermsAndConditionsRouter()
        let config: ApplicationConfigProtocol = ApplicationConfig.shared

        let presenter = TermsAndConditionsPresenter(
            router: router,
            localizationManager: localizationManager,
            termsUrl: config.soraCardTerms,
            privacyUrl: config.soraCardPrivacy
        )

        let view = TermsAndConditionsViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
