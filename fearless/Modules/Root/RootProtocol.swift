import UIKit

protocol RootViewProtocol: ControllerBackedProtocol {
    func didReceive(state: RootViewState)
}

protocol RootPresenterProtocol: AnyObject {
    func loadOnLaunch()
    func reload()
    func didTapRetryButton(from state: RootViewState)
}

protocol RootWireframeProtocol: AnyObject {
    func showSplash(splashView: ControllerBackedProtocol?, on window: UIWindow)
    func showLocalAuthentication(on window: UIWindow)
    func showOnboarding(on window: UIWindow)
    func showPincodeSetup(on window: UIWindow)
    func showBroken(on window: UIWindow)
    func showVersionUnsupported(from view: ControllerBackedProtocol?, locale: Locale)
}

protocol RootInteractorInputProtocol: AnyObject {
    func checkAppVersion()
    func setup(runMigrations: Bool)
}

protocol RootInteractorOutputProtocol: AnyObject {
    func didDecideOnboarding()
    func didDecideLocalAuthentication()
    func didDecidePincodeSetup()
    func didDecideBroken()
    func didDecideVersionUnsupported()
    func didFailCheckAppVersion()
}

protocol RootPresenterFactoryProtocol: AnyObject {
    static func createPresenter(with window: UIWindow) -> RootPresenterProtocol
}
