import Foundation

final class AboutPresenter {
    weak var view: AboutViewProtocol?
    var wireframe: AboutWireframeProtocol!

    let about: AboutData
    let locale: Locale

    init(locale: Locale, about: AboutData) {
        self.locale = locale
        self.about = about
    }

    private func show(url: URL) {
        if let view = view {
            wireframe.showWeb(url: url, from: view, style: .automatic)
        }
    }
}

extension AboutPresenter: AboutPresenterProtocol {
    func setup() {
        let viewModel = AboutViewModel(
            website: about.websiteUrl.absoluteString,
            version: about.version,
            social: about.socialUrl.absoluteString,
            email: about.writeUs.email
        )
        view?.didReceive(viewModel: viewModel)
    }

    func activateWebsite() {
        show(url: about.websiteUrl)
    }

    func activateSocial() {
        show(url: about.socialUrl)
    }

    func activateOpensource() {
        show(url: about.opensourceUrl)
    }

    func activateTerms() {
        show(url: about.legal.termsUrl)
    }

    func activatePrivacyPolicy() {
        show(url: about.legal.privacyPolicyUrl)
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
                        .noEmailBoundErrorMessage(preferredLanguages: locale.rLanguages),
                    title: R.string.localizable
                        .commonErrorGeneralTitle(preferredLanguages: locale.rLanguages),
                    closeAction: R.string.localizable
                        .commonClose(preferredLanguages: locale.rLanguages),
                    from: view
                )
            }
        }
    }
}
