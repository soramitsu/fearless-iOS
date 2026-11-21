import Foundation
import SoraKeystore

/// Consecutive wrong PINs and the lockout they started.
struct PincodeAttemptRecord: Codable, Equatable {
    /// Wrong PINs since the last correct one.
    var failures: Int
    /// Wall-clock end of the lockout, in seconds since 1970. Equal to `anchorDate` when there is none.
    var lockedUntil: TimeInterval
    /// Wall-clock time when the lockout last started or restarted.
    var anchorDate: TimeInterval
    /// `MonotonicClock.uptime()` at `anchorDate`. Setting the clock does not move it; a reboot invalidates it.
    var anchorUptime: TimeInterval

    static let empty = PincodeAttemptRecord(failures: 0, lockedUntil: 0, anchorDate: 0, anchorUptime: 0)
}

enum PincodeLockoutPolicy {
    /// Five free attempts. The 6th wrong PIN locks for 1 min, the 7th for 5 min, the 8th for 15 min, later ones 1 h.
    static func lockoutDuration(afterFailures failures: Int) -> TimeInterval {
        switch failures {
        case ..<6:
            return 0
        case 6:
            return 60
        case 7:
            return 5 * 60
        case 8:
            return 15 * 60
        default:
            return 60 * 60
        }
    }

    static func recordingFailure(
        to record: PincodeAttemptRecord,
        now: TimeInterval,
        uptime: TimeInterval
    ) -> PincodeAttemptRecord {
        let failures = record.failures == Int.max ? Int.max : record.failures + 1
        return PincodeAttemptRecord(
            failures: failures,
            lockedUntil: now + lockoutDuration(afterFailures: failures),
            anchorDate: now,
            anchorUptime: uptime
        )
    }

    /// Seconds of lockout left, and the record to store when this reading changed it.
    ///
    /// A lockout never ends early. Setting the wall clock forward does not move the monotonic clock, a wall clock set
    /// behind the last wrong PIN is ignored, and after a reboot the monotonic clock cannot vouch for the time that
    /// passed, so an unfinished lockout restarts at its full length. A lockout seen to end on this boot is recorded as
    /// ended, so a later reboot cannot bring it back; the count of wrong PINs stays until a correct PIN.
    static func remaining(
        in record: PincodeAttemptRecord,
        now: TimeInterval,
        uptime: TimeInterval
    ) -> (seconds: TimeInterval, updated: PincodeAttemptRecord?) {
        let length = record.lockedUntil - record.anchorDate
        guard length > 0 else {
            return (0, nil)
        }
        let rebooted = uptime < record.anchorUptime
        let clockMovedBack = now < record.anchorDate
        let monotonicLeft = rebooted ? length : record.anchorUptime + length - uptime
        let wallLeft = clockMovedBack ? monotonicLeft : record.lockedUntil - now
        let left = min(length, max(monotonicLeft, wallLeft))
        var updated = record
        guard left > 0 else {
            updated.lockedUntil = updated.anchorDate
            return (0, updated)
        }
        guard rebooted || clockMovedBack else {
            return (left, nil)
        }
        updated.anchorDate = now
        updated.anchorUptime = uptime
        updated.lockedUntil = now + left
        return (left, updated)
    }
}

protocol PincodeAttemptLimiting: AnyObject {
    /// Seconds left in the current lockout; zero when a PIN may be checked now.
    func remainingLockout() -> TimeInterval
    /// Counts a wrong PIN and returns the lockout it starts, zero during the free attempts.
    @discardableResult
    func registerFailure() -> TimeInterval
    /// Clears the count after a correct PIN or a newly saved PIN. A biometric success never clears it.
    func reset()
}

/// Keeps the count in the Keychain under its own tag, so app and device restarts do not reset it. It never reads or
/// changes the PIN, keys, or wallets, and failures never delete anything.
final class PincodeAttemptLimiter: PincodeAttemptLimiting {
    static let shared = PincodeAttemptLimiter()

    private let keystore: KeystoreProtocol
    private let now: () -> TimeInterval
    private let uptime: () -> TimeInterval
    private let tag = KeystoreTag.pincodeAttempts.rawValue
    private let lock = NSLock()
    /// The latest record this process wrote. A wrong PIN still counts here when its Keychain write failed.
    private var written: PincodeAttemptRecord?

    init(
        keystore: KeystoreProtocol = Keychain(),
        now: @escaping () -> TimeInterval = { Date().timeIntervalSince1970 },
        uptime: @escaping () -> TimeInterval = MonotonicClock.uptime
    ) {
        self.keystore = keystore
        self.now = now
        self.uptime = uptime
    }

    func remainingLockout() -> TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        let result = PincodeLockoutPolicy.remaining(in: currentRecord(), now: now(), uptime: uptime())
        if let updated = result.updated {
            store(updated)
        }
        return result.seconds
    }

    @discardableResult
    func registerFailure() -> TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        let record = PincodeLockoutPolicy.recordingFailure(to: currentRecord(), now: now(), uptime: uptime())
        store(record)
        return record.lockedUntil - record.anchorDate
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        do {
            try keystore.deleteKeyIfExists(for: tag)
            written = .empty
        } catch {
            store(.empty)
        }
    }

    private func currentRecord() -> PincodeAttemptRecord {
        let stored: PincodeAttemptRecord?
        do {
            if try keystore.checkKey(for: tag) {
                let data = try keystore.fetchKey(for: tag)
                // Undecodable data cannot come from another writer; it is replaced by the next write.
                stored = (try? JSONDecoder().decode(PincodeAttemptRecord.self, from: data)) ?? .empty
            } else {
                stored = .empty
            }
        } catch {
            stored = nil
        }
        guard let stored else {
            return written ?? .empty
        }
        guard let written, written.failures > stored.failures else {
            return stored
        }
        return written
    }

    private func store(_ record: PincodeAttemptRecord) {
        written = record
        guard let data = try? JSONEncoder().encode(record) else {
            return
        }
        try? keystore.saveKey(data, with: tag)
    }
}

enum PincodeComparison {
    /// The time taken depends only on the lengths, not on the position of the first wrong digit.
    static func matches(_ entered: String, _ stored: String) -> Bool {
        let lhs = Array(entered.utf8)
        let rhs = Array(stored.utf8)
        guard lhs.count == rhs.count else {
            return false
        }
        var difference: UInt8 = 0
        for index in lhs.indices {
            difference |= lhs[index] ^ rhs[index]
        }
        return difference == 0
    }
}

class LocalAuthInteractor {
    enum LocalAuthState {
        case waitingPincode
        case checkingPincode
        case checkingBiometry
        case completed
        case unexpectedFail
    }

    private weak var presenter: LocalAuthInteractorOutputProtocol?
    private(set) var secretManager: SecretStoreManagerProtocol
    private(set) var settingsManager: SettingsManagerProtocol
    private(set) var biometryAuth: BiometryAuthProtocol
    private(set) var locale: Locale
    private(set) var state = LocalAuthState.waitingPincode
    private(set) var pincode: String?
    private var generation: UInt64 = 0
    private let attemptLimiter: PincodeAttemptLimiting
    private let enrollmentGuard: BiometryEnrollmentGuarding

    init(
        secretManager: SecretStoreManagerProtocol,
        settingsManager: SettingsManagerProtocol,
        biometryAuth: BiometryAuthProtocol,
        locale: Locale,
        attemptLimiter: PincodeAttemptLimiting = PincodeAttemptLimiter.shared,
        enrollmentGuard: BiometryEnrollmentGuarding = BiometryEnrollmentGuard.shared
    ) {
        self.secretManager = secretManager
        self.settingsManager = settingsManager
        self.biometryAuth = biometryAuth
        self.locale = locale
        self.attemptLimiter = attemptLimiter
        self.enrollmentGuard = enrollmentGuard
    }

    // State and ownership live on the main queue, including replies from secret/biometric providers.
    private func onMain(_ action: @escaping () -> Void) {
        if Thread.isMainThread { action() } else { DispatchQueue.main.async(execute: action) }
    }

    private func changeState(to next: LocalAuthState) {
        guard state != next else { return }
        state = next
        presenter?.didChangeState(to: next)
    }

    private func deliver(_ attempt: UInt64, action: @escaping (LocalAuthInteractorOutputProtocol) -> Void) {
        DispatchQueue.main.async { [weak self, weak output = presenter] in
            guard let self = self, self.generation == attempt, let output = output,
                  self.presenter === output else { return }
            action(output)
        }
    }

    private func reportLockout(attempt: UInt64) {
        let remaining = attemptLimiter.remainingLockout()
        guard remaining > 0 else { return }
        deliver(attempt) { $0.didReceiveLockout(remaining: remaining) }
    }

    private func performBiometryAuth(attempt: UInt64) {
        guard generation == attempt, state == .checkingBiometry else { return }
        // A face or finger enrolled after the last correct PIN cannot stand in for the PIN.
        guard settingsManager.biometryEnabled == true, biometryAuth.availableBiometryType != .none,
              enrollmentGuard.isCurrentEnrollmentTrusted() else {
            changeState(to: .waitingPincode)
            return
        }
        biometryAuth.authenticate(
            localizedReason: R.string.localizable.askBiometryReason(preferredLanguages: locale.rLanguages),
            completionQueue: .main
        ) { [weak self] result in
            self?.onMain { [weak self] in
                self?.processBiometryAuth(result: result, attempt: attempt)
            }
        }
    }

    private func processBiometryAuth(result: Bool, attempt: UInt64) {
        guard generation == attempt, state == .checkingBiometry else { return }
        // The enrollment is checked again after the prompt. A trusted biometric success is allowed during a PIN
        // lockout, which only limits PIN guesses, and it never clears the count of wrong PINs.
        let accepted = result && enrollmentGuard.isCurrentEnrollmentTrusted()
        changeState(to: accepted ? .completed : .waitingPincode)
        if accepted { deliver(attempt) { $0.didCompleteAuth() } }
    }

    private func processStored(pin stored: String?, attempt: UInt64) {
        guard generation == attempt, state == .checkingPincode else { return }
        let entered = pincode
        pincode = nil
        guard let stored = stored, let entered = entered else {
            // An unreadable stored PIN is not the user's mistake, so it does not count as an attempt.
            changeState(to: .waitingPincode)
            deliver(attempt) { $0.didEnterWrongPincode() }
            return
        }
        let lockout = attemptLimiter.remainingLockout()
        guard lockout <= 0 else {
            // Another PIN screen started a lockout while this PIN was loading: it is not compared.
            changeState(to: .waitingPincode)
            deliver(attempt) { $0.didReceiveLockout(remaining: lockout) }
            return
        }
        guard PincodeComparison.matches(entered, stored) else {
            let nextLockout = attemptLimiter.registerFailure()
            changeState(to: .waitingPincode)
            deliver(attempt) { output in
                output.didEnterWrongPincode()
                if nextLockout > 0 { output.didReceiveLockout(remaining: nextLockout) }
            }
            return
        }
        attemptLimiter.reset()
        enrollmentGuard.trustCurrentEnrollment()
        changeState(to: .completed)
        deliver(attempt) { $0.didCompleteAuth() }
    }
}

extension LocalAuthInteractor: LocalAuthInteractorInputProtocol {
    var availableBiometryType: AvailableBiometryType {
        biometryAuth.availableBiometryType
    }

    var allowManualBiometryAuth: Bool {
        let touchOrFaceId = availableBiometryType == .touchId || availableBiometryType == .faceId
        return settingsManager.biometryEnabled == true && touchOrFaceId &&
            enrollmentGuard.isCurrentEnrollmentTrusted()
    }

    func startAuth(with output: LocalAuthInteractorOutputProtocol) {
        onMain { [weak self] in
            guard let self = self else { return }
            if self.presenter !== output {
                self.generation &+= 1
                self.biometryAuth.cancelAuthentication()
                self.pincode = nil
                self.state = .waitingPincode
                self.presenter = output
            }
            guard self.state == .waitingPincode else { return }
            self.generation &+= 1
            let attempt = self.generation
            self.reportLockout(attempt: attempt)
            self.changeState(to: .checkingBiometry)
            self.performBiometryAuth(attempt: attempt)
        }
    }

    func process(pin: String) {
        onMain { [weak self] in
            guard let self = self, self.presenter != nil,
                  self.state == .waitingPincode || self.state == .checkingBiometry else { return }
            let lockout = self.attemptLimiter.remainingLockout()
            guard lockout <= 0 else {
                // Refused before the stored PIN is read: a guess made during a lockout is never compared.
                self.deliver(self.generation) { $0.didReceiveLockout(remaining: lockout) }
                return
            }
            self.generation &+= 1
            self.biometryAuth.cancelAuthentication()
            let attempt = self.generation
            self.pincode = pin
            self.changeState(to: .checkingPincode)
            guard self.generation == attempt, self.state == .checkingPincode else { return }
            self.secretManager.loadSecret(
                for: KeystoreTag.pincode.rawValue,
                completionQueue: .main
            ) { [weak self] secret in
                self?.onMain { [weak self] in
                    self?.processStored(pin: secret?.toUTF8String(), attempt: attempt)
                }
            }
        }
    }

    func cancelAuth() {
        onMain { [weak self] in
            guard let self = self else { return }
            self.generation &+= 1
            self.biometryAuth.cancelAuthentication()
            self.pincode = nil
            self.presenter = nil
            self.state = .waitingPincode
        }
    }
}
