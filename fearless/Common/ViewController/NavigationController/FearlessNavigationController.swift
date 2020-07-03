import UIKit

protocol HiddableBarWhenPushed: class {}

final class FearlessNavigationController: UINavigationController, UINavigationControllerDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()

        setup()
    }

    override var childForStatusBarStyle: UIViewController? {
        return self.topViewController
    }

    private func setup() {
        delegate = self

        view.backgroundColor = .white

        navigationBar.tintColor = FearlessNavigationBarStyle.tintColor

        navigationBar.setBackgroundImage(FearlessNavigationBarStyle.background,
                                         for: UIBarMetrics.default)
        navigationBar.shadowImage = FearlessNavigationBarStyle.darkShadow

        navigationBar.titleTextAttributes = FearlessNavigationBarStyle.titleAttributes
    }

    // MARK: UINavigationControllerDelegate

    public func navigationController(_ navigationController: UINavigationController,
                                     willShow viewController: UIViewController, animated: Bool) {
        handleDesignableNavigationIfNeeded(viewController: viewController)
    }

    // MARK: Private

    private func handleDesignableNavigationIfNeeded(viewController: UIViewController) {
        updateNavigationBarState(in: viewController)
        setupBackButtonItem(for: viewController)
    }

    private func updateNavigationBarState(in viewController: UIViewController) {
        let isHidden = viewController as? HiddableBarWhenPushed != nil
        setNavigationBarHidden(isHidden, animated: true)

        var navigationShadowStyle = NavigationBarSeparatorStyle.dark

        if let navigationBarDesignable = viewController as? DesignableNavigationBarProtocol {
            navigationShadowStyle = navigationBarDesignable.separatorStyle
        }

        switch navigationShadowStyle {
        case .dark:
            navigationBar.shadowImage = FearlessNavigationBarStyle.darkShadow
        case .light:
            navigationBar.shadowImage = FearlessNavigationBarStyle.lightShadow
        case .empty:
            navigationBar.shadowImage = UIImage()
        }
    }

    private func setupBackButtonItem(for viewController: UIViewController) {
        let backButtonItem = viewController.navigationItem.backBarButtonItem ?? UIBarButtonItem()
        backButtonItem.title = " "
        viewController.navigationItem.backBarButtonItem = backButtonItem
    }
}
