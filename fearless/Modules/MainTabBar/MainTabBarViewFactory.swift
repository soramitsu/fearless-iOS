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

        let viewControllers = createViewControllers(walletConnect: walletConnect, wallet: wallet)
        let view = MainTabBarViewController(
            viewControllers: viewControllers,
            presenter: presenter,
            localizationManager: localizationManager
        )

        return view
    }

    static func createViewControllers(
        walletConnect: WalletConnectService,
        wallet: MetaAccountModel
    ) -> [UIViewController] {
        [
            createPortfolioController(walletConnect: walletConnect, wallet: wallet),
            createDeFiController(wallet: wallet),
            createPolkaswapController(wallet: wallet),
            createCrossChainController(wallet: wallet),
            createSettingsController()
        ]
    }

    static func reloadWalletDependentViews(
        on view: MainTabBarViewProtocol,
        wallet: MetaAccountModel,
        walletConnect: WalletConnectService = WalletConnectServiceImpl.shared
    ) {
        let replacements: [(MainTabBarDestination, UIViewController)] = [
            (.portfolio, createPortfolioController(walletConnect: walletConnect, wallet: wallet)),
            (.defi, createDeFiController(wallet: wallet)),
            (.polkaswap, createPolkaswapController(wallet: wallet)),
            (.crossChain, createCrossChainController(wallet: wallet))
        ]

        replacements.forEach { destination, controller in
            view.didReplaceView(for: controller, for: destination.rawValue)
        }
    }

    static func createPortfolioController(
        walletConnect: WalletConnectService,
        wallet: MetaAccountModel
    ) -> UIViewController {
        let viewController = WalletMainContainerAssembly
            .configureModule(wallet: wallet, walletConnect: walletConnect)?.view.controller ??
            FeatureUnavailableViewController(
                title: MainTabBarDestination.portfolio.title,
                message: "Portfolio data is unavailable while wallet services are starting.",
                icon: MainTabBarDestination.portfolio.image
            )

        return navigationController(
            root: viewController,
            destination: .portfolio
        )
    }

    static func createDeFiController(
        wallet: MetaAccountModel
    ) -> UIViewController {
        navigationController(
            root: DeFiHubViewController(wallet: wallet),
            destination: .defi
        )
    }

    static func createPolkaswapController(
        wallet: MetaAccountModel
    ) -> UIViewController {
        let viewController = PolkaswapAdjustmentAssembly
            .configureModule(chainAsset: nil, wallet: wallet)?.view.controller ??
            FeatureUnavailableViewController(
                title: MainTabBarDestination.polkaswap.title,
                message: "Add a SORA account and connect to the SORA network to use Polkaswap.",
                icon: R.image.polkaswapPinkButton()
            )

        return navigationController(
            root: viewController,
            destination: .polkaswap
        )
    }

    static func createCrossChainController(
        wallet: MetaAccountModel
    ) -> UIViewController {
        navigationController(
            root: CrossChainRootViewController(wallet: wallet),
            destination: .crossChain
        )
    }

    static func createSettingsController() -> UIViewController {
        let viewController = ProfileViewFactory.createView()?.controller ??
            FeatureUnavailableViewController(
                title: MainTabBarDestination.settings.title,
                message: "Settings are temporarily unavailable.",
                icon: MainTabBarDestination.settings.image
            )

        return navigationController(
            root: viewController,
            destination: .settings
        )
    }

    private static func navigationController(
        root: UIViewController,
        destination: MainTabBarDestination
    ) -> UIViewController {
        let navigationController = FearlessNavigationController(rootViewController: root)
        navigationController.tabBarItem = createTabBarItem(for: destination)
        return navigationController
    }

    static func createTabBarItem(for destination: MainTabBarDestination) -> UITabBarItem {
        let icon = destination.image
        let normalIcon = R.color.colorGray().flatMap { color in
            icon?.tinted(with: color)?.withRenderingMode(.alwaysOriginal)
        }
        let selectedIcon = R.color.colorWhite().flatMap { color in
            icon?.tinted(with: color)?.withRenderingMode(.alwaysOriginal)
        }
        let tabBarItem = UITabBarItem(
            title: destination.title,
            image: normalIcon,
            selectedImage: selectedIcon
        )
        tabBarItem.accessibilityLabel = destination.title

        return tabBarItem
    }
}
