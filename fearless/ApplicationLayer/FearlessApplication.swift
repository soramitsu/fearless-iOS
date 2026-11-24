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
/// A re-lock that cannot be shown at once, because the Keychain cannot yet say whether there is a PIN, because there
/// is no window, because screens open over the app are still being dismissed or because the PIN screen cannot be
/// presented, stays pending. Meanwhile `ApplicationLockState` counts the app as locked, so request prompts wait, and
/// an opaque cover that takes every touch, the keyboard and VoiceOver stays over the app. The lock is tried again
/// when a scene activates or comes to the foreground, when protected data becomes available, when a dismissal ends
/// and every `retryInterval` seconds. The cover goes only once UIKit reports the PIN presented and in its window.
/// Only a Keychain that answers "no PIN" ends a pending lock without the PIN: onboarding and the historical no-PIN
/// recovery stay as they were.
final class PendingSessionLock {
    enum Attempt: Equatable {
        /// No lock was pending.
        case idle
        /// The unlock PIN is presented and holds the lock.
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
    /// The PIN this request presented, the window it went to, and whether UIKit reported the presentation done.
    private weak var presentingPin: UIViewController?
    private weak var presentingWindow: UIWindow?
    private var presentationCompleted = false
    /// Set by `request()`: a PIN already on screen must start a fresh authentication for this lock.
    private var needsFreshAuthentication = false

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
        needsFreshAuthentication = true
        // Authentications that began before now do not end this lock.
        lockState.beginDueLock()
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

        let window = scene.flatMap { mainWindow($0) } ?? mainWindow(nil)
        if let pin = presentingPin, let target = presentingWindow, window == nil || window === target,
           pin.presentingViewController != nil, !pin.isBeingDismissed {
            if presentationCompleted, Self.isFrontmost(pin, in: target) {
                finish(restoringKeyWindow: false, window: target)
                return .locked
            }
            if presentationCompleted, pin.presentedViewController != nil {
                // Something was put over the PIN: it goes, and a later attempt checks again.
                pin.dismiss(animated: false)
            }
            // Still settling: the cover stays and a later attempt checks again.
            return .locked
        }
        // Not presented, gone, or the app's window changed: present again.
        presentingPin = nil
        presentingWindow = nil

        switch pinPresence() {
        case .absent:
            finish(restoringKeyWindow: true, window: nil)
            lockState.cancelPendingLock()
            return .noPin
        case .unknown:
            wait()
            return .waiting
        case .present:
            let presentation = FearlessApplication.showLock(
                on: window,
                lockState: lockState,
                makePin: { [weak self, weak window] in
                    let pin = self?.makePin()
                    // Known before presenting, in case UIKit reports the presentation finished at once.
                    self?.presentingPin = pin
                    self?.presentingWindow = window
                    self?.presentationCompleted = false
                    // A new PIN screen starts its own authentication.
                    self?.needsFreshAuthentication = false
                    return pin
                },
                afterDismissal: { [weak self] in self?.attempt(in: scene) },
                onPresented: { [weak self, weak window] pin in self?.didPresent(pin, in: window) }
            )
            switch presentation {
            case .presented:
                if isPending {
                    // Until UIKit reports the PIN presented and it is frontmost in its window, the cover stays (and
                    // goes up now if it was not), so the scene's app-switcher cover never comes off an open wallet.
                    cover.show(in: scenes())
                    scheduleRetry()
                }
                return .locked
            case let .alreadyShown(pin):
                // The PIN on screen becomes this lock's owner, so its unlock ends the lock and prompts are told.
                lockState.lock(with: pin)
                if needsFreshAuthentication {
                    needsFreshAuthentication = false
                    ((pin as? PinSetupViewController)?.presenter as? LocalAuthPresenter)?.restartAuthentication()
                }
                guard let window, Self.isFrontmost(pin, in: window) else {
                    // On screen per the chain but not settled or not visible: keep the cover and look again.
                    wait()
                    return .waiting
                }
                finish(restoringKeyWindow: false, window: window)
                return .locked
            case .noWindow, .dismissing, .notPresented:
                presentingPin = nil
                wait()
                return .waiting
            }
        }
    }

    private func didPresent(_ pin: UIViewController, in _: UIWindow?) {
        guard isPending, presentingPin === pin else {
            return
        }
        presentationCompleted = true
        // Checked on the next turn: UIKit may report the presentation before the PIN is in its window, and this can
        // run inside the attempt that presented it.
        DispatchQueue.main.async { [weak self] in
            self?.attempt()
        }
    }

    /// Presented in `window`, frontmost there, settled, and the window is visible.
    private static func isFrontmost(_ pin: UIViewController, in window: UIWindow) -> Bool {
        var frontmost = window.rootViewController
        while let presented = frontmost?.presentedViewController {
            frontmost = presented
        }
        return !window.isHidden && frontmost === pin && pin.viewIfLoaded?.window === window
            && !pin.isBeingPresented && !pin.isBeingDismissed
    }

    private func wait() {
        lockState.markLockPending()
        cover.show(in: scenes())
        scheduleRetry()
    }

    private func finish(restoringKeyWindow: Bool, window: UIWindow?) {
        isPending = false
        needsFreshAuthentication = false
        presentingPin = nil
        presentingWindow = nil
        presentationCompleted = false
        retryTimer?.invalidate()
        retryTimer = nil
        cover.hide(restoringKeyWindow: restoringKeyWindow)
        // The cover was key while it waited; the PIN's window takes the keyboard back.
        window?.makeKey()
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

/// The cover's window. Never a presenter: `SceneWindowFinder.activeWindow` skips it, so prompts that look for the top
/// screen wait instead of appearing on the cover.
final class SessionLockCoverWindow: UIWindow {}

/// An opaque window over every other window of the app, prompts included, that takes all touches, the keyboard and
/// VoiceOver while a timed re-lock waits to be shown. It is never left over the PIN screen.
final class SessionLockCover {
    /// Above the WalletConnect and IrohaConnect windows (`.alert + 1`), below the app-switcher cover.
    static let windowLevel = AppSwitcherSnapshotCover.windowLevel - 1

    private let notificationCenter: NotificationCenter
    private var windows: [SessionLockCoverWindow] = []
    private weak var previousKeyWindow: UIWindow?
    /// Windows whose VoiceOver elements the cover hid, with the value to restore.
    private let hiddenAccessibility = NSMapTable<UIWindow, NSNumber>.weakToStrongObjects()
    private var observers: [NSObjectProtocol] = []

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
    }

    deinit {
        observers.forEach { notificationCenter.removeObserver($0) }
    }

    var isShown: Bool {
        windows.contains { !$0.isHidden }
    }

    var shownWindows: [UIWindow] {
        windows.filter { !$0.isHidden }
    }

    func show(in scenes: [UIWindowScene]) {
        for scene in scenes where !windows.contains(where: { $0.windowScene === scene }) {
            if previousKeyWindow == nil {
                previousKeyWindow = scene.windows.first { $0.isKeyWindow }
            }
            let window = Self.makeWindow(in: scene)
            windows.append(window)
            // Nothing typed while the app waits for its lock reaches a field underneath.
            scene.windows.filter { $0 !== window }.forEach {
                $0.endEditing(true)
                hideAccessibility(of: $0)
            }
            window.makeKeyAndVisible()
        }
        observeWindowsIfNeeded()
    }

    func hide(restoringKeyWindow: Bool = true) {
        let wasKey = windows.contains { $0.isKeyWindow }
        observers.forEach { notificationCenter.removeObserver($0) }
        observers = []
        // Released, so a later lock starts from a fresh window with nothing presented on it.
        for window in windows {
            window.isHidden = true
            window.rootViewController = nil
        }
        windows = []
        for case let window as UIWindow in hiddenAccessibility.keyEnumerator().allObjects {
            window.accessibilityElementsHidden = hiddenAccessibility.object(forKey: window)?.boolValue ?? false
        }
        hiddenAccessibility.removeAllObjects()
        if restoringKeyWindow, wasKey, let previous = previousKeyWindow, !previous.isHidden {
            previous.makeKey()
        }
        previousKeyWindow = nil
    }

    private func hideAccessibility(of window: UIWindow) {
        guard !(window is SessionLockCoverWindow), hiddenAccessibility.object(forKey: window) == nil else {
            return
        }
        hiddenAccessibility.setObject(NSNumber(value: window.accessibilityElementsHidden), forKey: window)
        window.accessibilityElementsHidden = true
    }

    /// A prompt window that becomes key or visible while the cover is up gets neither the keyboard nor VoiceOver.
    private func observeWindowsIfNeeded() {
        guard observers.isEmpty, isShown else {
            return
        }
        let names = [UIWindow.didBecomeKeyNotification, UIWindow.didBecomeVisibleNotification]
        observers = names.map { name in
            notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                guard let self, let window = notification.object as? UIWindow,
                      !(window is SessionLockCoverWindow),
                      let cover = self.windows.first(where: { $0.windowScene === window.windowScene && !$0.isHidden }) else {
                    return
                }
                window.endEditing(true)
                self.hideAccessibility(of: window)
                if window.isKeyWindow {
                    cover.makeKey()
                }
            }
        }
    }

    private static func makeWindow(in scene: UIWindowScene) -> SessionLockCoverWindow {
        let window = SessionLockCoverWindow(windowScene: scene)
        window.windowLevel = windowLevel
        window.isUserInteractionEnabled = true
        window.backgroundColor = R.color.colorBlack() ?? .black
        window.rootViewController = SessionLockCoverViewController()
        window.accessibilityViewIsModal = true
        return window
    }
}

/// The launch screen, opaque, taking every touch and hiding the app from VoiceOver.
final class SessionLockCoverViewController: UIViewController {
    override func loadView() {
        let view = UIView()
        view.backgroundColor = R.color.colorBlack() ?? .black
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
        afterDismissal: (() -> Void)? = nil,
        onPresented: ((UIViewController) -> Void)? = nil
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

        root.present(pincodeViewController, animated: false) { [weak pincodeViewController] in
            if let pincodeViewController {
                onPresented?(pincodeViewController)
            }
        }
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

    /// The unlock PIN counts as shown only as the frontmost screen and while nothing in the chain is being dismissed:
    /// a PIN leaving after an unlock must not stand in for a new lock.
    private static func unlockPin(in window: UIWindow) -> UIViewController? {
        var controllers = [window.rootViewController].compactMap { $0 }
        while let presented = controllers.last?.presentedViewController {
            controllers.append(presented)
        }
        guard let frontmost = controllers.last,
              (frontmost as? PinSetupViewController)?.presenter is LocalAuthPresenter,
              !controllers.contains(where: { $0.isBeingDismissed }) else {
            return nil
        }
        return frontmost
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
