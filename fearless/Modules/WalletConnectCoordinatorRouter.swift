import Foundation
import UIKit

protocol WalletConnectCoordinatorRouter {
    func setRoot(controller: UIViewController)
    func present(controller: UIViewController)
    func dismiss(completion: (() -> Void)?)
}

final class WalletConnectCoordinatorRouterImpl: WalletConnectCoordinatorRouter {
    private let rootViewController: UIViewController? = {
        UIApplication.topViewController()
    }()

    func setRoot(controller: UIViewController) {
        rootViewController?.present(controller, animated: true)
    }

    func present(controller: UIViewController) {
        rootViewController?.topModalViewController.present(controller, animated: true)
    }

    func dismiss(completion: (() -> Void)?) {
        rootViewController?.dismiss(animated: true, completion: completion)
    }
}
