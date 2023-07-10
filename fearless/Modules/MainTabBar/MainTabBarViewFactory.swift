import UIKit
import SoraFoundation
import SoraKeystore
import CommonWallet
import SSFUtils

final class MainTabBarViewFactory: MainTabBarViewFactoryProtocol {
    static let walletIndex: Int = 0
    static let crowdloanIndex: Int = 1
    static let stakingIndex: Int = 2

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
            keystoreImportService: keystoreImportService
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
        view.viewControllers = createViewControllers(stakingModuleOutput: presenter)

        return view
    }

    static func createViewControllers(stakingModuleOutput: StakingMainModuleOutput?) -> [UIViewController]? {
        var viewControllers: [UIViewController] = []
        if let walletController = createWalletController() {
            viewControllers.append(walletController)
        }

        if let crowdloanController = createCrowdloanController() {
            viewControllers.append(crowdloanController)
        }

        let stakingController = createStakingController(moduleOutput: stakingModuleOutput)
        viewControllers.append(stakingController)

        if let settingsController = createProfileController() {
            viewControllers.append(settingsController)
        }

        return viewControllers
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

    @discardableResult
    static func reloadStakingView(
        on view: MainTabBarViewProtocol,
        stakingType: AssetSelectionStakingType,
        moduleOutput: StakingMainModuleOutput?
    ) -> UIViewController? {
        switch stakingType {
        case .normal:
            let stakingViewController = createStakingController(moduleOutput: moduleOutput)
            view.didReplaceView(for: stakingViewController, for: Self.stakingIndex)

            return stakingViewController
        case .pool:
            let stakingViewController = createPoolStakingController(moduleOutput: moduleOutput)
            view.didReplaceView(for: stakingViewController, for: Self.stakingIndex)

            return stakingViewController
        }
    }

    static func createWalletController() -> UIViewController? {
        guard let wallet = SelectedWalletSettings.shared.value,
              let viewController = WalletMainContainerAssembly.configureModule(wallet: wallet)?.view.controller
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

    static func createStakingController(
        moduleOutput: StakingMainModuleOutput?
    ) -> UIViewController {
        let viewController = StakingMainViewFactory.createView(moduleOutput: moduleOutput)?.controller ?? UIViewController()

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

    static func createPoolStakingController(
        moduleOutput: StakingMainModuleOutput?
    ) -> UIViewController {
        let module = StakingPoolMainAssembly.configureModule(moduleOutput: moduleOutput)
        guard let viewController = module?.view.controller else {
            return UIViewController()
        }

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
