import Foundation
import SoraFoundation

final class TermsAndConditionsPresenter {
    // MARK: Private properties

    private weak var view: TermsAndConditionsViewInput?
    private let router: TermsAndConditionsRouterInput
    private let termsUrl: URL
    private let privacyURL: URL

    // MARK: - Constructors

    init(
        router: TermsAndConditionsRouterInput,
        localizationManager: LocalizationManagerProtocol,
        termsUrl: URL,
        privacyUrl: URL
    ) {
        self.router = router
        self.termsUrl = termsUrl
        privacyURL = privacyUrl

        self.localizationManager = localizationManager
    }

    // MARK: - Private methods
}

// MARK: - TermsAndConditionsViewOutput

extension TermsAndConditionsPresenter: TermsAndConditionsViewOutput {
    func didLoad(view: TermsAndConditionsViewInput) {
        self.view = view
    }

    func didTapTermsButton() {
        guard let view = view else { return }
        router.showWeb(
            url: termsUrl,
            from: view,
            style: .automatic
        )
    }

    func didTapPrivacyButton() {
        guard let view = view else { return }
        router.showWeb(
            url: privacyURL,
            from: view,
            style: .automatic
        )
    }

    func didTapAcceptButton() {
        router.presentPhoneVerification(from: view)
    }

    func didTapBackButton() {
        router.dismiss(view: view)
    }
}

// MARK: - TermsAndConditionsInteractorOutput

extension TermsAndConditionsPresenter: TermsAndConditionsInteractorOutput {}

// MARK: - Localizable

extension TermsAndConditionsPresenter: Localizable {
    func applyLocalization() {}
}

extension TermsAndConditionsPresenter: TermsAndConditionsModuleInput {}
