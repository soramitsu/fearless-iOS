import UIKit

/// Whether the PIN screen that locks the app after inactivity is on screen, or a re-lock is due and waiting to be
/// shown. Prompts that live in their own windows above the app, such as WalletConnect requests, wait until the app
/// is unlocked instead of covering the PIN screen.
final class ApplicationLockState {
    static let shared = ApplicationLockState()
    static let didChangeNotification = Notification.Name("ApplicationLockStateDidChange")

    private let notificationCenter: NotificationCenter
    private weak var lockScreen: UIViewController?
    private var isLockPending = false

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
    }

    /// The lock ends when it is unlocked or when its PIN screen is gone. A re-lock that waits to be shown counts as
    /// locked too.
    var isLocked: Bool {
        isLockPending || lockScreen != nil
    }

    func lock(with screen: UIViewController) {
        lockScreen = screen
        isLockPending = false
        notificationCenter.post(name: Self.didChangeNotification, object: self)
    }

    /// A re-lock is due but its PIN screen is not on screen yet.
    func markLockPending() {
        guard !isLockPending else {
            return
        }
        isLockPending = true
        notificationCenter.post(name: Self.didChangeNotification, object: self)
    }

    /// The Keychain confirmed there is no PIN to unlock with. Only the re-lock ends its own pending state; `unlock`
    /// never does.
    func cancelPendingLock() {
        guard isLockPending else {
            return
        }
        isLockPending = false
        notificationCenter.post(name: Self.didChangeNotification, object: self)
    }

    func unlock() {
        guard lockScreen != nil else {
            return
        }
        lockScreen = nil
        notificationCenter.post(name: Self.didChangeNotification, object: self)
    }

    /// Ends the lock only if `screen` is the PIN screen that holds it: a PIN that finishes leaving after a newer lock
    /// was shown must not end that newer lock.
    func unlock(from screen: UIViewController) {
        guard lockScreen === screen else {
            return
        }
        unlock()
    }
}
