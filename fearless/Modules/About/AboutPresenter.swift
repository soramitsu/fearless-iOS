import Foundation
import SoraFoundation

final class AboutPresenter {
    private weak var view: AboutViewProtocol?
    private let wireframe: AboutWireframeProtocol
    private let about: AboutData

    init(
        about: AboutData,
        wireframe: AboutWireframeProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.wireframe = wireframe
        self.about = about
        self.localizationManager = localizationManager
    }

    private func show(url: URL) {
        if let view = view {
            wireframe.showWeb(url: url, from: view, style: .automatic)
        }
    }
}

extension AboutPresenter: AboutPresenterProtocol {
    func didLoad(view: AboutViewProtocol) {
        self.view = view

        view.didReceive(viewModel: aboutRows())
        view.didReceive(locale: selectedLocale)
    }

    func activate(url: URL) {
        show(url: url)
    }

    func activateWriteUs() {
        if let view = view {
            let message = SocialMessage(
                body: nil,
                subject: about.writeUs.subject,
                recepients: [about.writeUs.email]
            )
            if !wireframe.writeEmail(with: message, from: view, completionHandler: nil) {
                wireframe.present(
                    message: R.string.localizable
                        .noEmailBoundErrorMessage(preferredLanguages: selectedLocale.rLanguages),
                    title: R.string.localizable
                        .commonErrorGeneralTitle(preferredLanguages: selectedLocale.rLanguages),
                    closeAction: R.string.localizable
                        .commonClose(preferredLanguages: selectedLocale.rLanguages),
                    from: view
                )
            }
        }
    }
}

extension AboutPresenter: Localizable {
    func applyLocalization() {
        view?.didReceive(locale: selectedLocale)
        view?.didReceive(viewModel: aboutRows())
    }
}

extension AboutPresenter {
    // swiftlint:disable function_body_length
    private func aboutRows() -> [AboutViewModel] {
        [
            AboutViewModel( // web
                title: R.string.localizable
                    .aboutWebsite(preferredLanguages: selectedLocale.rLanguages),
                subtitle: about.websiteUrl.removeHttpsScheme(),
                icon: R.image.iconAboutWebsite(),
                url: about.websiteUrl
            ),
            AboutViewModel( // git
                title: R.string.localizable
                    .aboutVersion(preferredLanguages: selectedLocale.rLanguages),
                subtitle: R.string.localizable
                    .aboutVersion(preferredLanguages: selectedLocale.rLanguages) + " " + about.version,
                icon: R.image.iconAboutGithub(),
                url: about.opensourceUrl
            ),
            AboutViewModel( // twitter
                title: R.string.localizable
                    .aboutTwitter(preferredLanguages: selectedLocale.rLanguages),
                subtitle: about.twitter.removeHttpsScheme(),
                icon: R.image.iconAboutTwitter(),
                url: about.twitter
            ),
            AboutViewModel( // youTube
                title: R.string.localizable
                    .aboutYoutube(preferredLanguages: selectedLocale.rLanguages),
                subtitle: about.youTube.removeHttpsScheme(),
                icon: R.image.iconAboutYoutube(),
                url: about.youTube
            ),
            AboutViewModel( // instagram
                title: R.string.localizable
                    .aboutInstagram(preferredLanguages: selectedLocale.rLanguages),
                subtitle: about.instagram.removeHttpsScheme(),
                icon: R.image.iconAboutInstagram(),
                url: about.instagram
            ),
            AboutViewModel( // medium
                title: R.string.localizable
                    .aboutMedium(preferredLanguages: selectedLocale.rLanguages),
                subtitle: about.medium.removeHttpsScheme(),
                icon: R.image.iconAboutMedium(),
                url: about.medium
            ),
            AboutViewModel( // wiki
                title: R.string.localizable
                    .aboutWiki(preferredLanguages: selectedLocale.rLanguages),
                subtitle: about.wiki.removeHttpsScheme(),
                icon: R.image.iconAboutWiki(),
                url: about.wiki
            ),
            AboutViewModel( // telegram main
                title: R.string.localizable
                    .aboutTelegram(preferredLanguages: selectedLocale.rLanguages),
                subtitle: about.telegram.fearlessWallet.removeHttpsScheme(),
                icon: R.image.iconAboutTelegram(),
                url: about.telegram.fearlessWallet
            ),
            AboutViewModel( // telegram announcements
                title: R.string.localizable
                    .aboutAnnouncement(preferredLanguages: selectedLocale.rLanguages),
                subtitle: about.telegram.fearlessAnnouncements.removeHttpsScheme(),
                icon: R.image.iconAboutAnnouncements(),
                url: about.telegram.fearlessAnnouncements
            ),
            AboutViewModel( // telegram support
                title: R.string.localizable
                    .aboutSupport(preferredLanguages: selectedLocale.rLanguages),
                subtitle: about.telegram.fearlessHappiness.removeHttpsScheme(),
                icon: R.image.iconAboutSupport(),
                url: about.telegram.fearlessHappiness
            ),
            AboutViewModel( // email
                title: R.string.localizable
                    .aboutContactUs(preferredLanguages: selectedLocale.rLanguages),
                subtitle: about.writeUs.email,
                icon: R.image.iconAboutEmail(),
                url: nil
            ),
            AboutViewModel( // terms
                title: R.string.localizable
                    .aboutTerms(preferredLanguages: selectedLocale.rLanguages),
                subtitle: nil,
                icon: R.image.iconAboutTermsPrivacy(),
                url: about.legal.termsUrl
            ),
            AboutViewModel( // privacy
                title: R.string.localizable
                    .aboutPrivacy(preferredLanguages: selectedLocale.rLanguages),
                subtitle: nil,
                icon: R.image.iconAboutTermsPrivacy(),
                url: about.legal.privacyPolicyUrl
            )
        ]
    }
}
