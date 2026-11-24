import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var rootPresenter: RootPresenterProtocol?
    private let snapshotCover = AppSwitcherSnapshotCover()

    func scene(
        _ scene: UIScene,
        willConnectTo _: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene,
              !ProcessInfo.processInfo.arguments.contains("-UNITTEST") else {
            return
        }

        let rootWindow = FearlessWindow(windowScene: windowScene)
        window = rootWindow

        let presenter = RootPresenterFactory.createPresenter(with: rootWindow)
        rootPresenter = presenter
        presenter.loadOnLaunch()
        rootWindow.makeKeyAndVisible()
        // The Ignite launch covers the start flow above and flies into its first screen; it changes nothing below.
        FWLaunchIgnite.installIfNeeded(over: rootWindow, in: windowScene)
        FWFeedback.shared.prepare()
        #if DEBUG
            FWFeelDebugSeams.install()
            FWShikibanDebugSeams.install()
        #endif

        // Scene apps receive launch URLs here, not in AppDelegate launch options.
        // Defer delivery until root setup has installed its full handler list.
        let launchURLs = connectionOptions.urlContexts.map(\.url)
        DispatchQueue.main.async {
            for url in launchURLs {
                _ = URLHandlingService.shared.handle(url: url)
            }
        }
    }

    func scene(_: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for context in URLContexts {
            _ = URLHandlingService.shared.handle(url: context.url)
        }
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        guard let windowScene = scene as? UIWindowScene else {
            return
        }

        snapshotCover.show(in: windowScene)
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // A re-lock that is due, or still pending from before, goes on screen (or behind its cover) before the
        // app-switcher cover is removed, so the app is never shown unlocked in between.
        FearlessApplication.current?.sessionLock.willEnterForeground(in: scene as? UIWindowScene)
        snapshotCover.hide()
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        FearlessApplication.current?.sessionLock.attempt(in: scene as? UIWindowScene)
    }

    func sceneDidDisconnect(_: UIScene) {
        snapshotCover.hide()
        rootPresenter = nil
        window = nil
    }
}

/// iOS shows, and saves to disk, a snapshot of the screen taken after the scene
/// enters the background. A recovery phrase, seed or key on screen at that moment
/// would end up in the app switcher. This window covers every other window of the
/// scene with the launch screen while the app is in the background only, so it
/// never sits over Face ID, permission or sign-in prompts while the app is in use.
final class AppSwitcherSnapshotCover {
    /// Above the WalletConnect and IrohaConnect windows (`.alert + 1`).
    static let windowLevel = UIWindow.Level.alert + 100

    private var window: UIWindow?

    var isShown: Bool {
        window.map { !$0.isHidden } ?? false
    }

    func show(in scene: UIWindowScene) {
        let coverWindow: UIWindow
        if let window, window.windowScene === scene {
            coverWindow = window
        } else {
            coverWindow = makeWindow(in: scene)
            window = coverWindow
        }

        coverWindow.isHidden = false
    }

    func hide() {
        window?.isHidden = true
    }

    private func makeWindow(in scene: UIWindowScene) -> UIWindow {
        let window = UIWindow(windowScene: scene)
        window.windowLevel = Self.windowLevel
        window.isUserInteractionEnabled = false
        let launchScreen = UIStoryboard(name: "LaunchScreen", bundle: nil).instantiateInitialViewController()
        window.rootViewController = launchScreen ?? Self.makeFallbackCover()
        return window
    }

    private static func makeFallbackCover() -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = R.color.colorBlack()
        return controller
    }
}
