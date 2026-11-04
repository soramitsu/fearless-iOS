import UIKit
import SoraFoundation

final class MainTabBarViewController: UITabBarController {
    private var presenter: MainTabBarPresenterProtocol

    private var viewAppeared: Bool = false

    private let tabBarBackgroundView = TabBarBackgroundView()
    private let middleButton = TabBarMiddleButton(frame: .zero)
    private let middleButtonTouchTarget = TabBarMiddleButtonTouchTarget()
    private var accessibleTabs: [MainTabBarDestination: TabBarAccessibilityElement] = [:]
    /// The root controller of every destination, kept for both tab modes.
    private var destinationControllers: [UIViewController]

    /// iPad uses UIKit's sidebar-adaptable tabs (iPadOS 18 and later): a sidebar in
    /// landscape, a floating tab bar in portrait and a bottom tab bar in compact
    /// windows. iPhone keeps the custom tab bar with the raised Polkaswap button.
    let usesAdaptiveTabs: Bool

    init(
        viewControllers: [UIViewController],
        presenter: MainTabBarPresenterProtocol,
        localizationManager: LocalizationManagerProtocol,
        idiom: UIUserInterfaceIdiom = UIDevice.current.userInterfaceIdiom
    ) {
        self.presenter = presenter
        destinationControllers = viewControllers
        if #available(iOS 18.0, *) {
            usesAdaptiveTabs = idiom == .pad
        } else {
            usesAdaptiveTabs = false
        }

        super.init(nibName: nil, bundle: nil)

        if #available(iOS 18.0, *), usesAdaptiveTabs {
            mode = .tabSidebar
            tabs = MainTabBarDestination.allCases.compactMap(makeTab(for:))
        } else {
            self.viewControllers = viewControllers
        }
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        if usesAdaptiveTabs {
            configureAdaptiveTabs()
        } else {
            configureTabBar()
        }
        applyLocalization()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        guard !usesAdaptiveTabs else {
            return
        }

        tabBar.sendSubviewToBack(tabBarBackgroundView)
        tabBar.bringSubviewToFront(middleButton)
        layoutMiddleButtonTouchTarget()
        view.bringSubviewToFront(middleButtonTouchTarget)
        viewControllers?.forEach { reserveRaisedButtonSpace(in: $0) }
        updateAccessibleTabs()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        view.setNeedsLayout()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        view.setNeedsLayout()
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
                .font: UIFont.systemFont(ofSize: 12, weight: .medium)
            ]
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
                .foregroundColor: R.color.colorWhite() ?? UIColor.white,
                .font: UIFont.systemFont(ofSize: 12, weight: .semibold)
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
            make.centerY.equalTo(tabBar.snp.top)
        }
        middleButton.addAction { [weak self] in
            self?.select(destination: .polkaswap)
        }
        // UIKit's tab bar ignores touches above its bounds. Extend the artwork's
        // touch region in the parent view while retaining its single AX button.
        // iOS 27 attaches the tab bar to its own container only after this
        // runs, so a constraint to it crosses hierarchies and throws. The
        // target follows the artwork by frame in `layoutMiddleButtonTouchTarget`.
        middleButtonTouchTarget.isAccessibilityElement = false
        middleButtonTouchTarget.accessibilityElementsHidden = true
        middleButtonTouchTarget.translatesAutoresizingMaskIntoConstraints = true
        middleButtonTouchTarget.isHidden = true
        middleButtonTouchTarget.acceptsTouches = { [weak self] in
            self?.isMiddleButtonOnScreen ?? false
        }
        view.addSubview(middleButtonTouchTarget)
        middleButtonTouchTarget.addAction { [weak self] in
            self?.middleButton.sendActions(for: .touchUpInside)
        }
        viewControllers?.forEach { reserveRaisedButtonSpace(in: $0) }

        for destination in MainTabBarDestination.allCases where destination != .polkaswap {
            accessibleTabs[destination] = TabBarAccessibilityElement(container: tabBar) { [weak self] in
                self?.select(destination: destination)
            }
        }
        tabBar.accessibilityElements = MainTabBarDestination.allCases.compactMap { destination -> Any? in
            destination == .polkaswap ? middleButton : accessibleTabs[destination]
        }
        updateMiddleButtonSelection()
    }

    private var isMiddleButtonOnScreen: Bool {
        guard let window = view.window, middleButton.window === window else {
            return false
        }

        // A pushed screen may hide the tab bar or its system container.
        var current: UIView? = middleButton
        while let ancestor = current, ancestor !== window {
            if ancestor.isHidden || ancestor.alpha < 0.01 {
                return false
            }
            current = ancestor.superview
        }
        return true
    }

    private func layoutMiddleButtonTouchTarget() {
        guard isMiddleButtonOnScreen else {
            middleButtonTouchTarget.isHidden = true
            return
        }

        // Resolve the artwork's constraints before reading its geometry.
        tabBar.layoutIfNeeded()
        // Use bounds and center so the selected 1.05 transform never inflates the target.
        let centerInWindow = middleButton.convert(
            CGPoint(x: middleButton.bounds.midX, y: middleButton.bounds.midY),
            to: nil
        )
        middleButtonTouchTarget.bounds = CGRect(origin: .zero, size: middleButton.bounds.size)
        middleButtonTouchTarget.center = view.convert(centerInWindow, from: nil)
        middleButtonTouchTarget.isHidden = false
    }

    private func configureAdaptiveTabs() {
        view.tintColor = R.color.colorPink()
        if #available(iOS 26.0, *) {
            tabBarMinimizeBehavior = .never
        }
    }

    @available(iOS 18.0, *)
    private func makeTab(for destination: MainTabBarDestination) -> UITab? {
        guard let controller = destinationControllers[safe: destination.rawValue] else {
            return nil
        }

        return UITab(
            title: destination.title,
            image: destination.image,
            identifier: destination.tabIdentifier
        ) { _ in
            controller
        }
    }

    /// The destination on screen, in either tab mode.
    var selectedDestination: MainTabBarDestination? {
        if #available(iOS 18.0, *), usesAdaptiveTabs {
            return selectedTab.flatMap { MainTabBarDestination(tabIdentifier: $0.identifier) }
        }
        return MainTabBarDestination(rawValue: selectedIndex)
    }

    /// The root controller of a destination, in either tab mode.
    func controller(for destination: MainTabBarDestination) -> UIViewController? {
        destinationControllers[safe: destination.rawValue]
    }

    private func reserveRaisedButtonSpace(in controller: UIViewController) {
        guard !usesAdaptiveTabs, let root = controller.navigationRootViewController() else { return }
        // Include the selected artwork's 1.05 scale. Only the tab root needs
        // this space; pushed screens that hide the tab bar keep their layout.
        if root.additionalSafeAreaInsets.bottom < 30 {
            root.additionalSafeAreaInsets.bottom = 30
        }
    }

    func select(destination: MainTabBarDestination) {
        guard let destinationController = controller(for: destination) else {
            return
        }

        if selectedDestination == destination {
            returnToRoot(of: destinationController)
        }
        if #available(iOS 18.0, *), usesAdaptiveTabs {
            selectedTab = tab(forIdentifier: destination.tabIdentifier)
        } else {
            selectedIndex = destination.rawValue
            updateMiddleButtonSelection()
        }
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
        guard !usesAdaptiveTabs else {
            return
        }

        middleButton.isSelected = selectedIndex == MainTabBarDestination.polkaswap.rawValue
        updateAccessibleTabs()
    }

    private func updateAccessibleTabs() {
        guard !usesAdaptiveTabs else {
            return
        }

        let slotWidth = tabBar.bounds.width / CGFloat(MainTabBarDestination.allCases.count)
        for (destination, element) in accessibleTabs {
            element.accessibilityLabel = destination.title
            element.accessibilityTraits = selectedIndex == destination.rawValue ? [.button, .selected] : .button
            element.accessibilityFrameInContainerSpace = CGRect(
                x: CGFloat(destination.rawValue) * slotWidth, y: 0,
                width: slotWidth, height: max(44, tabBar.bounds.height - tabBar.safeAreaInsets.bottom)
            )
        }
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

    @available(iOS 18.0, *)
    func tabBarController(_: UITabBarController, shouldSelectTab tab: UITab) -> Bool {
        if
            tab.identifier == selectedTab?.identifier,
            let destination = MainTabBarDestination(tabIdentifier: tab.identifier),
            let destinationController = controller(for: destination) {
            returnToRoot(of: destinationController)
        }

        return true
    }
}

extension MainTabBarViewController: MainTabBarViewProtocol {
    var isPolkaswapUnavailable: Bool {
        guard let navigationController = controller(for: .polkaswap) as? UINavigationController else {
            return false
        }

        return navigationController.viewControllers.first is FeatureUnavailableViewController
    }

    func didReplaceView(for newView: UIViewController, for index: Int) {
        guard let destination = MainTabBarDestination(rawValue: index),
              destinationControllers.indices.contains(index) else {
            return
        }

        destinationControllers[index] = newView

        if #available(iOS 18.0, *), usesAdaptiveTabs {
            let selected = selectedDestination
            var newTabs = tabs
            if let position = newTabs.firstIndex(where: { $0.identifier == destination.tabIdentifier }),
               let newTab = makeTab(for: destination) {
                newTabs[position] = newTab
            }
            setTabs(newTabs, animated: false)
            if let selected = selected {
                selectedTab = tab(forIdentifier: selected.tabIdentifier)
            }
            return
        }

        guard var newViewControllers = viewControllers else {
            return
        }

        newViewControllers[index] = newView
        reserveRaisedButtonSpace(in: newView)

        setViewControllers(newViewControllers, animated: false)
    }

    func openPolkamarkt(marketId: String) {
        select(destination: .defi)
        guard let navigationController = controller(for: .defi) as? UINavigationController,
              let hub = navigationController.viewControllers.first as? DeFiHubViewController else {
            return
        }
        navigationController.popToRootViewController(animated: false)
        hub.openPolkamarkt(marketId: marketId)
    }
}

extension MainTabBarViewController: Localizable {
    func applyLocalization() {
        if #available(iOS 18.0, *), usesAdaptiveTabs {
            MainTabBarDestination.allCases.forEach { destination in
                tab(forIdentifier: destination.tabIdentifier)?.title = destination.title
            }
            return
        }

        MainTabBarDestination.allCases.forEach { destination in
            viewControllers?[safe: destination.rawValue]?.tabBarItem.title = destination.title
            viewControllers?[safe: destination.rawValue]?.tabBarItem.accessibilityLabel = destination.title
        }
        middleButton.accessibilityLabel = "Polkaswap"
        updateAccessibleTabs()
    }
}
