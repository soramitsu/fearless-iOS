import Foundation
import UIKit

protocol WalletConnectCoordinatorRouter {
    func setRoot(controller: UIViewController)
    func present(controller: UIViewController)
    func dismiss(completion: (() -> Void)?)
}

final class WalletConnectCoordinatorRouterImpl: WalletConnectCoordinatorRouter {
    private var coveringWindow: UIWindow?

    func setRoot(controller: UIViewController) {
        prepareWindow()
        coveringWindow?.rootViewController?.present(controller, animated: true)
    }

    func present(controller: UIViewController) {
        coveringWindow?.rootViewController?.topModalViewController.present(controller, animated: true)
    }

    func dismiss(completion: (() -> Void)?) {
        dismissWindow(completion: completion)
    }

    private func dismissWindow(completion: (() -> Void)?) {
        coveringWindow?.rootViewController?.dismiss(animated: true, completion: { [weak self] in
            self?.coveringWindow?.isHidden = true
            self?.coveringWindow = nil
            completion?()
        })
    }

    private func prepareWindow() {
        coveringWindow = UIWindow(frame: UIScreen.main.bounds)

        if let coveringWindow = coveringWindow {
            coveringWindow.windowLevel = UIWindow.Level.alert + 1
            coveringWindow.isHidden = false
            coveringWindow.backgroundColor = .clear
            coveringWindow.rootViewController = UIViewController()
            coveringWindow.makeKeyAndVisible()
        }
    }
}
