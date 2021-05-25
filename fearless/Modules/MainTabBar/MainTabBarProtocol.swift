import UIKit
import CommonWallet

protocol MainTabBarViewProtocol: ControllerBackedProtocol {
    func didReplaceView(for newView: UIViewController, for index: Int)
}

protocol MainTabBarPresenterProtocol: AnyObject {
    func setup()
    func viewDidAppear()
}

protocol MainTabBarInteractorInputProtocol: AnyObject {
    func setup()
}

protocol MainTabBarInteractorOutputProtocol: AnyObject {
    func didReloadSelectedAccount()
    func didReloadSelectedNetwork()
    func didUpdateWalletInfo()
    func didRequestImportAccount()
}

protocol MainTabBarWireframeProtocol: AlertPresentable, AuthorizationAccessible {
    var walletContext: CommonWalletContextProtocol { get set }

    func showNewWalletView(on view: MainTabBarViewProtocol?)
    func reloadWalletContent()

    func showNewCrowdloan(on view: MainTabBarViewProtocol?)

    func presentAccountImport(on view: MainTabBarViewProtocol?)
}

protocol MainTabBarViewFactoryProtocol: AnyObject {
    static func createView() -> MainTabBarViewProtocol?
    static func reloadWalletView(
        on view: MainTabBarViewProtocol,
        wireframe: MainTabBarWireframeProtocol
    )

    static func reloadCrowdloanView(on view: MainTabBarViewProtocol)
}
