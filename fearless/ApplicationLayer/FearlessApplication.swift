import UIKit
import SoraFoundation
import SoraKeystore

/// Decides whether returning from the background needs the PIN, from monotonic clock readings.
enum BackgroundSessionLockPolicy {
    /// True after `limit` seconds away, and also when the clock reads earlier than when the app left: only a reboot
    /// restarts the monotonic clock, and nothing then vouches for the time away.
    static func requiresPin(
        enteredBackgroundAt start: TimeInterval,
        now: TimeInterval,
        limit: TimeInterval = UtilityConstants.backgroundSessionDropTimeInSeconds
    ) -> Bool {
        let elapsed = now - start
        return elapsed < 0 || elapsed >= limit
    }
}

class FearlessApplication: UIApplication {
    /// Monotonic time when the app entered the background. The wall clock is not used: setting it back must not
    /// keep a backgrounded wallet unlocked.
    private var backgroundEnteredUptime: TimeInterval?
    private var timerToDetectInactivity: Timer?
    private var applicationHandler: ApplicationHandler?

    private lazy var secretManager: SecretStoreManagerProtocol = {
        KeychainManager.shared
    }()

    override init() {
        super.init()
        applicationHandler = ApplicationHandler()
        applicationHandler?.delegate = self
    }

    override func sendEvent(_ event: UIEvent) {
        super.sendEvent(event)
        if let touches = event.allTouches {
            for touch in touches where touch.phase == UITouch.Phase.began {
                self.resetTimer()
            }
        }
    }

    private func resetTimer() {
        if let timerToDetectInactivity = timerToDetectInactivity {
            timerToDetectInactivity.invalidate()
        }

        timerToDetectInactivity = Timer.scheduledTimer(
            timeInterval: UtilityConstants.inactiveSessionDropTimeInSeconds,
            target: self,
            selector: #selector(FearlessApplication.dropSession),
            userInfo: nil,
            repeats: false
        )
    }

    @objc private func dropSession() {
        guard secretManager.checkSecret(for: KeystoreTag.pincode.rawValue) else {
            return
        }
        let window = SceneWindowFinder.activeWindow()
        if let window = window {
            // The unlock PIN is already on screen; another one on top would ask for the PIN twice.
            guard !Self.isShowingUnlockPin(in: window) else {
                return
            }
            guard let pincodeViewController = PinViewFactory.createPinCheckView()?.controller else {
                return
            }

            window.rootViewController?.dismiss(animated: false)
            window.rootViewController?.present(pincodeViewController, animated: false)
            // Prompts in their own windows, such as WalletConnect requests, stay
            // behind the PIN screen until it is unlocked.
            ApplicationLockState.shared.lock(with: pincodeViewController)
        }
    }

    static func isShowingUnlockPin(in window: UIWindow) -> Bool {
        var controllers = [window.rootViewController].compactMap { $0 }
        while let presented = controllers.last?.presentedViewController {
            controllers.append(presented)
        }
        return controllers.contains { ($0 as? PinSetupViewController)?.presenter is LocalAuthPresenter }
    }
}

extension FearlessApplication: ApplicationHandlerDelegate {
    func didReceiveDidEnterBackground(notification _: Notification) {
        timerToDetectInactivity?.invalidate()
        backgroundEnteredUptime = MonotonicClock.uptime()
    }

    func didReceiveWillEnterForeground(notification _: Notification) {
        resetTimer()
        guard let enteredBackground = backgroundEnteredUptime else {
            return
        }
        backgroundEnteredUptime = nil
        let now = MonotonicClock.uptime()
        if BackgroundSessionLockPolicy.requiresPin(enteredBackgroundAt: enteredBackground, now: now) {
            dropSession()
        }
    }
}
