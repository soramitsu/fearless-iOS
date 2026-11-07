import Foundation

enum UtilityConstants {
    /// Foreground inactivity: no touches for this long asks for the PIN again.
    static let inactiveSessionDropTimeInSeconds: TimeInterval = 1200
    /// Time in the background after which returning to the app asks for the PIN. Every
    /// fund-moving confirm asks for the PIN or biometrics itself, so this guards what an
    /// unlocked wallet shows; five minutes keeps a quick app switch from dropping a form.
    static let backgroundSessionDropTimeInSeconds: TimeInterval = 300
}

/// Seconds since boot, counting the time the device spent asleep. Setting the clock does not move it; a reboot
/// restarts it from zero. `ProcessInfo.systemUptime` stops while the device sleeps, so it cannot measure how long a
/// locked phone sat with the wallet in the background.
enum MonotonicClock {
    static func uptime() -> TimeInterval {
        let nanoseconds = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
        guard nanoseconds > 0 else {
            return ProcessInfo.processInfo.systemUptime
        }
        return TimeInterval(nanoseconds) / 1_000_000_000
    }
}
