import Foundation
import SoraFoundation

final class SCKYCTermsAndConditionsPresenter {
    // MARK: Private properties

    private weak var view: SCKYCTermsAndConditionsViewInput?
    private let router: SCKYCTermsAndConditionsRouterInput
    private let termsUrl: URL
    private let privacyURL: URL

    // MARK: - Constructors

    init(
        router: SCKYCTermsAndConditionsRouterInput,
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

// MARK: - SCKYCTermsAndConditionsViewOutput

extension SCKYCTermsAndConditionsPresenter: SCKYCTermsAndConditionsViewOutput {
    func didLoad(view: SCKYCTermsAndConditionsViewInput) {
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

// MARK: - SCKYCTermsAndConditionsInteractorOutput

extension SCKYCTermsAndConditionsPresenter: SCKYCTermsAndConditionsInteractorOutput {}

// MARK: - Localizable

extension SCKYCTermsAndConditionsPresenter: Localizable {
    func applyLocalization() {}
}

extension SCKYCTermsAndConditionsPresenter: SCKYCTermsAndConditionsModuleInput {}
