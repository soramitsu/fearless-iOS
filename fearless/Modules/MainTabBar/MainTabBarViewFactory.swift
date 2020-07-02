import UIKit
import SoraFoundation

final class MainTabBarViewFactory: MainTabBarViewFactoryProtocol {
	static func createView() -> MainTabBarViewProtocol? {
        let localizationManager = LocalizationManager.shared

        guard let walletController = createWalletController(localizationManager: localizationManager) else {
            return nil
        }

        guard let stakingController = createStakingController(for: localizationManager) else {
            return nil
        }

        guard let governanceController = createGovernanceController(for: localizationManager) else {
            return nil
        }

        guard let extrinsicsController = createExtrinsicsController(for: localizationManager) else {
            return nil
        }

        guard let settingsController = createSettingsController(for: localizationManager) else {
            return nil
        }

        let view = MainTabBarViewController()
        view.viewControllers = [
            walletController,
            stakingController,
            governanceController,
            extrinsicsController,
            settingsController
        ]

        let presenter = MainTabBarPresenter()

        let interactor = MainTabBarInteractor()

        let wireframe = MainTabBarWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
	}

    static func createWalletController(localizationManager: LocalizationManagerProtocol) -> UIViewController? {
        do {
            let walletContext = try WalletContextFactory().createContext()
            let viewController = try walletContext.createRootController()

            let localizableTitle = LocalizableResource { locale in
                R.string.localizable.tabbarWalletTitle(preferredLanguages: locale.rLanguages)
            }

            let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
            viewController.tabBarItem = createTabBarItem(title: currentTitle,
                                                         normalImage: nil,
                                                         selectedImage: nil)

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
        let viewController = UIViewController()
        viewController.view.backgroundColor = .white

        let localizableTitle = LocalizableResource { locale in
            R.string.localizable.tabbarStakingTitle(preferredLanguages: locale.rLanguages)
        }

        let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
        viewController.tabBarItem = createTabBarItem(title: currentTitle,
                                                     normalImage: nil,
                                                     selectedImage: nil)

        localizationManager.addObserver(with: viewController) { [weak viewController] (_, _) in
            let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
            viewController?.tabBarItem.title = currentTitle
        }

        return viewController
    }

    static func createGovernanceController(for localizationManager: LocalizationManagerProtocol)
        -> UIViewController? {
        let viewController = UIViewController()
        viewController.view.backgroundColor = .white

        let localizableTitle = LocalizableResource { locale in
            R.string.localizable.tabbarGovernanceTitle(preferredLanguages: locale.rLanguages)
        }

        let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
        viewController.tabBarItem = createTabBarItem(title: currentTitle,
                                                     normalImage: nil,
                                                     selectedImage: nil)

        localizationManager.addObserver(with: viewController) { [weak viewController] (_, _) in
            let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
            viewController?.tabBarItem.title = currentTitle
        }

        return viewController
    }

    static func createExtrinsicsController(for localizationManager: LocalizationManagerProtocol)
        -> UIViewController? {
        let viewController = UIViewController()
        viewController.view.backgroundColor = .white

        let localizableTitle = LocalizableResource { locale in
            R.string.localizable.tabbarExtrinsicsTitle(preferredLanguages: locale.rLanguages)
        }

        let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
        viewController.tabBarItem = createTabBarItem(title: currentTitle,
                                                     normalImage: nil,
                                                     selectedImage: nil)

        localizationManager.addObserver(with: viewController) { [weak viewController] (_, _) in
            let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
            viewController?.tabBarItem.title = currentTitle
        }

        return viewController
    }

    static func createSettingsController(for localizationManager: LocalizationManagerProtocol)
        -> UIViewController? {
        guard let settingsView = ProfileViewFactory.createView() else {
            return nil
        }

        let navigationController = FearlessNavigationController(rootViewController: settingsView.controller)

        let localizableTitle = LocalizableResource { locale in
            R.string.localizable.tabbarSettingsTitle(preferredLanguages: locale.rLanguages)
        }

        let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
        navigationController.tabBarItem = createTabBarItem(title: currentTitle,
                                                           normalImage: nil,
                                                           selectedImage: nil)

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

        let normalAttributes = [NSAttributedString.Key.foregroundColor: UIColor.tabBarItemNormal]
        let selectedAttributes = [NSAttributedString.Key.foregroundColor: UIColor.tabBarItemSelected]

        tabBarItem.setTitleTextAttributes(normalAttributes, for: .normal)
        tabBarItem.setTitleTextAttributes(selectedAttributes, for: .selected)

        return tabBarItem
    }
}
