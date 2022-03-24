import Foundation
import SoraFoundation

final class AboutPresenter {
    private weak var view: AboutViewProtocol?
    private let wireframe: AboutWireframeProtocol
    private let aboutViewModelFactory: AboutViewModelFactoryProtocol
    private let about: AboutData

    init(
        about: AboutData,
        wireframe: AboutWireframeProtocol,
        aboutViewModelFactory: AboutViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.wireframe = wireframe
        self.about = about
        self.aboutViewModelFactory = aboutViewModelFactory
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

        let aboutItemViewModels = aboutViewModelFactory.createAboutItemViewModels(locale: selectedLocale)
        let state = AboutViewState.loaded(aboutItemViewModels)

        view.didReceive(state: state)
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
        let aboutItemViewModels = aboutViewModelFactory.createAboutItemViewModels(locale: selectedLocale)
        let state = AboutViewState.loaded(aboutItemViewModels)
        view?.didReceive(state: state)
    }
}
