import UIKit
import CommonWallet

protocol MainTabBarViewProtocol: ControllerBackedProtocol {
    func didReplaceView(for newView: UIViewController, for index: Int)
    func presentFailedMemoView()
}

protocol MainTabBarPresenterProtocol: AnyObject {
    func setup()
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
    func showNewWalletView(on view: MainTabBarViewProtocol?)

    func showNewCrowdloan(on view: MainTabBarViewProtocol?) -> UIViewController?

    func presentAccountImport(on view: MainTabBarViewProtocol?)
}

protocol MainTabBarViewFactoryProtocol: AnyObject {
    static func createView() -> MainTabBarViewProtocol?
    static func reloadWalletView(
        on view: MainTabBarViewProtocol,
        wireframe: MainTabBarWireframeProtocol
    )

    static func reloadCrowdloanView(
        on view: MainTabBarViewProtocol
    ) -> UIViewController?
}
