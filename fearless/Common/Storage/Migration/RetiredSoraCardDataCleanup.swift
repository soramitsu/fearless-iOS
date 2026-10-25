import Foundation
import SoraKeystore

enum RetiredSoraCardDataCleanupOutcome: Equatable {
    case alreadyCompleted
    case completed
    case retryOnNextLaunch
}

/// Removes what the retired SORA Card feature left on upgraded devices.
///
/// Builds that shipped SORA Card kept the PayWings session in the Keychain secret
/// `SCAccessToken` and four flags in `UserDefaults.standard`. This removes exactly
/// those, once, and records completion only after the Keychain confirms the token
/// is gone; a failed or deferred attempt repeats on the next launch.
///
/// It never queries the Keychain broadly and never touches wallet keys: the token
/// is removed by its exact identifier through the same `SecretStoreManagerProtocol`
/// (`KeychainManager`) that stored it.
final class RetiredSoraCardDataCleanup {
    static let accessTokenIdentifier = "SCAccessToken"
    static let userDefaultsKeys = ["SCKycId", "SCIsHidden", "SCIsRetry", "SCIsAppStarted"]
    static let completionKey = "retiredSoraCardDataCleanupCompleted"

    private let secretManager: SecretStoreManagerProtocol
    private let keystore: KeystoreProtocol
    private let settings: SettingsManagerProtocol
    private let protectedDataAvailabilityMonitor: RootProtectedDataAvailabilityMonitoring
    private let workQueue: DispatchQueue
    private let logger: LoggerProtocol?

    private let lock = NSLock()
    private var protectedDataObservation: RootProtectedDataAvailabilityObservation?
    private var completionsAwaitingProtectedData: [(RetiredSoraCardDataCleanupOutcome) -> Void] = []

    init(
        secretManager: SecretStoreManagerProtocol = KeychainManager.shared,
        keystore: KeystoreProtocol = Keychain(),
        settings: SettingsManagerProtocol = SettingsManager.shared,
        protectedDataAvailabilityMonitor: RootProtectedDataAvailabilityMonitoring =
            RootUIApplicationProtectedDataAvailabilityMonitor(),
        workQueue: DispatchQueue = DispatchQueue(
            label: "jp.co.soramitsu.fearlesswallet.retired-sora-card-cleanup",
            qos: .utility
        ),
        logger: LoggerProtocol? = Logger.shared
    ) {
        self.secretManager = secretManager
        self.keystore = keystore
        self.settings = settings
        self.protectedDataAvailabilityMonitor = protectedDataAvailabilityMonitor
        self.workQueue = workQueue
        self.logger = logger
    }

    deinit {
        protectedDataObservation?.invalidate()
    }

    /// Call on the main queue: protected data availability is read from `UIApplication`.
    /// The completion runs on the cleanup's work queue.
    func runIfNeeded(completion: ((RetiredSoraCardDataCleanupOutcome) -> Void)? = nil) {
        // The token was stored `WhenUnlockedThisDeviceOnly` and UserDefaults can be
        // unreadable before the first unlock, so wait for protected data instead of
        // reading or writing anything early.
        guard protectedDataAvailabilityMonitor.isProtectedDataAvailable else {
            waitForProtectedData(completion: completion)
            return
        }

        workQueue.async { [self] in
            perform { outcome in
                completion?(outcome)
            }
        }
    }

    private func waitForProtectedData(completion: ((RetiredSoraCardDataCleanupOutcome) -> Void)?) {
        let observation = protectedDataAvailabilityMonitor.observeDidBecomeAvailable { [weak self] in
            self?.protectedDataDidBecomeAvailable()
        }

        lock.lock()
        let previousObservation = protectedDataObservation
        protectedDataObservation = observation
        if let completion = completion {
            completionsAwaitingProtectedData.append(completion)
        }
        lock.unlock()

        previousObservation?.invalidate()

        // Data may have become available before the observation was registered.
        if protectedDataAvailabilityMonitor.isProtectedDataAvailable {
            protectedDataDidBecomeAvailable()
        }
    }

    private func protectedDataDidBecomeAvailable() {
        lock.lock()
        guard let observation = protectedDataObservation else {
            lock.unlock()
            return
        }
        protectedDataObservation = nil
        let completions = completionsAwaitingProtectedData
        completionsAwaitingProtectedData = []
        lock.unlock()

        observation.invalidate()

        runIfNeeded { outcome in
            completions.forEach { $0(outcome) }
        }
    }

    private func perform(completion: @escaping (RetiredSoraCardDataCleanupOutcome) -> Void) {
        guard settings.bool(for: Self.completionKey) != true else {
            completion(.alreadyCompleted)
            return
        }

        Self.userDefaultsKeys.forEach { settings.removeValue(for: $0) }

        secretManager.removeSecret(
            for: Self.accessTokenIdentifier,
            completionQueue: workQueue
        ) { [self] _ in
            completion(confirmTokenRemoval())
        }
    }

    private func confirmTokenRemoval() -> RetiredSoraCardDataCleanupOutcome {
        // `removeSecret` reports `false` both for a missing token and for a failed
        // delete, so ask the Keychain directly; only "not found" counts as removed.
        let tokenRemains: Bool
        do {
            tokenRemains = try keystore.checkKey(for: Self.accessTokenIdentifier)
        } catch {
            logger?.warning("Retired SORA Card token could not be checked; will retry on next launch")
            return .retryOnNextLaunch
        }

        guard !tokenRemains else {
            logger?.warning("Retired SORA Card token is still stored; will retry on next launch")
            return .retryOnNextLaunch
        }

        settings.set(value: true, for: Self.completionKey)
        logger?.info("Removed retired SORA Card data")
        return .completed
    }
}
