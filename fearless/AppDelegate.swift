import UIKit

class AppDelegate: UIResponder, UIApplicationDelegate {
    private lazy var retiredSoraCardDataCleanup = RetiredSoraCardDataCleanup()

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

        // Not part of startup: it never blocks or fails the wallet opening.
        retiredSoraCardDataCleanup.runIfNeeded()
        return true
    }
}
