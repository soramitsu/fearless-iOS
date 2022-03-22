import Foundation

final class OnboardingMainPresenter {
    weak var view: OnboardingMainViewProtocol?
    var wireframe: OnboardingMainWireframeProtocol!
    var interactor: OnboardingMainInteractorInputProtocol!
    let appVersionObserver: AppVersionObserver

    let legalData: LegalData

    let locale: Locale

    init(legalData: LegalData, locale: Locale, appVersionObserver: AppVersionObserver) {
        self.legalData = legalData
        self.locale = locale
        self.appVersionObserver = appVersionObserver
    }
}

extension OnboardingMainPresenter: OnboardingMainPresenterProtocol {
    func setup() {
        interactor.setup()

        appVersionObserver.checkVersion(from: view, callback: nil)
    }

    func activateTerms() {
        if let view = view {
            wireframe.showWeb(
                url: legalData.termsUrl,
                from: view,
                style: .modal
            )
        }
    }

    func activatePrivacy() {
        if let view = view {
            wireframe.showWeb(
                url: legalData.privacyPolicyUrl,
                from: view,
                style: .modal
            )
        }
    }

    func activateSignup() {
        wireframe.showSignup(from: view)
    }

    func activateAccountRestore() {
        wireframe.showAccountRestore(from: view)
    }
}

extension OnboardingMainPresenter: OnboardingMainInteractorOutputProtocol {
    func didSuggestKeystoreImport() {
        wireframe.showKeystoreImport(from: view)
    }
}
