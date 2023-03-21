import UIKit
import SoraFoundation

final class SCKYCTermsAndConditionsAssembly {
    static func configureModule() -> SCKYCTermsAndConditionsModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let router = SCKYCTermsAndConditionsRouter()
        let config: ApplicationConfigProtocol = ApplicationConfig.shared

        let presenter = SCKYCTermsAndConditionsPresenter(
            router: router,
            localizationManager: localizationManager,
            termsUrl: config.soraCardTerms,
            privacyUrl: config.soraCardPrivacy
        )

        let view = SCKYCTermsAndConditionsViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
