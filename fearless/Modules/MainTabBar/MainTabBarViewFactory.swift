import UIKit
import SoraFoundation
import SoraKeystore
import CommonWallet

final class MainTabBarViewFactory: MainTabBarViewFactoryProtocol {
    static let walletIndex: Int = 0

	static func createView() -> MainTabBarViewProtocol? {

        guard let keystoreImportService: KeystoreImportServiceProtocol = URLHandlingService.shared
                .findService() else {
            Logger.shared.error("Can't find required keystore import service")
            return nil
        }

        let localizationManager = LocalizationManager.shared
        let webSocketService = WebSocketService.shared
        webSocketService.networkStatusPresenter =
            createNetworkStatusPresenter(localizationManager: localizationManager)
        let gitHubPhishingAPIService = GitHubPhishingServiceFactory().createGitHubService()

        let interactor = MainTabBarInteractor(eventCenter: EventCenter.shared,
                                              settings: SettingsManager.shared,
                                              webSocketService: webSocketService,
                                              gitHubPhishingAPIService: gitHubPhishingAPIService)
                                              runtimeService: RuntimeRegistryFacade.sharedService,
                                              keystoreImportService: keystoreImportService)

        guard
            let walletContext = try? WalletContextFactory().createContext(),
            let walletController = createWalletController(walletContext: walletContext,
                                                          localizationManager: localizationManager)
            else {
            return nil
        }

        guard let stakingController = createStakingController(for: localizationManager) else {
            return nil
        }

        guard let governanceController = createGovernanceController(for: localizationManager) else {
            return nil
        }

        guard let polkaswapController = createPolkaswapController(for: localizationManager) else {
            return nil
        }

        guard let settingsController = createProfileController(for: localizationManager) else {
            return nil
        }

        let view = MainTabBarViewController()
        view.viewControllers = [
            walletController,
            polkaswapController,
            stakingController,
            governanceController,
            settingsController
        ]

        let presenter = MainTabBarPresenter()

        let wireframe = MainTabBarWireframe(walletContext: walletContext)

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
	}

    static func reloadWalletView(on view: MainTabBarViewProtocol,
                                 wireframe: MainTabBarWireframeProtocol) {
        let localizationManager = LocalizationManager.shared

        guard
            let walletContext = try? WalletContextFactory().createContext(),
            let walletController = createWalletController(walletContext: walletContext,
                                                          localizationManager: localizationManager)
            else {
            return
        }

        wireframe.walletContext = walletContext
        view.didReplaceView(for: walletController, for: Self.walletIndex)
    }

    static func createWalletController(walletContext: CommonWalletContextProtocol,
                                       localizationManager: LocalizationManagerProtocol)
        -> UIViewController? {
        do {
            let viewController = try walletContext.createRootController()

            let localizableTitle = LocalizableResource { locale in
                R.string.localizable.tabbarWalletTitle(preferredLanguages: locale.rLanguages)
            }

            let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
            let icon = R.image.iconTabWallet()
            let normalIcon = icon?.tinted(with: R.color.colorGray()!)?
                .withRenderingMode(.alwaysOriginal)
            let selectedIcon = icon?.tinted(with: R.color.colorWhite()!)?
                .withRenderingMode(.alwaysOriginal)
            viewController.tabBarItem = createTabBarItem(title: currentTitle,
                                                         normalImage: normalIcon,
                                                         selectedImage: selectedIcon)

            localizationManager.addObserver(with: viewController) { [weak viewController] (_, _) in
                let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
                viewController?.tabBarItem.title = currentTitle
            }

            return viewController
        } catch {
            Logger.shared.error("Can't create wallet: \(error)")

            return nil
        }
    }

    static func createStakingController(for localizationManager: LocalizationManagerProtocol)
        -> UIViewController? {
        guard let viewController = CommingSoonViewFactory.createView()?.controller else {
            return nil
        }

        let localizableTitle = LocalizableResource { locale in
            R.string.localizable.tabbarStakingTitle(preferredLanguages: locale.rLanguages)
        }

        let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
        let icon = R.image.iconTabStaking()
        let normalIcon = icon?.tinted(with: R.color.colorGray()!)?
            .withRenderingMode(.alwaysOriginal)
        let selectedIcon = icon?.tinted(with: R.color.colorWhite()!)?
            .withRenderingMode(.alwaysOriginal)
        viewController.tabBarItem = createTabBarItem(title: currentTitle,
                                                     normalImage: normalIcon,
                                                     selectedImage: selectedIcon)

        localizationManager.addObserver(with: viewController) { [weak viewController] (_, _) in
            let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
            viewController?.tabBarItem.title = currentTitle
        }

        return viewController
    }

    static func createGovernanceController(for localizationManager: LocalizationManagerProtocol)
        -> UIViewController? {
        guard let viewController = CommingSoonViewFactory.createView()?.controller else {
            return nil
        }

        let localizableTitle = LocalizableResource { locale in
            R.string.localizable.tabbarGovernanceTitle(preferredLanguages: locale.rLanguages)
        }

        let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
        let icon = R.image.iconTabGov()
        let normalIcon = icon?.tinted(with: R.color.colorGray()!)?
            .withRenderingMode(.alwaysOriginal)
        let selectedIcon = normalIcon?.tinted(with: R.color.colorWhite()!)?
            .withRenderingMode(.alwaysOriginal)
        viewController.tabBarItem = createTabBarItem(title: currentTitle,
                                                     normalImage: normalIcon,
                                                     selectedImage: selectedIcon)

        localizationManager.addObserver(with: viewController) { [weak viewController] (_, _) in
            let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
            viewController?.tabBarItem.title = currentTitle
        }

        return viewController
    }

    static func createPolkaswapController(for localizationManager: LocalizationManagerProtocol)
        -> UIViewController? {

        guard let viewController = CommingSoonViewFactory.createView()?.controller else {
            return nil
        }

        let localizableTitle = LocalizableResource { locale in
            R.string.localizable.tabbarPolkaswapTitle(preferredLanguages: locale.rLanguages)
        }

        let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
        let icon = R.image.iconTabPolkaswap()
        let normalIcon = icon?.tinted(with: R.color.colorGray()!)?
            .withRenderingMode(.alwaysOriginal)
        let selectedIcon = icon?.tinted(with: R.color.colorWhite()!)?
            .withRenderingMode(.alwaysOriginal)
        viewController.tabBarItem = createTabBarItem(title: currentTitle,
                                                     normalImage: normalIcon,
                                                     selectedImage: selectedIcon)

        localizationManager.addObserver(with: viewController) { [weak viewController] (_, _) in
            let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
            viewController?.tabBarItem.title = currentTitle
        }

        return viewController
    }

    static func createProfileController(for localizationManager: LocalizationManagerProtocol)
        -> UIViewController? {
        guard let settingsView = ProfileViewFactory.createView() else {
            return nil
        }

        let navigationController = FearlessNavigationController(rootViewController: settingsView.controller)

        let localizableTitle = LocalizableResource { locale in
            R.string.localizable.tabbarSettingsTitle(preferredLanguages: locale.rLanguages)
        }

        let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
        let icon = R.image.iconTabSettings()
        let normalIcon = icon?.tinted(with: R.color.colorGray()!)?
            .withRenderingMode(.alwaysOriginal)
        let selectedIcon = icon?.tinted(with: R.color.colorWhite()!)?
            .withRenderingMode(.alwaysOriginal)
        navigationController.tabBarItem = createTabBarItem(title: currentTitle,
                                                           normalImage: normalIcon,
                                                           selectedImage: selectedIcon)

        localizationManager.addObserver(with: navigationController) { [weak navigationController] (_, _) in
            let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
            navigationController?.tabBarItem.title = currentTitle
        }

        return navigationController
    }

    static func createTabBarItem(title: String,
                                 normalImage: UIImage?,
                                 selectedImage: UIImage?) -> UITabBarItem {

        let tabBarItem = UITabBarItem(title: title,
                                      image: normalImage,
                                      selectedImage: selectedImage)

        // Style is set here for compatibility reasons for iOS 12.x and less.
        // For iOS 13 styling see MainTabBarViewController's 'configure' method.

        if #available(iOS 13.0, *) {
            return tabBarItem
        }

        let normalAttributes = [NSAttributedString.Key.foregroundColor: R.color.colorGray()!]
        let selectedAttributes = [NSAttributedString.Key.foregroundColor: R.color.colorWhite()!]

        tabBarItem.setTitleTextAttributes(normalAttributes, for: .normal)
        tabBarItem.setTitleTextAttributes(selectedAttributes, for: .selected)

        return tabBarItem
    }

    static func createNetworkStatusPresenter(localizationManager: LocalizationManagerProtocol)
        -> NetworkAvailabilityLayerInteractorOutputProtocol? {
        guard let window = UIApplication.shared.keyWindow as? ApplicationStatusPresentable else {
            return nil
        }

        let prenseter = NetworkAvailabilityLayerPresenter()
        prenseter.localizationManager = localizationManager
        prenseter.view = window

        return prenseter
    }
}
