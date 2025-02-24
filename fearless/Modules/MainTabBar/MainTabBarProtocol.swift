import UIKit
import WalletConnectSign
import SSFModels

protocol MainTabBarViewProtocol: ControllerBackedProtocol {
    func didReplaceView(for newView: UIViewController, for index: Int)
}

protocol MainTabBarPresenterProtocol: AnyObject {
    func didLoad(view: MainTabBarViewProtocol)
    func presentPolkaswap()
}

protocol MainTabBarInteractorInputProtocol: AnyObject {
    func setup(with output: MainTabBarInteractorOutputProtocol)
}

protocol MainTabBarInteractorOutputProtocol: AnyObject {
    func didRequestImportAccount()
}

protocol MainTabBarWireframeProtocol: SheetAlertPresentable, AuthorizationAccessible, WarningPresentable, AppUpdatePresentable, PresentDismissable {
    func presentAccountImport(on view: MainTabBarViewProtocol?)
    func replaceStaking(on view: MainTabBarViewProtocol?, type: AssetSelectionStakingType, moduleOutput: StakingMainModuleOutput?)
    func presentSwapAssetSelection(
        on view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        onSelectHandler: ((ChainAsset?) -> Void)?
    )
    func showPolkaswap(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    )
    func presentCrossChainFlow(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    )
}

protocol MainTabBarViewFactoryProtocol: AnyObject {
    static func createView() -> MainTabBarViewProtocol?
}
