import UIKit

enum FWTier: String, CaseIterable {
    case full, lite, reduced
}

/// Full is selected by Automatic; the user can deliberately reduce the effects.
enum FWEffectsChoice: String, CaseIterable {
    case automatic, lite, reduced
}

/// Paint-only preferences. UIKit consumers and preference writes belong on the main thread.
final class FWEffects {
    struct SystemState: Equatable {
        var reduceTransparency = false
        var highContrast = false
        var reduceMotion = false
        var lowPower = false

        static var current: Self {
            Self(
                reduceTransparency: UIAccessibility.isReduceTransparencyEnabled,
                highContrast: UIAccessibility.isDarkerSystemColorsEnabled,
                reduceMotion: UIAccessibility.isReduceMotionEnabled,
                lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled
            )
        }
    }

    static let shared = FWEffects()
    static let didChange = Notification.Name("FWEffectsDidChange")
    static let preferenceKey = "fw.effects.v1"

    let notificationCenter: NotificationCenter
    private let defaults: UserDefaults
    private let readSystemState: () -> SystemState
    private var observations: [NSObjectProtocol] = []
    private var state: SystemState
    private var choice: FWEffectsChoice
    private(set) var tier: FWTier = .full

    var userChoice: FWEffectsChoice {
        get { choice }
        set {
            guard newValue != choice else { return }
            defaults.set(newValue.rawValue, forKey: Self.preferenceKey)
            refresh()
        }
    }

    var highContrast: Bool {
        state.highContrast
    }

    var reduceMotion: Bool {
        state.reduceMotion
    }

    init(
        defaults: UserDefaults = .standard,
        notificationCenter: NotificationCenter = .default,
        systemState: @escaping () -> SystemState = { .current }
    ) {
        self.defaults = defaults
        self.notificationCenter = notificationCenter
        readSystemState = systemState
        state = systemState()
        choice = defaults.string(forKey: Self.preferenceKey).flatMap(FWEffectsChoice.init(rawValue:)) ?? .automatic
        refresh()
        let names = [
            UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            UIAccessibility.darkerSystemColorsStatusDidChangeNotification,
            UIAccessibility.reduceMotionStatusDidChangeNotification,
            Notification.Name.NSProcessInfoPowerStateDidChange,
            UserDefaults.didChangeNotification
        ]
        // UserDefaults posts its change on the writing thread. A main-queue observer would make that write wait
        // for the main thread, which deadlocks a writer that holds a lock the main thread is waiting for.
        observations = names.map { name in
            notificationCenter.addObserver(forName: name, object: nil, queue: nil) { [weak self] _ in
                if Thread.isMainThread {
                    self?.refresh()
                } else {
                    DispatchQueue.main.async { self?.refresh() }
                }
            }
        }
    }

    deinit {
        observations.forEach(notificationCenter.removeObserver)
    }

    func paintReduced(calm: Bool = false) -> Bool {
        calm || tier == .reduced || highContrast
    }

    func allowsLiveBlur(calm: Bool = false) -> Bool {
        tier == .full && !paintReduced(calm: calm)
    }

    /// Refresh both system signals and preferences, including another window's UI preference change.
    func refresh() {
        let previousState = state
        let previousTier = tier
        let previousChoice = choice
        state = readSystemState()
        choice = defaults.string(forKey: Self.preferenceKey).flatMap(FWEffectsChoice.init(rawValue:)) ?? .automatic
        if state.reduceTransparency || state.highContrast || userChoice == .reduced {
            tier = .reduced
        } else if userChoice == .lite || state.lowPower {
            tier = .lite
        } else {
            tier = .full
        }
        if previousState != state || previousTier != tier || previousChoice != choice {
            notificationCenter.post(name: Self.didChange, object: self)
        }
    }
}
