import Foundation

protocol OnboardingMainViewProtocol: ControllerBackedProtocol {}

protocol OnboardingMainPresenterProtocol: class {
    func activateSignup()
    func activateAccountRestore()
    func activateTerms()
    func activatePrivacy()
}

protocol OnboardingMainWireframeProtocol: WebPresentable, ErrorPresentable, AlertPresentable {
    func showSignup(from view: OnboardingMainViewProtocol?)
    func showAccountRestore(from view: OnboardingMainViewProtocol?)
}

protocol OnboardingMainViewFactoryProtocol {
    static func createView() -> OnboardingMainViewProtocol?
}
