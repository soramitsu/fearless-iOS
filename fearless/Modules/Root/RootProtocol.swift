import UIKit

protocol RootPresenterProtocol: AnyObject {
    func loadOnLaunch()
    func reload()
}

protocol RootWireframeProtocol: AnyObject {
    func showLocalAuthentication(on view: UIWindow)
    func showOnboarding(on view: UIWindow)
    func showPincodeSetup(on view: UIWindow)
    func showBroken(on view: UIWindow)
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
}

protocol RootPresenterFactoryProtocol: AnyObject {
    static func createPresenter(with view: UIWindow) -> RootPresenterProtocol
}
