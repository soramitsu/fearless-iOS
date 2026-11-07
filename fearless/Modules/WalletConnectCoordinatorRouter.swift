import Foundation
import UIKit

protocol WalletConnectCoordinatorRouter {
    var isBusy: Bool { get }
    func setRoot(controller: UIViewController)
    func present(controller: UIViewController)
    func dismiss(completion: (() -> Void)?)
}

final class WalletConnectCoordinatorRouterImpl: WalletConnectCoordinatorRouter {
    var isBusy: Bool {
        coveringWindow != nil
    }

    private(set) var coveringWindow: UIWindow?
    private let lockState: ApplicationLockState
    private let notificationCenter: NotificationCenter
    private let windowScene: () -> UIWindowScene?
    private var lockObserver: NSObjectProtocol?

    init(
        lockState: ApplicationLockState = .shared,
        notificationCenter: NotificationCenter = .default,
        windowScene: @escaping () -> UIWindowScene? = { SceneWindowFinder.activeWindow()?.windowScene }
    ) {
        self.lockState = lockState
        self.notificationCenter = notificationCenter
        self.windowScene = windowScene
        lockObserver = notificationCenter.addObserver(
            forName: ApplicationLockState.didChangeNotification,
            object: lockState,
            queue: .main
        ) { [weak self] _ in
            self?.updateVisibility()
        }
    }

    deinit {
        if let lockObserver = lockObserver {
            notificationCenter.removeObserver(lockObserver)
        }
    }

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
        guard let windowScene = windowScene() else {
            return
        }

        coveringWindow = UIWindow(windowScene: windowScene)

        if let coveringWindow = coveringWindow {
            coveringWindow.windowLevel = UIWindow.Level.alert + 1
            coveringWindow.isHidden = false
            coveringWindow.backgroundColor = .clear
            coveringWindow.rootViewController = UIViewController()
            coveringWindow.makeKeyAndVisible()
        }

        updateVisibility()
    }

    /// The request window sits above the app's window, so it is hidden while the PIN
    /// screen locks the app and shown again once the app is unlocked.
    private func updateVisibility() {
        guard let coveringWindow = coveringWindow else {
            return
        }

        if lockState.isLocked {
            coveringWindow.isHidden = true
            // The PIN screen is on the app's own window: it takes the key status back.
            SceneWindowFinder.mainWindow(from: coveringWindow.windowScene)?.makeKey()
        } else {
            coveringWindow.makeKeyAndVisible()
        }
    }
}
