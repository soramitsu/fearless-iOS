import UIKit

protocol RootPresenterProtocol: class {
    func loadOnLaunch()
}

protocol RootWireframeProtocol: class {
    func showLocalAuthentication(on view: UIWindow)
    func showOnboarding(on view: UIWindow)
    func showPincodeSetup(on view: UIWindow)
    func showBroken(on view: UIWindow)
}

protocol RootInteractorInputProtocol: class {
    func setup()
    func decideModuleSynchroniously()
}

protocol RootInteractorOutputProtocol: class {
    func didDecideOnboarding()
    func didDecideLocalAuthentication()
    func didDecidePincodeSetup()
    func didDecideBroken()
}

protocol RootPresenterFactoryProtocol: class {
    static func createPresenter(with view: UIWindow) -> RootPresenterProtocol
}
