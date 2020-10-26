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

        view.backgroundColor = R.color.colorBlack()

        navigationBar.tintColor = FearlessNavigationBarStyle.tintColor

        navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
        navigationBar.shadowImage = UIImage()

        navigationBar.titleTextAttributes = FearlessNavigationBarStyle.titleAttributes
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        insertCloseButtonToRootIfNeeded()
    }

    // MARK: UINavigationControllerDelegate

    public func navigationController(_ navigationController: UINavigationController,
                                     willShow viewController: UIViewController, animated: Bool) {
        updateNavigationBarState(in: viewController)
        setupBackButtonItem(for: viewController)
    }

    // MARK: Private

    private func updateNavigationBarState(in viewController: UIViewController) {
        let isHidden = viewController as? HiddableBarWhenPushed != nil
        setNavigationBarHidden(isHidden, animated: true)
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
            let closeItem = UIBarButtonItem(image: R.image.iconClose(),
                                            style: .plain,
                                            target: self,
                                            action: #selector(actionClose))
            rootViewController.navigationItem.leftBarButtonItem = closeItem
        }
    }

    @objc private func actionClose() {
        presentingViewController?.dismiss(animated: true, completion: nil)
    }
}
