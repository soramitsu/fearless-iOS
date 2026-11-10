import UIKit

/// Whether the PIN screen that locks the app after inactivity is on screen. Prompts
/// that live in their own windows above the app, such as WalletConnect requests, wait
/// until the app is unlocked instead of covering the PIN screen.
final class ApplicationLockState {
    static let shared = ApplicationLockState()
    static let didChangeNotification = Notification.Name("ApplicationLockStateDidChange")

    private let notificationCenter: NotificationCenter
    private weak var lockScreen: UIViewController?

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
    }

    /// The lock ends when it is unlocked or when its PIN screen is gone.
    var isLocked: Bool {
        lockScreen != nil
    }

    func lock(with screen: UIViewController) {
        lockScreen = screen
        notificationCenter.post(name: Self.didChangeNotification, object: self)
    }

    func unlock() {
        guard lockScreen != nil else {
            return
        }
        lockScreen = nil
        notificationCenter.post(name: Self.didChangeNotification, object: self)
    }
}
