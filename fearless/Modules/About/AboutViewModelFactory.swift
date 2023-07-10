import Foundation
import UIKit

protocol AboutViewModelFactoryProtocol: AnyObject {
    var about: AboutData { get }
    func createAboutItemViewModels(locale: Locale) -> [AboutViewModel]
}

enum AboutRow: CaseIterable {
    case web
    case git
    case twitter
    case youtube
    case instagram
    case medium
    case wiki
    case telegramMain
    case telegramAnnouncements
    case telegramSupport
    case email
    case terms
    case privacy
}

final class AboutViewModelFactory: AboutViewModelFactoryProtocol {
    let about: AboutData

    init(about: AboutData) {
        self.about = about
    }

    // swiftlint:disable cyclomatic_complexity function_body_length
    func createAboutItemViewModels(locale: Locale) -> [AboutViewModel] {
        let rLanguages = locale.rLanguages

        let aboutViewModels = AboutRow.allCases.map { aboutRow -> AboutViewModel in
            switch aboutRow {
            case .web:
                return createAboutItem(
                    title: R.string.localizable
                        .aboutWebsite(preferredLanguages: rLanguages),
                    subtitle: about.websiteUrl.host,
                    icon: R.image.iconAboutWebsite(),
                    url: about.websiteUrl
                )
            case .git:
                return createAboutItem(
                    title: R.string.localizable
                        .aboutVersion(preferredLanguages: rLanguages),
                    subtitle: R.string.localizable
                        .aboutVersion(preferredLanguages: rLanguages) + " " + about.version,
                    icon: R.image.iconAboutGithub(),
                    url: about.opensourceUrl
                )
            case .twitter:
                return createAboutItem(
                    title: R.string.localizable
                        .aboutTwitter(preferredLanguages: rLanguages),
                    subtitle: createSubtitle(from: about.twitter),
                    icon: R.image.iconAboutTwitter(),
                    url: about.twitter
                )
            case .youtube:
                return createAboutItem(
                    title: R.string.localizable
                        .aboutYoutube(preferredLanguages: rLanguages),
                    subtitle: createSubtitle(from: about.youTube),
                    icon: R.image.iconAboutYoutube(),
                    url: about.youTube
                )
            case .instagram:
                return createAboutItem(
                    title: R.string.localizable
                        .aboutInstagram(preferredLanguages: rLanguages),
                    subtitle: createSubtitle(from: about.instagram),
                    icon: R.image.iconAboutInstagram(),
                    url: about.instagram
                )
            case .medium:
                return createAboutItem(
                    title: R.string.localizable
                        .aboutMedium(preferredLanguages: rLanguages),
                    subtitle: createSubtitle(from: about.medium),
                    icon: R.image.iconAboutMedium(),
                    url: about.medium
                )
            case .wiki:
                return createAboutItem(
                    title: R.string.localizable
                        .aboutWiki(preferredLanguages: rLanguages),
                    subtitle: createSubtitle(from: about.wiki),
                    icon: R.image.iconAboutWiki(),
                    url: about.wiki
                )
            case .telegramMain:
                return createAboutItem(
                    title: R.string.localizable
                        .aboutTelegram(preferredLanguages: rLanguages),
                    subtitle: createSubtitle(from: about.telegram.fearlessWallet),
                    icon: R.image.iconAboutTelegram(),
                    url: about.telegram.fearlessWallet
                )
            case .telegramAnnouncements:
                return createAboutItem(
                    title: R.string.localizable
                        .aboutAnnouncement(preferredLanguages: rLanguages),
                    subtitle: createSubtitle(from: about.telegram.fearlessAnnouncements),
                    icon: R.image.iconAboutAnnouncements(),
                    url: about.telegram.fearlessAnnouncements
                )
            case .telegramSupport:
                return createAboutItem(
                    title: R.string.localizable
                        .aboutSupport(preferredLanguages: rLanguages),
                    subtitle: createSubtitle(from: about.telegram.fearlessHappiness),
                    icon: R.image.iconAboutSupport(),
                    url: about.telegram.fearlessHappiness
                )
            case .email:
                return createAboutItem(
                    title: R.string.localizable
                        .aboutContactEmail(preferredLanguages: rLanguages),
                    subtitle: about.writeUs.email,
                    icon: R.image.iconAboutEmail(),
                    url: nil
                )
            case .terms:
                return createAboutItem(
                    title: R.string.localizable
                        .commonTermsAndConditions(preferredLanguages: rLanguages),
                    subtitle: nil,
                    icon: R.image.iconCheckMark(),
                    url: about.legal.termsUrl
                )
            case .privacy:
                return createAboutItem(
                    title: R.string.localizable
                        .aboutPrivacy(preferredLanguages: rLanguages),
                    subtitle: nil,
                    icon: R.image.iconCheckMark(),
                    url: about.legal.privacyPolicyUrl
                )
            }
        }

        return aboutViewModels
    }

    private func createAboutItem(
        title: String,
        subtitle: String?,
        icon: UIImage?,
        url: URL?
    ) -> AboutViewModel {
        AboutViewModel(title: title, subtitle: subtitle, icon: icon, url: url)
    }

    private func createSubtitle(from url: URL) -> String? {
        guard let host = url.host else { return nil }
        return host + url.path
    }
}
