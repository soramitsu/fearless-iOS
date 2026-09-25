import UIKit
import WalletConnectSign

protocol MainTabBarViewProtocol: ControllerBackedProtocol {
    var isPolkaswapUnavailable: Bool { get }

    func didReplaceView(for newView: UIViewController, for index: Int)
    func openPolkamarkt(marketId: String)
}

protocol MainTabBarPresenterProtocol: AnyObject {
    func didLoad(view: MainTabBarViewProtocol)
}

protocol MainTabBarInteractorInputProtocol: AnyObject {
    func setup(with output: MainTabBarInteractorOutputProtocol)
}

protocol MainTabBarInteractorOutputProtocol: AnyObject {
    func didChangeSelectedAccount(_ account: MetaAccountModel)
    func didPrepareChains()
    func didRequestImportAccount()
    func didRequestPolkamarkt(marketId: String)
}

protocol MainTabBarWireframeProtocol: SheetAlertPresentable, AuthorizationAccessible, WarningPresentable, AppUpdatePresentable, PresentDismissable {
    func reloadWalletDependentViews(on view: MainTabBarViewProtocol?, wallet: MetaAccountModel)
    func reloadPolkaswapViewIfUnavailable(on view: MainTabBarViewProtocol?, wallet: MetaAccountModel)
    func presentAccountImport(on view: MainTabBarViewProtocol?)
}

protocol MainTabBarViewFactoryProtocol: AnyObject {
    static func createView(
        presentingWindow: ApplicationStatusPresentable?,
        dependencies: MainTabBarViewFactory.Dependencies
    ) -> MainTabBarViewProtocol?
}
