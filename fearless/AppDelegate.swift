import UIKit

class AppDelegate: UIResponder, UIApplicationDelegate {
    var isUnitTesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-UNITTEST")
    }

    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        FailClosedSecureUnarchiveFromDataTransformer.register()

        guard !isUnitTesting else { return true }

        URLHandlingService.shared.setup(children: [
            IrohaConnectURLHandler.shared, LegacyTonConnectURLHandler.shared, GoogleDriveBackupURLHandler.shared
        ])
        return true
    }
}
