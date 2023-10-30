import UIKit
import WalletConnectSign
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
    func didRequestImportAccount()
}

protocol MainTabBarWireframeProtocol: SheetAlertPresentable, AuthorizationAccessible, WarningPresentable, AppUpdatePresentable, PresentDismissable {
    func showNewCrowdloan(on view: MainTabBarViewProtocol?) -> UIViewController?
    func presentAccountImport(on view: MainTabBarViewProtocol?)
    func replaceStaking(on view: MainTabBarViewProtocol?, type: AssetSelectionStakingType, moduleOutput: StakingMainModuleOutput?)
}

protocol MainTabBarViewFactoryProtocol: AnyObject {
    static func createView() -> MainTabBarViewProtocol?

    static func reloadCrowdloanView(
        on view: MainTabBarViewProtocol
    ) -> UIViewController?
}
