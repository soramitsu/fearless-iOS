import UIKit

class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    var isUnitTesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-UNITTEST")
    }

    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        FailClosedSecureUnarchiveFromDataTransformer.register()

        guard !isUnitTesting else { return true }

        let rootWindow = FearlessWindow()
        window = rootWindow

        URLHandlingService.shared.setup(children: [
            IrohaConnectURLHandler.shared, LegacyTonConnectURLHandler.shared, GoogleDriveBackupURLHandler.shared
        ])

        let presenter = RootPresenterFactory.createPresenter(with: rootWindow)
        presenter.loadOnLaunch()

        rootWindow.makeKeyAndVisible()

        if let launchURL = launchOptions?[.url] as? URL {
            DispatchQueue.main.async {
                _ = URLHandlingService.shared.handle(url: launchURL)
            }
        }
        return true
    }

    func application(
        _: UIApplication,
        open url: URL,
        options _: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        URLHandlingService.shared.handle(url: url)
    }
}
