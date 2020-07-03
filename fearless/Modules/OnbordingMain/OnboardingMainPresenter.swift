import Foundation

final class OnboardingMainPresenter {
    weak var view: OnboardingMainViewProtocol?
    var interactor: OnboardingMainInputInteractorProtocol!
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
        interactor.signup()
    }

    func activateAccountRestore() {
        wireframe.showAccountRestore(from: view)
    }
}

extension OnboardingMainPresenter: OnboardingMainOutputInteractorProtocol {
    func didStartSignup() {
        view?.didStartLoading()
    }

    func didCompleteSignup() {
        view?.didStopLoading()
        wireframe.showSignup(from: view)
    }

    func didReceiveSignup(error: Error) {
        view?.didStopLoading()
        _ = wireframe.present(error: error, from: view, locale: locale)
    }
}
