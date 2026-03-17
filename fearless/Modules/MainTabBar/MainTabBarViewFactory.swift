import UIKit
import SoraFoundation
import SoraKeystore
import RobinHood
import SSFUtils

final class MainTabBarViewFactory: MainTabBarViewFactoryProtocol {
    struct Dependencies {
        var walletSettings: SelectedWalletSettings
        var localizationManager: LocalizationManagerProtocol
        var walletConnectService: WalletConnectService
        var reachability: ReachabilityManager?
        var eventCenter: EventCenterProtocol
        var operationManager: OperationManagerProtocol
        var serviceCoordinatorBuilder: (MetaAccountModel, WalletConnectService) -> ServiceCoordinatorProtocol
        var keystoreImportServiceProvider: () -> KeystoreImportServiceProtocol?
        var applicationHandlerBuilder: () -> ApplicationHandler

        static var live: Dependencies {
            Dependencies(
                walletSettings: SelectedWalletSettings.shared,
                localizationManager: LocalizationManager.shared,
                walletConnectService: WalletConnectServiceImpl.shared,
                reachability: ReachabilityManager.shared,
                eventCenter: EventCenter.shared,
                operationManager: OperationManagerFacade.sharedManager,
                serviceCoordinatorBuilder: { metaAccount, walletConnect in
                    ServiceCoordinator.createDefault(with: metaAccount, walletConnect: walletConnect)
                },
                keystoreImportServiceProvider: {
                    URLHandlingService.shared.findService()
                },
                applicationHandlerBuilder: {
                    ApplicationHandler()
                }
            )
        }
    }

    static let walletIndex: Int = 0
    static let crowdloanIndex: Int = 1
    static let stakingIndex: Int = 3

    static func createView(
        presentingWindow: ApplicationStatusPresentable? = nil,
        dependencies: Dependencies = .live
    ) -> MainTabBarViewProtocol? {
        let presentableWindow = presentingWindow ?? SceneWindowFinder.statusPresentableWindow()
        guard
            let window = presentableWindow,
            let wallet = dependencies.walletSettings.value,
            let keystoreImportService: KeystoreImportServiceProtocol = dependencies.keystoreImportServiceProvider()
        else {
            Logger.shared.error("Can't find required keystore import service")
            return nil
        }

        let localizationManager = dependencies.localizationManager

        let walletConnect = dependencies.walletConnectService
        let serviceCoordinator = dependencies.serviceCoordinatorBuilder(wallet, walletConnect)

        let wireframe = MainTabBarWireframe()

        let appVersionObserver = AppVersionObserver(
            operationManager: dependencies.operationManager,
            currentAppVersion: AppVersion.stringValue,
            wireframe: wireframe,
            locale: localizationManager.selectedLocale
        )

        let interactor = MainTabBarInteractor(
            eventCenter: dependencies.eventCenter,
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
            applicationHandler: dependencies.applicationHandlerBuilder(),
            networkStatusPresenter: networkStatusPresenter,
            reachability: dependencies.reachability,
            walletConnectCoordinator: WalletConnectCoordinator(),
            localizationManager: localizationManager
        )

        let viewControllers = createViewControllers(stakingModuleOutput: presenter, walletConnect: walletConnect, wallet: wallet)
        let view = MainTabBarViewController(
            viewControllers: viewControllers,
            presenter: presenter,
            localizationManager: localizationManager
        )

        return view
    }

    static func createViewControllers(
        stakingModuleOutput: StakingMainModuleOutput?,
        walletConnect: WalletConnectService,
        wallet: MetaAccountModel
    ) -> [UIViewController] {
        var viewControllers: [UIViewController?] = []
        let walletController = createWalletController(walletConnect: walletConnect, wallet: wallet)
        viewControllers.append(walletController)

        let crowdloanController = createCrowdloanController(wallet: wallet)
        viewControllers.append(crowdloanController)

        let polkaswapControoller = createPolkaswapController(wallet: wallet)
        viewControllers.append(polkaswapControoller)

        let stakingController = createStakingController(moduleOutput: stakingModuleOutput)
        viewControllers.append(stakingController)

        let settingsController = createProfileController()
        viewControllers.append(settingsController)

        return viewControllers.compactMap { $0 }
    }

    static func reloadCrowdloanView(on view: MainTabBarViewProtocol, wallet: MetaAccountModel? = SelectedWalletSettings.shared.value) -> UIViewController? {
        guard let crowdloanController = createCrowdloanController(wallet: wallet) else {
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

    static func createWalletController(
        walletConnect: WalletConnectService,
        wallet: MetaAccountModel
    ) -> UIViewController? {
        guard let viewController = WalletMainContainerAssembly
            .configureModule(wallet: wallet, walletConnect: walletConnect)?.view.controller
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

    static func createCrowdloanController(wallet: MetaAccountModel? = SelectedWalletSettings.shared.value) -> UIViewController? {
        let crowdloanState = CrowdloanSharedState()
        crowdloanState.settings.setup()

        guard let selectedMetaAccount = wallet,
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

    static func createPolkaswapController(wallet _: MetaAccountModel) -> UIViewController? {
        let fakeSwapViewController = UIViewController()
        fakeSwapViewController.tabBarItem.isEnabled = false
        return fakeSwapViewController
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
