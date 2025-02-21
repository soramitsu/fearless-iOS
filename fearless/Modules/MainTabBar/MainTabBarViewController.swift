import UIKit
import SoraFoundation
import SSFModels
import SoraKeystore

final class MainTabBarViewController: UITabBarController {
    private var presenter: MainTabBarPresenterProtocol
    private var eventCenter: EventCenterProtocol
    private var viewAppeared: Bool = false
    private var fullViewControllersList: [UIViewController]
    private var wallet: MetaAccountModel

    init(
        viewControllers: [UIViewController],
        presenter: MainTabBarPresenterProtocol,
        localizationManager: LocalizationManagerProtocol,
        eventCenter: EventCenterProtocol,
        wallet: MetaAccountModel
    ) {
        self.presenter = presenter
        self.eventCenter = eventCenter
        self.fullViewControllersList = viewControllers
        self.wallet = wallet

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

        eventCenter.add(observer: self, dispatchIn: .main)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if !viewAppeared {
            update(with: wallet)
            viewAppeared = true
            presenter.didLoad(view: self)
        }

        let tabBar = TabBar(frame: tabBar.frame)
        tabBar.setup(for: wallet.ecosystem)
        tabBar.middleButton.addAction { [weak self] in
            self?.presenter.presentPolkaswap()
        }
        setValue(tabBar, forKey: "tabBar")

        applyLocalization()
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

    private func update(with wallet: MetaAccountModel) {
        let isDappEnabled = SettingsManager.shared.dappEnabled
        
        if let tabBar = self.tabBar as? TabBar {
            tabBar.setup(for: wallet.ecosystem)
        }
        let indexes: IndexSet
        switch wallet.ecosystem {
        case .regular:
            indexes = [0, 2, 3, 4, 5]
        case .ton:
            indexes = isDappEnabled ? [0, 1, 5] : [0, 5]
        }
        let tonViewControllers = indexes.map { fullViewControllersList[$0] }
        selectedIndex = 0
        setViewControllers(tonViewControllers, animated: true)
    }
}

extension MainTabBarViewController: UITabBarControllerDelegate {
    func tabBarController(
        _: UITabBarController,
        shouldSelect viewController: UIViewController
    ) -> Bool {
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
}

extension MainTabBarViewController: Localizable {
    func applyLocalization() {}
}

extension MainTabBarViewController: EventVisitorProtocol {
    func processSelectedAccountChanged(event: SelectedAccountChanged) {
        self.wallet = event.account
        update(with: event.account)
    }
    
    func processFeatureToggleConfigSyncComplete(event: FeatureToggleConfigSyncComplete) {
        update(with: wallet)
    }
}
