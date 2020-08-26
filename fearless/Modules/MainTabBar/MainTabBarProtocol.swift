import UIKit

protocol MainTabBarViewProtocol: ControllerBackedProtocol {
    func didReplaceView(for newView: UIViewController, for index: Int)
}

protocol MainTabBarPresenterProtocol: class {
    func setup()
    func viewDidAppear()
}

protocol MainTabBarInteractorInputProtocol: class {
    func setup()
}

protocol MainTabBarInteractorOutputProtocol: class {
    func didReloadSelectedAccount()
}

protocol MainTabBarWireframeProtocol: AlertPresentable {
    func showNewWalletView(on view: MainTabBarViewProtocol?)
}

protocol MainTabBarViewFactoryProtocol: class {
    static func createView() -> MainTabBarViewProtocol?
    static func reloadWalletView(on view: MainTabBarViewProtocol)
}
