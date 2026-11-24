import Foundation
import LocalAuthentication
import SoraKeystore
import UIKit

/// Wallet secrets that need the device owner (docs/wallet-secret-user-presence.md, step 2).
///
/// On only when this build compiles it in **and** the remote `protected_keychain_enabled` switch
/// has not vetoed it. A veto stops new migrations and new PIN verifiers; it never makes a migrated
/// wallet unreadable, because the router stays installed for every migrated wallet.
enum ProtectedKeychainPolicy {
    /// Off until the owner has approved the prompts (design doc, section 7).
    static let isCompiledIn = false
    /// Debug builds may turn it on for device testing: launch argument `-FearlessProtectedKeychain YES`.
    static let debugOverrideKey = "FearlessProtectedKeychain"

    static var isEnabled: Bool {
        isEnabled(compiledIn: isCompiledIn || isDebugOverrideOn, remote: MultiChainFeaturePolicy.current)
    }

    static func isEnabled(compiledIn: Bool, remote: FeatureToggleConfig) -> Bool {
        compiledIn && remote.protectedKeychainEnabled
    }

    private static var isDebugOverrideOn: Bool {
        #if DEBUG
            return UserDefaults.standard.bool(forKey: debugOverrideKey)
        #else
            return false
        #endif
    }
}

/// Asks iOS whether the device owner is present.
protocol DeviceOwnerAuthorizing: AnyObject {
    /// False when the device has no passcode: protected items cannot be created and migration waits.
    var isPasscodeSet: Bool { get }
    /// Shows the system sheet (Face ID, Touch ID or passcode) and returns the evaluated context.
    /// Blocks the calling thread, which must not be the main thread.
    func evaluate(reason: String) throws -> LAContext
}

final class SystemDeviceOwnerAuthorizer: DeviceOwnerAuthorizing {
    var isPasscodeSet: Bool {
        let context = LAContext()
        defer { context.invalidate() }
        var error: NSError?
        let available = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
        if let error, error.code == LAError.passcodeNotSet.rawValue {
            return false
        }
        return available
    }

    func evaluate(reason: String) throws -> LAContext {
        guard !Thread.isMainThread else {
            throw ProtectedKeychainError.interactionNotAllowed
        }
        let context = LAContext()
        let done = DispatchSemaphore(value: 0)
        var outcome: Result<Void, ProtectedKeychainError> = .failure(.canceled)
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
            outcome = success ? .success(()) : .failure(Self.map(error))
            done.signal()
        }
        done.wait()
        switch outcome {
        case .success:
            return context
        case let .failure(error):
            context.invalidate()
            throw error
        }
    }

    private static func map(_ error: Error?) -> ProtectedKeychainError {
        guard let error = error as? LAError else {
            return .authenticationFailed
        }
        switch error.code {
        case .userCancel, .appCancel, .systemCancel, .userFallback:
            return .canceled
        case .passcodeNotSet:
            return .passcodeNotSet
        default:
            return .authenticationFailed
        }
    }
}

/// The device-owner context of the wallet operation in progress, so one operation shows one
/// system sheet however many items it reads.
///
/// A context is adopted after a protected read evaluated one, after an explicit evaluation, or
/// after the app's own biometric check succeeded. It is reused for at most `reuseWindow`
/// seconds and invalidated at once when the app goes to the background; the next operation
/// gets a fresh one.
final class WalletSecretAuthorization {
    static let shared = WalletSecretAuthorization()
    static let reuseWindow: TimeInterval = 10

    private let lock = NSLock()
    /// Held while a system sheet is up, so concurrent reads wait for it instead of opening more.
    private let evaluationLock = NSLock()
    private var context: LAContext?
    private var adoptedAt: Date?
    private var accepting = false
    private let now: () -> Date
    private let notificationCenter: NotificationCenter
    private var observer: NSObjectProtocol?

    init(now: @escaping () -> Date = Date.init, notificationCenter: NotificationCenter = .default) {
        self.now = now
        self.notificationCenter = notificationCenter
        observer = notificationCenter.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.invalidate()
        }
    }

    deinit {
        observer.map(notificationCenter.removeObserver)
        context?.invalidate()
    }

    /// True while protected items may exist: only then does the app keep evaluated contexts.
    var isAccepting: Bool {
        lock.lock()
        defer { lock.unlock() }
        return accepting
    }

    func setAccepting(_ value: Bool) {
        lock.lock()
        accepting = value
        lock.unlock()
        if !value {
            invalidate()
        }
    }

    /// Keeps `context`, already evaluated by the device owner, for the operation in progress.
    func adopt(_ context: LAContext) {
        lock.lock()
        guard accepting else {
            lock.unlock()
            context.invalidate()
            return
        }
        let previous = self.context
        self.context = context
        adoptedAt = now()
        lock.unlock()
        if previous !== context {
            previous?.invalidate()
        }
    }

    /// The adopted context while it is fresh.
    func currentContext() -> LAContext? {
        lock.lock()
        defer { lock.unlock() }
        guard let context, let adoptedAt else {
            return nil
        }
        let age = now().timeIntervalSince(adoptedAt)
        guard age >= 0, age <= Self.reuseWindow else {
            context.invalidate()
            self.context = nil
            self.adoptedAt = nil
            return nil
        }
        return context
    }

    func invalidate() {
        lock.lock()
        let context = self.context
        self.context = nil
        adoptedAt = nil
        lock.unlock()
        context?.invalidate()
    }

    /// The context a protected read uses: the adopted one, or one the device owner approves now.
    /// On the main thread with none adopted it returns a fresh, unevaluated context carrying the
    /// reason: the keychain then shows the sheet itself.
    func context(reason: String, authorizer: DeviceOwnerAuthorizing) throws -> LAContext {
        if let context = currentContext() {
            return context
        }
        guard !Thread.isMainThread else {
            let context = LAContext()
            context.localizedReason = reason
            return context
        }
        evaluationLock.lock()
        defer { evaluationLock.unlock() }
        // Another read may have been approved while this one waited.
        if let context = currentContext() {
            return context
        }
        let context = try authorizer.evaluate(reason: reason)
        if isAccepting {
            adopt(context)
        }
        return context
    }
}
