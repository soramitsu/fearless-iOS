import UIKit
import SoraFoundation
import SoraKeystore
import CommonWallet
import FearlessUtils

final class MainTabBarViewFactory: MainTabBarViewFactoryProtocol {
    static let walletIndex: Int = 0
    static let crowdloanIndex: Int = 1

    static func createView() -> MainTabBarViewProtocol? {
        guard
            let window = UIApplication.shared.keyWindow as? ApplicationStatusPresentable,
            let selectedMetaAccount = SelectedWalletSettings.shared.value,
            let keystoreImportService: KeystoreImportServiceProtocol = URLHandlingService.shared
            .findService()
        else {
            Logger.shared.error("Can't find required keystore import service")
            return nil
        }

        let localizationManager = LocalizationManager.shared

        let serviceCoordinator = ServiceCoordinator.createDefault(
            with: selectedMetaAccount
        )

        let wireframe = MainTabBarWireframe()

        let appVersionObserver = AppVersionObserver(
            operationManager: OperationManagerFacade.sharedManager,
            currentAppVersion: AppVersion.stringValue,
            wireframe: wireframe,
            locale: localizationManager.selectedLocale
        )

        let interactor = MainTabBarInteractor(
            eventCenter: EventCenter.shared,
            serviceCoordinator: serviceCoordinator,
            keystoreImportService: keystoreImportService,
            applicationHandler: ApplicationHandler()
        )

        let networkStatusPresenter = NetworkAvailabilityLayerPresenter(
            view: window,
            localizationManager: localizationManager
        )

        let presenter = MainTabBarPresenter(
            wireframe: wireframe,
            interactor: interactor,
            appVersionObserver: appVersionObserver,
            applicationHandler: ApplicationHandler(),
            networkStatusPresenter: networkStatusPresenter,
            reachability: ReachabilityManager.shared,
            localizationManager: localizationManager
        )

        let view = MainTabBarViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )
        view.viewControllers = createViewControllers()

        return view
    }

    static func createViewControllers() -> [UIViewController]? {
        guard
            let walletController = createWalletController(),
            let stakingController = createStakingController(),
            let crowdloanController = createCrowdloanController(),
            let settingsController = createProfileController()
        else {
            return nil
        }

        return [
            walletController,
            crowdloanController,
            stakingController,
            settingsController
        ]
    }

    static func reloadWalletView(
        on view: MainTabBarViewProtocol,
        wireframe _: MainTabBarWireframeProtocol
    ) {
        guard let walletController = createWalletController() else {
            return
        }

        view.didReplaceView(for: walletController, for: Self.walletIndex)
    }

    static func reloadCrowdloanView(on view: MainTabBarViewProtocol) -> UIViewController? {
        guard let crowdloanController = createCrowdloanController() else {
            return nil
        }

        view.didReplaceView(for: crowdloanController, for: Self.crowdloanIndex)

        return crowdloanController
    }

    static func createWalletController() -> UIViewController? {
        guard let selectedMetaAccount = SelectedWalletSettings.shared.value,
              let viewController = WalletMainContainerAssembly.configureModule(selectedMetaAccount: selectedMetaAccount)?.view.controller
        else {
            return nil
        }

        let icon = R.image.iconTabWallet()
        let normalIcon = icon?.tinted(with: R.color.colorGray()!)?
            .withRenderingMode(.alwaysOriginal)
        let selectedIcon = icon?.tinted(with: R.color.colorWhite()!)?
            .withRenderingMode(.alwaysOriginal)
        viewController.tabBarItem = createTabBarItem(
            normalImage: normalIcon,
            selectedImage: selectedIcon
        )

        let navigationController = FearlessNavigationController(rootViewController: viewController)

        return navigationController
    }

    static func createStakingController() -> UIViewController? {
        // TODO: Remove when staking is fixed
        let viewController = StakingMainViewFactory.createView()?.controller ?? UIViewController()

        let icon = R.image.iconTabStaking()
        let normalIcon = icon?.tinted(with: R.color.colorGray()!)?
            .withRenderingMode(.alwaysOriginal)
        let selectedIcon = icon?.tinted(with: R.color.colorWhite()!)?
            .withRenderingMode(.alwaysOriginal)
        viewController.tabBarItem = createTabBarItem(
            normalImage: normalIcon,
            selectedImage: selectedIcon
        )

        let navigationController = FearlessNavigationController(rootViewController: viewController)

        return navigationController
    }

    static func createProfileController() -> UIViewController? {
        // TODO: Remove when settings fixed
        let viewController = ProfileViewFactory.createView()?.controller ?? UIViewController()
        let navigationController = FearlessNavigationController(rootViewController: viewController)

        let icon = R.image.iconTabSettings()
        let normalIcon = icon?.tinted(with: R.color.colorGray()!)?
            .withRenderingMode(.alwaysOriginal)
        let selectedIcon = icon?.tinted(with: R.color.colorWhite()!)?
            .withRenderingMode(.alwaysOriginal)
        navigationController.tabBarItem = createTabBarItem(
            normalImage: normalIcon,
            selectedImage: selectedIcon
        )

        return navigationController
    }

    static func createCrowdloanController() -> UIViewController? {
        let crowdloanState = CrowdloanSharedState()
        crowdloanState.settings.setup()

        guard let selectedMetaAccount = SelectedWalletSettings.shared.value,
              let crowloanView = CrowdloanListViewFactory.createView(
                  with: crowdloanState,
                  selectedMetaAccount: selectedMetaAccount
              )
        else {
            return nil
        }

        let navigationController = FearlessNavigationController(rootViewController: crowloanView.controller)

        let icon = R.image.iconTabCrowloan()
        let normalIcon = icon?.tinted(with: R.color.colorGray()!)?
            .withRenderingMode(.alwaysOriginal)
        let selectedIcon = icon?.tinted(with: R.color.colorWhite()!)?
            .withRenderingMode(.alwaysOriginal)
        navigationController.tabBarItem = createTabBarItem(
            normalImage: normalIcon,
            selectedImage: selectedIcon
        )

        return navigationController
    }

    static func createTabBarItem(
        normalImage: UIImage?,
        selectedImage: UIImage?
    ) -> UITabBarItem {
        let tabBarItem = UITabBarItem(
            title: nil,
            image: normalImage,
            selectedImage: selectedImage
        )

        tabBarItem.imageInsets = UIEdgeInsets(top: 10, left: 0, bottom: -10, right: 0)
        tabBarItem.title = nil

        return tabBarItem
    }
}
