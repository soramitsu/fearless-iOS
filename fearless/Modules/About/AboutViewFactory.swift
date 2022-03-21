import Foundation
import SoraFoundation

final class AboutViewFactory: AboutViewFactoryProtocol {
    static func createView() -> AboutViewProtocol? {
        let locale = LocalizationManager.shared.selectedLocale

        let config: ApplicationConfigProtocol = ApplicationConfig.shared
        let legal = LegalData(termsUrl: config.termsURL, privacyPolicyUrl: config.privacyPolicyURL)

        let supportData = SupportData(
            title: R.string.localizable
                .helpSupportTitle(preferredLanguages: locale.rLanguages),
            subject: "",
            details: "",
            email: ApplicationConfig.shared.supportEmail
        )

        let about = AboutData(
            websiteUrl: config.websiteURL,
            opensourceUrl: config.opensourceURL,
            twitter: config.twitter,
            youTube: config.youTube,
            instagram: config.instagram,
            medium: config.medium,
            wiki: config.wiki,
            telegram: TelegramData(
                fearlessWallet: config.fearlessWallet,
                fearlessAnnouncements: config.fearlessAnnouncements,
                fearlessHappiness: config.fearlessHappiness
            ),
            writeUs: supportData,
            version: config.version,
            legal: legal
        )

        let wireframe = AboutWireframe()
        let localizationManager = LocalizationManager.shared

        let presenter = AboutPresenter(
            about: about,
            wireframe: wireframe,
            localizationManager: localizationManager
        )
        let view = AboutViewController(locale: locale, presenter: presenter)

        return view
    }
}
