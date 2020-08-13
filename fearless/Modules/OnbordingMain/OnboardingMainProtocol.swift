import Foundation

protocol OnboardingMainViewProtocol: ControllerBackedProtocol {}

protocol OnboardingMainPresenterProtocol: class {
    func setup()
    func activateSignup()
    func activateAccountRestore()
    func activateTerms()
    func activatePrivacy()
}

protocol OnboardingMainWireframeProtocol: WebPresentable, ErrorPresentable, AlertPresentable {
    func showSignup(from view: OnboardingMainViewProtocol?)
    func showAccountRestore(from view: OnboardingMainViewProtocol?)
    func showKeystoreImport(from view: OnboardingMainViewProtocol?)
}

protocol OnboardingMainInteractorInputProtocol: class {
    func setup()
}

protocol OnboardingMainInteractorOutputProtocol: class {
    func didSuggestKeystoreImport()
}

protocol OnboardingMainViewFactoryProtocol {
    static func createView() -> OnboardingMainViewProtocol?
}
