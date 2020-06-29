import Foundation

protocol OnboardingMainViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {}

protocol OnboardingMainPresenterProtocol: class {
    func activateSignup()
    func activateAccountRestore()
    func activateTerms()
    func activatePrivacy()
}

protocol OnboardingMainInputInteractorProtocol: class {
    func signup()
}

protocol OnboardingMainOutputInteractorProtocol: class {
    func didStartSignup()
    func didCompleteSignup()
    func didReceiveSignup(error: Error)
}

protocol OnboardingMainWireframeProtocol: WebPresentable, ErrorPresentable, AlertPresentable {
    func showSignup(from view: OnboardingMainViewProtocol?)
    func showAccountRestore(from view: OnboardingMainViewProtocol?)
}

protocol OnboardingMainViewFactoryProtocol {
    static func createView() -> OnboardingMainViewProtocol?
}
