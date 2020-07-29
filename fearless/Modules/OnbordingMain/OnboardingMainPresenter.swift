import Foundation

final class OnboardingMainPresenter {
    weak var view: OnboardingMainViewProtocol?
    var wireframe: OnboardingMainWireframeProtocol!

    let legalData: LegalData

    let locale: Locale

    init(legalData: LegalData, locale: Locale) {
        self.legalData = legalData
        self.locale = locale
    }
}

extension OnboardingMainPresenter: OnboardingMainPresenterProtocol {
    func activateTerms() {
        if let view = view {
            wireframe.showWeb(url: legalData.termsUrl,
                              from: view,
                              style: .modal)
        }
    }

    func activatePrivacy() {
        if let view = view {
            wireframe.showWeb(url: legalData.privacyPolicyUrl,
                              from: view,
                              style: .modal)
        }
    }

    func activateSignup() {
        wireframe.showSignup(from: view)
    }

    func activateAccountRestore() {
        wireframe.showAccountRestore(from: view)
    }
}
