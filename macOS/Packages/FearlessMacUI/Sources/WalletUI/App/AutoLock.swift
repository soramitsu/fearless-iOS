import AppKit
import Foundation

/// When the app locks on its own.
struct AutoLockPolicy: Equatable, Sendable {
    /// Idle minutes before locking; 0 means never.
    var idleMinutes: Int
    var lockOnSleep: Bool
    var lockOnScreenLock: Bool

    enum Event: Sendable {
        case systemWillSleep
        case screenLocked
    }

    /// True when the app has been idle for at least the configured time.
    func shouldLock(lastActivity: Date, now: Date) -> Bool {
        guard idleMinutes > 0 else { return false }
        return now.timeIntervalSince(lastActivity) >= TimeInterval(idleMinutes) * 60
    }

    func shouldLock(on event: Event) -> Bool {
        switch event {
        case .systemWillSleep: return lockOnSleep
        case .screenLocked: return lockOnScreenLock
        }
    }

    /// Seconds until the idle lock would fire, or nil when it never does.
    func secondsUntilLock(lastActivity: Date, now: Date) -> TimeInterval? {
        guard idleMinutes > 0 else { return nil }
        return max(0, TimeInterval(idleMinutes) * 60 - now.timeIntervalSince(lastActivity))
    }
}

/// Watches for sleep, screen lock and idleness and asks the app to lock.
/// The decisions live in `AutoLockPolicy`; this type only gathers events.
@MainActor
final class AutoLockController {
    private let policy: () -> AutoLockPolicy
    private let isUnlocked: () -> Bool
    private let lock: () -> Void
    private let now: () -> Date

    private(set) var lastActivity: Date
    private var timer: Timer?
    private var eventMonitor: Any?
    private var observers: [(center: NotificationCenter, token: NSObjectProtocol)] = []

    init(
        policy: @escaping () -> AutoLockPolicy,
        isUnlocked: @escaping () -> Bool,
        lock: @escaping () -> Void,
        now: @escaping () -> Date = Date.init
    ) {
        self.policy = policy
        self.isUnlocked = isUnlocked
        self.lock = lock
        self.now = now
        lastActivity = now()
    }

    /// Starts listening to the system. Safe to call once per process.
    func start() {
        guard timer == nil else { return }
        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.willSleepNotification) { controller in controller.handle(.systemWillSleep) }
        let distributed = DistributedNotificationCenter.default()
        observe(distributed, Notification.Name("com.apple.screenIsLocked")) { controller in controller.handle(.screenLocked) }

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel]) { [weak self] event in
            MainActor.assumeIsolated { self?.noteActivity() }
            return event
        }
        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = 2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
        eventMonitor = nil
        for observer in observers { observer.center.removeObserver(observer.token) }
        observers = []
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, _ action: @escaping @MainActor (AutoLockController) -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                action(self)
            }
        }
        observers.append((center, token))
    }

    /// The user did something in the app.
    func noteActivity() {
        lastActivity = now()
    }

    /// Locks if the app has been idle long enough.
    func tick() {
        guard isUnlocked() else {
            lastActivity = now()
            return
        }
        if policy().shouldLock(lastActivity: lastActivity, now: now()) {
            lock()
        }
    }

    func handle(_ event: AutoLockPolicy.Event) {
        guard isUnlocked(), policy().shouldLock(on: event) else { return }
        lock()
    }
}
