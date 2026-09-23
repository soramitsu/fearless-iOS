import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var rootPresenter: RootPresenterProtocol?

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

    func sceneDidDisconnect(_: UIScene) {
        rootPresenter = nil
        window = nil
    }
}
