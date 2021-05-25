import UIKit

protocol HiddableBarWhenPushed: AnyObject {}

protocol NavigationDependable: AnyObject {
    var navigationControlling: NavigationControlling? { get set }
}

protocol NavigationControlling: AnyObject {
    var isNavigationBarHidden: Bool { get }

    func setNavigationBarHidden(_ hidden: Bool, animated: Bool)
}

final class FearlessNavigationController: UINavigationController, UINavigationControllerDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()

        setup()
    }

    override var childForStatusBarStyle: UIViewController? {
        topViewController
    }

    private func setup() {
        delegate = self

        view.backgroundColor = R.color.colorBlack()

        navigationBar.tintColor = FearlessNavigationBarStyle.tintColor

        navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
        navigationBar.shadowImage = UIImage()
        navigationBar.backIndicatorImage = R.image.iconBack()
        navigationBar.backIndicatorTransitionMaskImage = R.image.iconBack()

        navigationBar.titleTextAttributes = FearlessNavigationBarStyle.titleAttributes
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        insertCloseButtonToRootIfNeeded()
    }

    // MARK: UINavigationControllerDelegate

    func navigationController(
        _: UINavigationController,
        willShow viewController: UIViewController,
        animated _: Bool
    ) {
        updateNavigationBarState(in: viewController)
        setupBackButtonItem(for: viewController)
    }

    // MARK: Private

    private func updateNavigationBarState(in viewController: UIViewController) {
        let isHidden = viewController as? HiddableBarWhenPushed != nil
        setNavigationBarHidden(isHidden, animated: true)

        if let navigationDependable = viewController as? NavigationDependable {
            navigationDependable.navigationControlling = self
        }
    }

    private func setupBackButtonItem(for viewController: UIViewController) {
        let backButtonItem = viewController.navigationItem.backBarButtonItem ?? UIBarButtonItem()
        backButtonItem.title = " "
        viewController.navigationItem.backBarButtonItem = backButtonItem
    }

    private func insertCloseButtonToRootIfNeeded() {
        if
            presentingViewController != nil,
            let rootViewController = viewControllers.first,
            rootViewController.navigationItem.leftBarButtonItem == nil {
            let closeItem = UIBarButtonItem(
                image: R.image.iconClose(),
                style: .plain,
                target: self,
                action: #selector(actionClose)
            )
            rootViewController.navigationItem.leftBarButtonItem = closeItem
        }
    }

    @objc private func actionClose() {
        presentingViewController?.dismiss(animated: true, completion: nil)
    }
}

extension FearlessNavigationController: NavigationControlling {}
