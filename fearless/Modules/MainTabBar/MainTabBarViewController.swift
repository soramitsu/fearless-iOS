import UIKit
import SoraFoundation

final class MainTabBarViewController: UITabBarController {
    private var presenter: MainTabBarPresenterProtocol

    private var viewAppeared: Bool = false

    private let tabBarBackgroundView = TabBarBackgroundView()
    private let middleButton = TabBarMiddleButton(frame: .zero)

    init(
        viewControllers: [UIViewController],
        presenter: MainTabBarPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter

        super.init(nibName: nil, bundle: nil)

        self.viewControllers = viewControllers
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        configureTabBar()
        applyLocalization()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        tabBar.sendSubviewToBack(tabBarBackgroundView)
        tabBar.bringSubviewToFront(middleButton)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if !viewAppeared {
            viewAppeared = true
            presenter.didLoad(view: self)
        }
    }

    private func configureTabBar() {
        // UITabBarController owns the tab bar and installs its item views. Keep
        // that instance intact and layer the Fearless styling onto it.
        tabBar.backgroundColor = .clear
        tabBar.clipsToBounds = false
        tabBar.isTranslucent = true

        if #available(iOS 26.0, *) {
            tabBarMinimizeBehavior = .never
        }

        if #available(iOS 13.0, *) {
            let appearance = UITabBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = .clear
            appearance.backgroundEffect = nil
            appearance.shadowColor = .clear
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
                .foregroundColor: R.color.colorGray() ?? UIColor.gray,
                .font: UIFont.systemFont(ofSize: 10, weight: .medium)
            ]
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
                .foregroundColor: R.color.colorWhite() ?? UIColor.white,
                .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
            ]
            tabBar.standardAppearance = appearance

            if #available(iOS 15.0, *) {
                tabBar.scrollEdgeAppearance = appearance
            }
        } else {
            tabBar.backgroundImage = UIImage()
            tabBar.shadowImage = UIImage()
            tabBar.barTintColor = .clear
        }

        tabBar.insertSubview(tabBarBackgroundView, at: 0)
        tabBarBackgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        tabBar.addSubview(middleButton)
        middleButton.snp.makeConstraints { make in
            make.size.equalTo(56)
            make.centerX.equalToSuperview()
            make.centerY.equalTo(tabBar.snp.top).offset(12)
        }
        middleButton.addAction { [weak self] in
            self?.select(destination: .polkaswap)
        }

        updateMiddleButtonSelection()
    }

    func select(destination: MainTabBarDestination) {
        guard viewControllers?.indices.contains(destination.rawValue) == true else {
            return
        }

        if selectedIndex == destination.rawValue,
           let selectedController = viewControllers?[destination.rawValue] {
            returnToRoot(of: selectedController)
        }
        selectedIndex = destination.rawValue
        updateMiddleButtonSelection()
    }

    private func returnToRoot(of viewController: UIViewController) {
        if let navigationController = viewController as? UINavigationController,
           navigationController.viewControllers.count > 1 {
            // UIKit defers the stack mutation when an animated pop is requested
            // before this tab is attached to a window. Keep the state change
            // deterministic while preserving animation for the visible app.
            let shouldAnimate = navigationController.viewIfLoaded?.window != nil
            navigationController.popToRootViewController(animated: shouldAnimate)
        } else if let scrollableController = viewController.navigationRootViewController() as? ScrollsToTop {
            scrollableController.scrollToTop()
        }
    }

    private func updateMiddleButtonSelection() {
        middleButton.isSelected = selectedIndex == MainTabBarDestination.polkaswap.rawValue
    }
}

extension MainTabBarViewController: UITabBarControllerDelegate {
    func tabBarController(
        _: UITabBarController,
        shouldSelect viewController: UIViewController
    ) -> Bool {
        if viewController == viewControllers?[selectedIndex] {
            returnToRoot(of: viewController)
        }

        return true
    }

    func tabBarController(_: UITabBarController, didSelect _: UIViewController) {
        updateMiddleButtonSelection()
    }
}

extension MainTabBarViewController: MainTabBarViewProtocol {
    var isPolkaswapUnavailable: Bool {
        guard let navigationController = viewControllers?[safe: MainTabBarDestination.polkaswap.rawValue]
            as? UINavigationController else {
            return false
        }

        return navigationController.viewControllers.first is FeatureUnavailableViewController
    }

    func didReplaceView(for newView: UIViewController, for index: Int) {
        guard var newViewControllers = viewControllers else {
            return
        }

        newViewControllers[index] = newView

        setViewControllers(newViewControllers, animated: false)
    }

    func openPolkamarkt(marketId: String) {
        select(destination: .defi)
        guard let navigationController = viewControllers?[safe: MainTabBarDestination.defi.rawValue]
            as? UINavigationController,
            let hub = navigationController.viewControllers.first as? DeFiHubViewController else {
            return
        }
        navigationController.popToRootViewController(animated: false)
        hub.openPolkamarkt(marketId: marketId)
    }
}

extension MainTabBarViewController: Localizable {
    func applyLocalization() {
        MainTabBarDestination.allCases.forEach { destination in
            viewControllers?[safe: destination.rawValue]?.tabBarItem.title = destination.title
            viewControllers?[safe: destination.rawValue]?.tabBarItem.accessibilityLabel = destination.title
        }
        middleButton.accessibilityLabel = MainTabBarDestination.polkaswap.title
    }
}
