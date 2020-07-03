import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    var isUnitTesting: Bool {
        return ProcessInfo.processInfo.arguments.contains("-UNITTEST")
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        if !isUnitTesting {
            let rootWindow = UIWindow()
            window = rootWindow

            let presenter = RootPresenterFactory.createPresenter(with: rootWindow)
            presenter.loadOnLaunch()

            rootWindow.makeKeyAndVisible()
        }
        return true
    }
}
