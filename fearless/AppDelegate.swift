import UIKit

class AppDelegate: UIResponder, UIApplicationDelegate {
    private lazy var retiredSoraCardDataCleanup = RetiredSoraCardDataCleanup()
    private var sensitiveLeftoversObserver: NSObjectProtocol?

    var isUnitTesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-UNITTEST")
    }

    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        FailClosedSecureUnarchiveFromDataTransformer.register()
        FWSunlitAppearance.apply()

        guard !isUnitTesting else { return true }

        URLHandlingService.shared.setup(children: [
            IrohaConnectURLHandler.shared, LegacyTonConnectURLHandler.shared, WalletConnectURLHandler.shared,
            GoogleDriveBackupURLHandler.shared
        ])

        // Not part of startup: these never block or fail the wallet opening.
        retiredSoraCardDataCleanup.runIfNeeded()
        removeSensitiveLeftoversOnceActive()
        return true
    }

    /// A third-party keyboard can read and send everything typed into the wallet,
    /// recovery phrases and passwords included, so only the system keyboard is offered.
    func application(
        _: UIApplication,
        shouldAllowExtensionPointIdentifier extensionPointIdentifier: UIApplication.ExtensionPointIdentifier
    ) -> Bool {
        extensionPointIdentifier != .keyboard
    }

    /// Removes secret files that earlier runs left behind (`SensitiveExportFiles`), once per
    /// launch and off the main thread. A keystore opened from another app at launch waits in
    /// `Documents/Inbox` until the scene's queued URL delivery reads it on the main queue, so
    /// the clean-up is queued behind that delivery when the app first becomes active.
    private func removeSensitiveLeftoversOnceActive() {
        sensitiveLeftoversObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            guard let self, let observer = self.sensitiveLeftoversObserver else {
                return
            }
            NotificationCenter.default.removeObserver(observer)
            self.sensitiveLeftoversObserver = nil
            DispatchQueue.main.async {
                DispatchQueue.global(qos: .utility).async {
                    SensitiveExportFiles.removeLeftovers()
                }
            }
        }
    }
}
