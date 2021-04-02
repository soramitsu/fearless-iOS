import Foundation

protocol OnboardingMainViewProtocol: ControllerBackedProtocol {}

protocol OnboardingMainPresenterProtocol: AnyObject {
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

protocol OnboardingMainInteractorInputProtocol: AnyObject {
    func setup()
}

protocol OnboardingMainInteractorOutputProtocol: AnyObject {
    func didSuggestKeystoreImport()
}

protocol OnboardingMainViewFactoryProtocol {
    static func createViewForOnboarding() -> OnboardingMainViewProtocol?
    static func createViewForAdding() -> OnboardingMainViewProtocol?
    static func createViewForConnection(item: ConnectionItem) -> OnboardingMainViewProtocol?
    static func createViewForAccountSwitch() -> OnboardingMainViewProtocol?
}
