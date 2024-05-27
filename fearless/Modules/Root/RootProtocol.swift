import UIKit

protocol RootViewProtocol: ControllerBackedProtocol {
    func didReceive(state: RootViewState)
}

protocol RootPresenterProtocol: AnyObject {
    func loadOnLaunch()
    func reload()
}

protocol RootWireframeProtocol: AnyObject {
    func showSplash(splashView: ControllerBackedProtocol?, on window: UIWindow)
    func showLocalAuthentication(on window: UIWindow)
    func showMain(on window: UIWindow)
    func showPincodeSetup(on window: UIWindow)
    func showBroken(on window: UIWindow)
    func showOnboarding(on window: UIWindow)
}

protocol RootInteractorInputProtocol: AnyObject {
    func setup(runMigrations: Bool)
}

protocol RootInteractorOutputProtocol: AnyObject {}

protocol RootPresenterFactoryProtocol: AnyObject {
    static func createPresenter(with window: UIWindow) -> RootPresenterProtocol
}
