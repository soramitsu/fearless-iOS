import Foundation

final class OnboardingMainPresenter {
    weak var view: OnboardingMainViewProtocol?
    private let wireframe: OnboardingMainWireframeProtocol
    private let interactor: OnboardingMainInteractorInputProtocol
    private let appVersionObserver: AppVersionObserver

    private let legalData: LegalData
    private let locale: Locale

    init(
        legalData: LegalData,
        locale: Locale,
        appVersionObserver: AppVersionObserver,
        wireframe: OnboardingMainWireframeProtocol,
        interactor: OnboardingMainInteractorInputProtocol
    ) {
        self.legalData = legalData
        self.locale = locale
        self.appVersionObserver = appVersionObserver
        self.wireframe = wireframe
        self.interactor = interactor
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
