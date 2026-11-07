import Foundation
import Security
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

enum RetiredWalletConnectDataCleanupOutcome: Equatable {
    case alreadyCompleted
    case completed
    case retryOnNextLaunch
}

/// Removes what WalletConnect left on upgraded devices.
///
/// WalletConnect was removed because its SDK (reown-swift) is not open source. Releases
/// 3.0.5 to 4.2.x kept its relay session material as generic passwords under the service
/// `com.walletconnect.sdk`: in the app's default access group up to 4.1.0 and in the app
/// group since 4.2.0. Its session and pairing records lived in `UserDefaults.standard` and
/// in the app group's suite. None of it is wallet key material: wallet keys are
/// `kSecClassKey` items, and this never touches that class.
///
/// The Keychain delete names only the class and the service, with no access group, so it
/// reaches every group the app can access. Completion is recorded only after the Keychain
/// reports success or "not found"; anything else repeats on the next launch.
final class RetiredWalletConnectDataCleanup {
    static let keychainService = "com.walletconnect.sdk"
    static let userDefaultsKeyPrefix = "com.walletconnect."
    /// Markers the SDK wrote into the group suite after moving one of its stores there.
    static let groupMigrationMarkerPrefix = "hasMigratedToGroup_com.walletconnect."
    /// The app's own record of sessions kept by releases before 4.2.0.
    static let legacySessionsKey = "walletconnect.legacy_sessions.v1"
    static let completionKey = "retiredWalletConnectDataCleanupCompleted"

    static let productionBundleIdentifier = "jp.co.soramitsu.fearlesswallet"
    static let developmentBundleIdentifier = "jp.co.soramitsu.fearlesswallet.dev"
    static let productionGroupIdentifier = "group.jp.co.soramitsu.fearlesswallet"
    static let developmentGroupIdentifier = "group.jp.co.soramitsu.fearlesswallet.walletconnect"

    private let standardDefaults: UserDefaults
    private let groupDefaults: UserDefaults?
    private let deleteKeychainItems: () -> OSStatus
    private let protectedDataAvailabilityMonitor: RootProtectedDataAvailabilityMonitoring
    private let workQueue: DispatchQueue
    private let logger: LoggerProtocol?

    private let lock = NSLock()
    private var protectedDataObservation: RootProtectedDataAvailabilityObservation?
    private var completionsAwaitingProtectedData: [(RetiredWalletConnectDataCleanupOutcome) -> Void] = []

    init(
        standardDefaults: UserDefaults = .standard,
        groupDefaults: UserDefaults? = RetiredWalletConnectDataCleanup
            .groupIdentifier(bundleIdentifier: Bundle.main.bundleIdentifier)
            .flatMap { UserDefaults(suiteName: $0) },
        deleteKeychainItems: @escaping () -> OSStatus =
            RetiredWalletConnectDataCleanup.deleteWalletConnectKeychainItems,
        protectedDataAvailabilityMonitor: RootProtectedDataAvailabilityMonitoring =
            RootUIApplicationProtectedDataAvailabilityMonitor(),
        workQueue: DispatchQueue = DispatchQueue(
            label: "jp.co.soramitsu.fearlesswallet.retired-walletconnect-cleanup",
            qos: .utility
        ),
        logger: LoggerProtocol? = Logger.shared
    ) {
        self.standardDefaults = standardDefaults
        self.groupDefaults = groupDefaults
        self.deleteKeychainItems = deleteKeychainItems
        self.protectedDataAvailabilityMonitor = protectedDataAvailabilityMonitor
        self.workQueue = workQueue
        self.logger = logger
    }

    deinit {
        protectedDataObservation?.invalidate()
    }

    /// The app group WalletConnect used for this application identity, if any.
    static func groupIdentifier(bundleIdentifier: String?) -> String? {
        if bundleIdentifier == productionBundleIdentifier {
            return productionGroupIdentifier
        }

        if bundleIdentifier == developmentBundleIdentifier {
            return developmentGroupIdentifier
        }

        return nil
    }

    /// WalletConnect's generic passwords only: the class and the service, with no access
    /// group, so the delete covers the app group and the default group alike. Never a whole
    /// class, and never `kSecClassKey`, where wallet keys live.
    static func deleteWalletConnectKeychainItems() -> OSStatus {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService
        ]
        return SecItemDelete(query as CFDictionary)
    }

    /// Call on the main queue: protected data availability is read from `UIApplication`.
    /// The completion runs on the cleanup's work queue.
    func runIfNeeded(completion: ((RetiredWalletConnectDataCleanupOutcome) -> Void)? = nil) {
        // The SDK stored its keys `AfterFirstUnlockThisDeviceOnly` and UserDefaults can be
        // unreadable before the first unlock, so wait for protected data instead of
        // reading or deleting anything early.
        guard protectedDataAvailabilityMonitor.isProtectedDataAvailable else {
            waitForProtectedData(completion: completion)
            return
        }

        workQueue.async { [self] in
            let outcome = perform()
            completion?(outcome)
        }
    }

    private func waitForProtectedData(completion: ((RetiredWalletConnectDataCleanupOutcome) -> Void)?) {
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

    private func perform() -> RetiredWalletConnectDataCleanupOutcome {
        guard !standardDefaults.bool(forKey: Self.completionKey) else {
            return .alreadyCompleted
        }

        let status = deleteKeychainItems()
        guard status == errSecSuccess || status == errSecItemNotFound else {
            logger?.warning("Retired WalletConnect keys could not be removed (\(status)); will retry on next launch")
            return .retryOnNextLaunch
        }

        Self.removeKeys(from: standardDefaults) { key in
            key.hasPrefix(Self.userDefaultsKeyPrefix) || key == Self.legacySessionsKey
        }

        if let groupDefaults = groupDefaults {
            Self.removeKeys(from: groupDefaults) { key in
                key.hasPrefix(Self.userDefaultsKeyPrefix) || key.hasPrefix(Self.groupMigrationMarkerPrefix)
            }
        }

        standardDefaults.set(true, forKey: Self.completionKey)
        logger?.info("Removed retired WalletConnect data")
        return .completed
    }

    private static func removeKeys(from defaults: UserDefaults, where shouldRemove: (String) -> Bool) {
        for key in defaults.dictionaryRepresentation().keys where shouldRemove(key) {
            defaults.removeObject(forKey: key)
        }
    }
}
