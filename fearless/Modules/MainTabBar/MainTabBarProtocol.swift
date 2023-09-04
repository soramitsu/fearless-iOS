import UIKit
import WalletConnectSign
import CommonWallet
// import WalletConnectSwiftV2

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
    func didReceive(proposal: Session.Proposal)
    func didReceive(request: Request, session: Session?)
}

protocol MainTabBarWireframeProtocol: SheetAlertPresentable, AuthorizationAccessible, WarningPresentable, AppUpdatePresentable, PresentDismissable {
    func showNewCrowdloan(on view: MainTabBarViewProtocol?) -> UIViewController?
    func presentAccountImport(on view: MainTabBarViewProtocol?)
    func replaceStaking(on view: MainTabBarViewProtocol?, type: AssetSelectionStakingType, moduleOutput: StakingMainModuleOutput?)
    func showSession(
        proposal: Session.Proposal,
        view: ControllerBackedProtocol?
    )
    func showSign(
        request: Request,
        session: Session?,
        view: ControllerBackedProtocol?
    )
}

protocol MainTabBarViewFactoryProtocol: AnyObject {
    static func createView() -> MainTabBarViewProtocol?

    static func reloadCrowdloanView(
        on view: MainTabBarViewProtocol
    ) -> UIViewController?
}
