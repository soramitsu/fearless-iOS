import UIKit

final class MainTabBarViewController: UITabBarController {
	var presenter: MainTabBarPresenterProtocol!

    private var viewAppeared: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()

        self.delegate = self

        configureTabBar()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if !viewAppeared {
            viewAppeared = true
            presenter.setup()
        }

        presenter.viewDidAppear()
    }

    private func configureTabBar() {
        if #available(iOS 13.0, *) {
            let appearance = UITabBarAppearance()

            appearance.backgroundImage = UIImage.background(from: UIColor.tabBarBackground)
            appearance.shadowImage = UIImage.background(from: UIColor.tabBarShadow)

            let normalAttributes = [NSAttributedString.Key.foregroundColor: UIColor.tabBarItemNormal]
            let selectedAttributes = [NSAttributedString.Key.foregroundColor: UIColor.tabBarItemSelected]

            appearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttributes
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttributes

            tabBar.standardAppearance = appearance
        } else {
            tabBar.backgroundImage = UIImage.background(from: UIColor.tabBarBackground)
            tabBar.shadowImage = UIImage.background(from: UIColor.tabBarShadow)
        }
    }
}

extension MainTabBarViewController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController,
                          shouldSelect viewController: UIViewController) -> Bool {
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

        self.setViewControllers(newViewControllers, animated: false)
    }
}
