import UIKit
import SoraFoundation

final class MainTabBarViewController: UITabBarController {
    private lazy var failedMemoView: AttentionView = {
        let view = AttentionView()
        view.backgroundColor = .black.withAlphaComponent(0.9)
        view.titleLabel.font = .h6Title
        return view
    }()

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

        applyLocalization()
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
            make.centerY.equalTo(tabBar.snp.top).offset(14)
        }
        middleButton.addAction { [weak self] in
            self?.presenter.presentPolkaswap()
        }
    }

    @objc private func didTapFailedMemoView(_: UIGestureRecognizer) {
        _ = openTab(vcClass: CrowdloanListViewController.self)
        failedMemoView.removeFromSuperview()
    }

    private func openTab<T: UIViewController>(vcClass _: T.Type) -> Bool {
        if let index = viewControllers?.firstIndex(where: { viewController in
            if viewController.isKind(of: T.self) {
                return true
            }

            if let navigationController = viewController as? FearlessNavigationController,
               let rootViewController = navigationController.viewControllers.first,
               rootViewController.isKind(of: T.self) {
                return true
            }

            return false
        }) {
            selectedIndex = index
            return true
        }

        return false
    }

    private func wrappedSelectedViewController() -> UIViewController? {
        selectedViewController?.navigationRootViewController()
    }
}

extension MainTabBarViewController: UITabBarControllerDelegate {
    func tabBarController(
        _: UITabBarController,
        shouldSelect viewController: UIViewController
    ) -> Bool {
        if let wrappedSelectedViewController = viewController.navigationRootViewController(),
           wrappedSelectedViewController.isKind(of: CrowdloanListViewController.self) {
            failedMemoView.removeFromSuperview()
        }

        if viewController == viewControllers?[selectedIndex],
           let scrollableController = viewController as? ScrollsToTop {
            scrollableController.scrollToTop()
        }

        return true
    }
}

extension MainTabBarViewController: MainTabBarViewProtocol {
    func didReplaceView(for newView: UIViewController, for index: Int) {
        guard var newViewControllers = viewControllers else {
            return
        }

        newViewControllers[index] = newView

        setViewControllers(newViewControllers, animated: false)
    }

    func presentFailedMemoView() {
        guard let wrappedSelectedViewController = wrappedSelectedViewController(),
              !wrappedSelectedViewController.isKind(of: CrowdloanListViewController.self) else {
            return
        }

        view.addSubview(failedMemoView)
        failedMemoView.snp.makeConstraints { make in
            make.bottom.equalTo(self.tabBar.snp.top)
            make.centerX.equalToSuperview()
            make.width.equalToSuperview()
            make.height.equalTo(UIConstants.cellHeight)
        }

        failedMemoView.iconView.snp.remakeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.defaultOffset)
            make.size.equalTo(UIConstants.normalAddressIconSize.height)
            make.centerY.equalToSuperview()
        }

        failedMemoView.titleLabel.snp.remakeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(failedMemoView.iconView.snp.trailing).offset(UIConstants.defaultOffset)
        }

        applyLocalization()

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTapFailedMemoView(_:)))
        tapGesture.isEnabled = true
        failedMemoView.addGestureRecognizer(tapGesture)
    }
}

extension MainTabBarViewController: Localizable {
    func applyLocalization() {
        failedMemoView.titleLabel.text = R.string.localizable
            .tabbarCrowdloanAttention(preferredLanguages: selectedLocale.rLanguages)
    }
}
