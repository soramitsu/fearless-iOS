import UIKit
import CommonWallet

protocol MainTabBarViewProtocol: ControllerBackedProtocol {
    func didReplaceView(for newView: UIViewController, for index: Int)
    func presentFailedMemoView()
}

protocol MainTabBarPresenterProtocol: AnyObject {
    func didLoad(view: MainTabBarViewProtocol)
}

protocol MainTabBarInteractorInputProtocol: AnyObject {
    func setup(with output: MainTabBarInteractorOutputProtocol)
}

protocol MainTabBarInteractorOutputProtocol: AnyObject {
    func didReloadSelectedAccount()
    func didReloadSelectedNetwork()
    func didRequestImportAccount()
    func handleLongInactivity()
}

protocol MainTabBarWireframeProtocol: SheetAlertPresentable, AuthorizationAccessible, WarningPresentable, AppUpdatePresentable, PresentDismissable {
    func showNewWalletView(on view: MainTabBarViewProtocol?)
    func showNewCrowdloan(on view: MainTabBarViewProtocol?) -> UIViewController?
    func presentAccountImport(on view: MainTabBarViewProtocol?)
    func logout(from _: MainTabBarViewProtocol?)
    func replaceStaking(on view: MainTabBarViewProtocol?, type: AssetSelectionStakingType, moduleOutput: StakingMainModuleOutput?)
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
