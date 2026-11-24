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

/// What the Keychain says about the app PIN right now.
enum AppPinPresence: Equatable {
    case present
    /// The Keychain answered that there is no app PIN: a fresh install still in onboarding, or a historical
    /// installation that predates the app PIN (its recovery asks for the device passcode instead).
    case absent
    /// The Keychain could not answer: protected data is unavailable or the Keychain returned an error.
    case unknown

    /// Never reads a Keychain value: it only asks whether the PIN item exists. While protected data is unavailable
    /// a missing item and an unreadable one cannot be told apart, so the answer is `unknown`.
    static func reading(
        keystore: KeystoreProtocol,
        isProtectedDataAvailable: () -> Bool
    ) -> AppPinPresence {
        guard isProtectedDataAvailable() else {
            return .unknown
        }
        do {
            return try keystore.checkKey(for: KeystoreTag.pincode.rawValue) ? .present : .absent
        } catch {
            return .unknown
        }
    }
}

/// Puts the unlock PIN on screen for a timed re-lock and keeps the request until it is there.
///
/// A re-lock that cannot be shown at once, because the Keychain cannot yet say whether there is a PIN or because
/// there is no window or the PIN screen cannot be presented, stays pending. An opaque cover that takes every touch
/// stays over the app meanwhile, and the lock is tried again when a scene activates or comes to the foreground,
/// when protected data becomes available, and every `retryInterval` seconds. Only a Keychain that answers "no PIN"
/// ends a pending lock without the PIN: onboarding and the historical no-PIN recovery stay as they were.
final class PendingSessionLock {
    enum Attempt: Equatable {
        /// No lock was pending.
        case idle
        /// The unlock PIN is on screen.
        case locked
        /// The Keychain answered that there is no app PIN, so there is nothing to unlock with.
        case noPin
        /// Still pending: the cover stays until a later attempt shows the PIN.
        case waiting
    }

    private(set) var isPending = false
    var isCoverShown: Bool {
        cover.isShown
    }

    let cover: SessionLockCover

    private let pinPresence: () -> AppPinPresence
    private let mainWindow: (UIWindowScene?) -> UIWindow?
    private let scenes: () -> [UIWindowScene]
    private let makePin: () -> UIViewController?
    private let lockState: ApplicationLockState
    private let notificationCenter: NotificationCenter
    private let retryInterval: TimeInterval?
    private var observers: [NSObjectProtocol] = []
    private var retryTimer: Timer?
    private var isAttempting = false
    private var backgroundEnteredUptime: TimeInterval?

    init(
        pinPresence: @escaping () -> AppPinPresence = {
            AppPinPresence.reading(
                keystore: Keychain(),
                isProtectedDataAvailable: { UIApplication.shared.isProtectedDataAvailable }
            )
        },
        mainWindow: @escaping (UIWindowScene?) -> UIWindow? = { SceneWindowFinder.mainWindow(from: $0) },
        scenes: @escaping () -> [UIWindowScene] = {
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        },
        makePin: @escaping () -> UIViewController? = { PinViewFactory.createPinCheckView()?.controller },
        lockState: ApplicationLockState = .shared,
        cover: SessionLockCover = SessionLockCover(),
        notificationCenter: NotificationCenter = .default,
        retryInterval: TimeInterval? = 1
    ) {
        self.pinPresence = pinPresence
        self.mainWindow = mainWindow
        self.scenes = scenes
        self.makePin = makePin
        self.lockState = lockState
        self.cover = cover
        self.notificationCenter = notificationCenter
        self.retryInterval = retryInterval

        let retryNotifications: [Notification.Name] = [
            UIApplication.protectedDataDidBecomeAvailableNotification,
            UIApplication.didBecomeActiveNotification,
            UIScene.willEnterForegroundNotification,
            UIScene.didActivateNotification
        ]
        observers = retryNotifications.map { name in
            notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                self?.attempt(in: notification.object as? UIWindowScene)
            }
        }
    }

    deinit {
        observers.forEach { notificationCenter.removeObserver($0) }
        retryTimer?.invalidate()
    }

    /// Asks for the unlock PIN now, or as soon as it can be shown.
    @discardableResult
    func request(in scene: UIWindowScene? = nil) -> Attempt {
        isPending = true
        return attempt(in: scene)
    }

    /// Records when the app left. A pending lock stays pending in the background.
    func didEnterBackground(now: TimeInterval = MonotonicClock.uptime()) {
        backgroundEnteredUptime = now
    }

    /// Asks for the PIN after `limit` seconds away and keeps a lock that is still pending from before. Called from
    /// the scene before its app-switcher cover is removed, and again for the application, so it is idempotent.
    @discardableResult
    func willEnterForeground(
        in scene: UIWindowScene? = nil,
        now: TimeInterval = MonotonicClock.uptime(),
        limit: TimeInterval = UtilityConstants.backgroundSessionDropTimeInSeconds
    ) -> Attempt {
        if let enteredBackground = backgroundEnteredUptime {
            backgroundEnteredUptime = nil
            if BackgroundSessionLockPolicy.requiresPin(enteredBackgroundAt: enteredBackground, now: now, limit: limit) {
                return request(in: scene)
            }
        }
        return attempt(in: scene)
    }

    @discardableResult
    func attempt(in scene: UIWindowScene? = nil) -> Attempt {
        guard isPending else {
            return .idle
        }
        guard !isAttempting else {
            return .waiting
        }
        isAttempting = true
        defer { isAttempting = false }

        switch pinPresence() {
        case .absent:
            finish(restoringKeyWindow: true)
            return .noPin
        case .unknown:
            wait()
            return .waiting
        case .present:
            let window = scene.flatMap { mainWindow($0) } ?? mainWindow(nil)
            let presentation = FearlessApplication.showLock(
                on: window,
                lockState: lockState,
                makePin: makePin,
                afterDismissal: { [weak self] in self?.attempt(in: scene) }
            )
            switch presentation {
            case .presented, .alreadyShown:
                finish(restoringKeyWindow: false)
                // The cover was key while it waited; the PIN's window takes the keyboard back.
                window?.makeKey()
                return .locked
            case .noWindow, .dismissing, .notPresented:
                wait()
                return .waiting
            }
        }
    }

    private func wait() {
        cover.show(in: scenes())
        scheduleRetry()
    }

    private func finish(restoringKeyWindow: Bool) {
        isPending = false
        retryTimer?.invalidate()
        retryTimer = nil
        cover.hide(restoringKeyWindow: restoringKeyWindow)
    }

    private func scheduleRetry() {
        guard let retryInterval, retryTimer == nil else {
            return
        }
        let timer = Timer(timeInterval: retryInterval, repeats: true) { [weak self] _ in
            self?.attempt()
        }
        RunLoop.main.add(timer, forMode: .common)
        retryTimer = timer
    }
}

/// An opaque window over every other window of the app, prompts included, that takes all touches while a timed
/// re-lock waits to be shown. It is never shown over the PIN screen: it goes away once the PIN is presented.
final class SessionLockCover {
    /// Above the WalletConnect and IrohaConnect windows (`.alert + 1`), below the app-switcher cover.
    static let windowLevel = AppSwitcherSnapshotCover.windowLevel - 1

    private var windows: [UIWindow] = []
    private weak var previousKeyWindow: UIWindow?

    var isShown: Bool {
        windows.contains { !$0.isHidden }
    }

    var shownWindows: [UIWindow] {
        windows.filter { !$0.isHidden }
    }

    func show(in scenes: [UIWindowScene]) {
        for scene in scenes {
            let window: UIWindow
            if let existing = windows.first(where: { $0.windowScene === scene }) {
                window = existing
            } else {
                window = Self.makeWindow(in: scene)
                windows.append(window)
            }
            guard window.isHidden else {
                continue
            }
            if previousKeyWindow == nil {
                previousKeyWindow = scene.windows.first { $0.isKeyWindow && $0 !== window }
            }
            // Nothing typed while the app waits for its lock reaches a field underneath.
            scene.windows.filter { $0 !== window }.forEach { $0.endEditing(true) }
            window.makeKeyAndVisible()
        }
    }

    func hide(restoringKeyWindow: Bool = true) {
        let wasKey = windows.contains { $0.isKeyWindow }
        windows.forEach { $0.isHidden = true }
        if restoringKeyWindow, wasKey, let previous = previousKeyWindow, !previous.isHidden {
            previous.makeKey()
        }
        previousKeyWindow = nil
    }

    private static func makeWindow(in scene: UIWindowScene) -> UIWindow {
        let window = UIWindow(windowScene: scene)
        window.windowLevel = windowLevel
        window.isUserInteractionEnabled = true
        window.backgroundColor = R.color.colorBlack()
        window.rootViewController = SessionLockCoverViewController()
        window.isHidden = true
        return window
    }
}

/// The launch screen, opaque, taking every touch and hiding the app from VoiceOver.
final class SessionLockCoverViewController: UIViewController {
    override func loadView() {
        let view = UIView()
        view.backgroundColor = R.color.colorBlack()
        view.isOpaque = true
        view.isUserInteractionEnabled = true
        view.accessibilityViewIsModal = true
        self.view = view
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let launchScreen = UIStoryboard(name: "LaunchScreen", bundle: nil).instantiateInitialViewController() else {
            return
        }
        addChild(launchScreen)
        launchScreen.view.frame = view.bounds
        launchScreen.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(launchScreen.view)
        launchScreen.didMove(toParent: self)
    }
}

class FearlessApplication: UIApplication {
    private var timerToDetectInactivity: Timer?
    private var applicationHandler: ApplicationHandler?

    /// The timed re-lock. Created with the application, before any scene connects.
    let sessionLock = PendingSessionLock()

    static var current: FearlessApplication? {
        UIApplication.shared as? FearlessApplication
    }

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

    /// The idle lock. A Keychain error or a PIN screen that cannot be shown leaves the lock pending, never skipped.
    @objc private func dropSession() {
        sessionLock.request()
    }

    enum LockPresentation {
        case presented(UIViewController)
        /// The unlock PIN was already on screen.
        case alreadyShown(UIViewController)
        case noWindow
        /// The screens open over the app are being dismissed; the PIN follows once they are gone.
        case dismissing
        /// UIKit refused the presentation, for example during another transition, or no PIN screen was made.
        case notPresented
    }

    /// Puts the unlock PIN on the app's own window and records the lock. The key window may be a prompt above the app
    /// (a WalletConnect request): that window is hidden while the app is locked, so the PIN never goes there.
    /// Returns the PIN screen, or nil when one is already shown, there is no window, or it could not be presented.
    @discardableResult
    static func presentLock(
        on window: UIWindow?,
        lockState: ApplicationLockState = .shared,
        makePin: () -> UIViewController?
    ) -> UIViewController? {
        if case let .presented(pin) = showLock(on: window, lockState: lockState, makePin: makePin) {
            return pin
        }
        return nil
    }

    static func showLock(
        on window: UIWindow?,
        lockState: ApplicationLockState = .shared,
        makePin: () -> UIViewController?,
        afterDismissal: (() -> Void)? = nil
    ) -> LockPresentation {
        guard let window = window, let root = window.rootViewController else {
            return .noWindow
        }
        // The unlock PIN is already on screen; another one on top would ask for the PIN twice.
        if let shown = unlockPin(in: window) {
            return .alreadyShown(shown)
        }
        if root.presentedViewController != nil {
            // Screens open over the app go first. Even unanimated, the dismissal usually ends after this call, and
            // UIKit refuses (and only logs) a presentation from a controller that is still presenting: the PIN is
            // presented from the dismissal's completion instead.
            root.dismiss(animated: false, completion: afterDismissal)
            if root.presentedViewController != nil {
                return .dismissing
            }
        }
        guard let pincodeViewController = makePin() else {
            return .notPresented
        }

        root.present(pincodeViewController, animated: false)
        // UIKit declines a presentation during another transition and only logs it. The lock counts only once the
        // PIN screen is actually presented; otherwise it stays pending and is tried again.
        guard root.presentedViewController === pincodeViewController else {
            return .notPresented
        }
        // Prompts in their own windows, such as WalletConnect requests, stay
        // behind the PIN screen until it is unlocked.
        lockState.lock(with: pincodeViewController)
        return .presented(pincodeViewController)
    }

    static func isShowingUnlockPin(in window: UIWindow) -> Bool {
        unlockPin(in: window) != nil
    }

    private static func unlockPin(in window: UIWindow) -> UIViewController? {
        var controllers = [window.rootViewController].compactMap { $0 }
        while let presented = controllers.last?.presentedViewController {
            controllers.append(presented)
        }
        return controllers.first { ($0 as? PinSetupViewController)?.presenter is LocalAuthPresenter }
    }
}

extension FearlessApplication: ApplicationHandlerDelegate {
    func didReceiveDidEnterBackground(notification _: Notification) {
        timerToDetectInactivity?.invalidate()
        sessionLock.didEnterBackground()
    }

    func didReceiveWillEnterForeground(notification _: Notification) {
        resetTimer()
        // The scene usually got here first, before removing its app-switcher cover; this keeps a lock that is
        // still pending.
        sessionLock.willEnterForeground()
    }
}
