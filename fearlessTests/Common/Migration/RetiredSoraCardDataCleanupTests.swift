import XCTest
import SoraKeystore
@testable import fearless

final class RetiredSoraCardDataCleanupTests: XCTestCase {
    private static let tokenIdentifier = "SCAccessToken"
    private static let storedToken = Data("refresh-fixture@access-fixture@1700000000".utf8)
    private static let retiredDefaultsKeys = ["SCKycId", "SCIsHidden", "SCIsRetry", "SCIsAppStarted"]

    // Wallet secrets and near-miss identifiers that must survive byte for byte.
    private static let walletSecrets: [String: Data] = [
        KeystoreTagV2.substrateSecretKeyTagForMetaId("fixture-meta"): Data([0x01, 0x02, 0x03]),
        KeystoreTagV2.ethereumSecretKeyTagForMetaId("fixture-meta"): Data([0x04, 0x05]),
        KeystoreTagV2.entropyTagForMetaId("fixture-meta"): Data([0x06]),
        KeystoreTag.pincode.rawValue: Data("1234".utf8),
        "SCAccessToken-backup": Data([0x07]),
        "scaccesstoken": Data([0x08]),
        "SCAccessTokens": Data([0x09])
    ]

    func testUpgradeFromSoraCardBuildRemovesOnlyTheRetiredLeftovers() throws {
        let keychain = InMemoryKeychain()
        try installSoraCardBuildState(in: keychain)
        let settings = InMemorySettingsManager()
        installSoraCardBuildDefaults(in: settings)
        let secretStore = RecordingSecretStore(keychain: keychain)
        let keystore = RecordingKeystore(keychain: keychain)

        let outcome = run(makeCleanup(secretStore: secretStore, keystore: keystore, settings: settings))

        XCTAssertEqual(outcome, .completed)
        XCTAssertFalse(try keychain.checkKey(for: Self.tokenIdentifier))
        try assertWalletSecretsUnchanged(in: keychain)
        for key in Self.retiredDefaultsKeys {
            XCTAssertNil(settings.anyValue(for: key), key)
        }
        XCTAssertEqual(settings.string(for: SettingsKey.selectedLocalization.rawValue), "ja")
        XCTAssertEqual(settings.string(for: "SCKycIdBackup"), "unrelated")
        XCTAssertEqual(settings.bool(for: SettingsKey.biometryEnabled.rawValue), true)
        XCTAssertEqual(settings.bool(for: RetiredSoraCardDataCleanup.completionKey), true)

        // The only Keychain operations are the exact-identifier removal and its confirmation.
        XCTAssertEqual(secretStore.calls, [.remove(Self.tokenIdentifier)])
        XCTAssertEqual(keystore.calls, [.check(Self.tokenIdentifier)])
    }

    func testLaterLaunchesDoNotTouchTheKeychainAgain() throws {
        let keychain = InMemoryKeychain()
        try installSoraCardBuildState(in: keychain)
        let settings = InMemorySettingsManager()
        installSoraCardBuildDefaults(in: settings)
        let secretStore = RecordingSecretStore(keychain: keychain)
        let keystore = RecordingKeystore(keychain: keychain)

        XCTAssertEqual(run(makeCleanup(secretStore: secretStore, keystore: keystore, settings: settings)), .completed)
        XCTAssertEqual(run(makeCleanup(secretStore: secretStore, keystore: keystore, settings: settings)), .alreadyCompleted)
        XCTAssertEqual(run(makeCleanup(secretStore: secretStore, keystore: keystore, settings: settings)), .alreadyCompleted)

        XCTAssertEqual(secretStore.calls, [.remove(Self.tokenIdentifier)])
        XCTAssertEqual(keystore.calls, [.check(Self.tokenIdentifier)])
        try assertWalletSecretsUnchanged(in: keychain)
    }

    func testInstallWithoutSoraCardDataCompletesWithoutChangingWalletData() throws {
        let keychain = InMemoryKeychain()
        for (identifier, secret) in Self.walletSecrets {
            try keychain.addKey(secret, with: identifier)
        }
        let settings = InMemorySettingsManager()
        settings.set(value: "ja", for: SettingsKey.selectedLocalization.rawValue)

        let outcome = run(makeCleanup(keychain: keychain, settings: settings))

        XCTAssertEqual(outcome, .completed)
        try assertWalletSecretsUnchanged(in: keychain)
        XCTAssertEqual(settings.string(for: SettingsKey.selectedLocalization.rawValue), "ja")
        XCTAssertEqual(settings.bool(for: RetiredSoraCardDataCleanup.completionKey), true)
    }

    func testFailedTokenRemovalIsRetriedOnTheNextLaunch() throws {
        let keychain = InMemoryKeychain()
        try installSoraCardBuildState(in: keychain)
        let settings = InMemorySettingsManager()
        installSoraCardBuildDefaults(in: settings)
        let failingStore = RecordingSecretStore(keychain: keychain, failsRemoval: true)

        let firstOutcome = run(makeCleanup(
            secretStore: failingStore,
            keystore: RecordingKeystore(keychain: keychain),
            settings: settings
        ))

        XCTAssertEqual(firstOutcome, .retryOnNextLaunch)
        XCTAssertTrue(try keychain.checkKey(for: Self.tokenIdentifier))
        XCTAssertNil(settings.bool(for: RetiredSoraCardDataCleanup.completionKey))

        let secondOutcome = run(makeCleanup(keychain: keychain, settings: settings))

        XCTAssertEqual(secondOutcome, .completed)
        XCTAssertFalse(try keychain.checkKey(for: Self.tokenIdentifier))
        try assertWalletSecretsUnchanged(in: keychain)
        XCTAssertEqual(settings.bool(for: RetiredSoraCardDataCleanup.completionKey), true)
    }

    func testUnreadableKeychainIsRetriedOnTheNextLaunch() throws {
        let keychain = InMemoryKeychain()
        try installSoraCardBuildState(in: keychain)
        let settings = InMemorySettingsManager()
        installSoraCardBuildDefaults(in: settings)
        let unreadableKeystore = RecordingKeystore(keychain: keychain, checkError: KeystoreError.unexpectedFail)

        let firstOutcome = run(makeCleanup(
            secretStore: RecordingSecretStore(keychain: keychain),
            keystore: unreadableKeystore,
            settings: settings
        ))

        XCTAssertEqual(firstOutcome, .retryOnNextLaunch)
        XCTAssertNil(settings.bool(for: RetiredSoraCardDataCleanup.completionKey))

        let secondOutcome = run(makeCleanup(keychain: keychain, settings: settings))

        XCTAssertEqual(secondOutcome, .completed)
        try assertWalletSecretsUnchanged(in: keychain)
    }

    func testLockedDeviceWaitsForProtectedDataBeforeTouchingAnything() throws {
        let keychain = InMemoryKeychain()
        try installSoraCardBuildState(in: keychain)
        let settings = InMemorySettingsManager()
        installSoraCardBuildDefaults(in: settings)
        let secretStore = RecordingSecretStore(keychain: keychain)
        let keystore = RecordingKeystore(keychain: keychain)
        let monitor = TestProtectedDataMonitor(isAvailable: false)
        let cleanup = makeCleanup(
            secretStore: secretStore,
            keystore: keystore,
            settings: settings,
            monitor: monitor
        )

        let finished = expectation(description: "cleanup finished")
        var outcome: RetiredSoraCardDataCleanupOutcome?
        cleanup.runIfNeeded {
            outcome = $0
            finished.fulfill()
        }

        let notYet = expectation(description: "nothing happens while locked")
        notYet.isInverted = true
        wait(for: [notYet], timeout: 0.2)

        XCTAssertNil(outcome)
        XCTAssertEqual(secretStore.calls, [])
        XCTAssertEqual(keystore.calls, [])
        XCTAssertTrue(try keychain.checkKey(for: Self.tokenIdentifier))
        XCTAssertEqual(settings.string(for: "SCKycId"), "fixture-kyc-id")
        XCTAssertEqual(monitor.observerCount, 1)

        monitor.makeAvailable()
        wait(for: [finished], timeout: 5)

        XCTAssertEqual(outcome, .completed)
        XCTAssertFalse(try keychain.checkKey(for: Self.tokenIdentifier))
        XCTAssertNil(settings.anyValue(for: "SCKycId"))
        XCTAssertEqual(monitor.observerCount, 0)
        try assertWalletSecretsUnchanged(in: keychain)
    }

    func testSystemKeychainRemovesOnlyTheExactTokenItem() throws {
        let keychain = Keychain()
        let sibling = "SCAccessToken.retired-sora-card-tests"
        let walletShaped = KeystoreTagV2.substrateSecretKeyTagForMetaId("retired-sora-card-tests")
        let siblingSecret = Data("sibling".utf8)
        let walletSecret = Data([0xA1, 0xB2, 0xC3])

        do {
            try keychain.saveKey(Self.storedToken, with: Self.tokenIdentifier)
            try keychain.saveKey(siblingSecret, with: sibling)
            try keychain.saveKey(walletSecret, with: walletShaped)
        } catch {
            throw XCTSkip("The test host has no usable Keychain: \(error)")
        }
        addTeardownBlock {
            try? keychain.deleteKeyIfExists(for: sibling)
            try? keychain.deleteKeyIfExists(for: walletShaped)
        }

        let settings = InMemorySettingsManager()
        let cleanup = RetiredSoraCardDataCleanup(
            secretManager: KeychainManager.shared,
            keystore: keychain,
            settings: settings,
            protectedDataAvailabilityMonitor: TestProtectedDataMonitor(isAvailable: true),
            logger: nil
        )

        XCTAssertEqual(run(cleanup), .completed)
        XCTAssertFalse(try keychain.checkKey(for: Self.tokenIdentifier))
        XCTAssertEqual(try keychain.fetchKey(for: sibling), siblingSecret)
        XCTAssertEqual(try keychain.fetchKey(for: walletShaped), walletSecret)
    }

    // MARK: - Helpers

    private func installSoraCardBuildState(in keychain: InMemoryKeychain) throws {
        try keychain.addKey(Self.storedToken, with: Self.tokenIdentifier)
        for (identifier, secret) in Self.walletSecrets {
            try keychain.addKey(secret, with: identifier)
        }
    }

    private func installSoraCardBuildDefaults(in settings: InMemorySettingsManager) {
        settings.set(value: "fixture-kyc-id", for: "SCKycId")
        settings.set(value: true, for: "SCIsHidden")
        settings.set(value: true, for: "SCIsRetry")
        settings.set(value: true, for: "SCIsAppStarted")
        settings.set(value: "ja", for: SettingsKey.selectedLocalization.rawValue)
        settings.set(value: true, for: SettingsKey.biometryEnabled.rawValue)
        settings.set(value: "unrelated", for: "SCKycIdBackup")
    }

    private func assertWalletSecretsUnchanged(
        in keychain: InMemoryKeychain,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        for (identifier, secret) in Self.walletSecrets {
            XCTAssertEqual(try keychain.fetchKey(for: identifier), secret, identifier, file: file, line: line)
        }
    }

    private func makeCleanup(
        keychain: InMemoryKeychain,
        settings: SettingsManagerProtocol
    ) -> RetiredSoraCardDataCleanup {
        makeCleanup(
            secretStore: RecordingSecretStore(keychain: keychain),
            keystore: RecordingKeystore(keychain: keychain),
            settings: settings
        )
    }

    private func makeCleanup(
        secretStore: SecretStoreManagerProtocol,
        keystore: KeystoreProtocol,
        settings: SettingsManagerProtocol,
        monitor: RootProtectedDataAvailabilityMonitoring = TestProtectedDataMonitor(isAvailable: true)
    ) -> RetiredSoraCardDataCleanup {
        RetiredSoraCardDataCleanup(
            secretManager: secretStore,
            keystore: keystore,
            settings: settings,
            protectedDataAvailabilityMonitor: monitor,
            logger: nil
        )
    }

    private func run(_ cleanup: RetiredSoraCardDataCleanup) -> RetiredSoraCardDataCleanupOutcome? {
        let finished = expectation(description: "cleanup finished")
        var outcome: RetiredSoraCardDataCleanupOutcome?
        cleanup.runIfNeeded {
            outcome = $0
            finished.fulfill()
        }
        wait(for: [finished], timeout: 5)
        return outcome
    }
}

private enum KeychainCall: Equatable {
    case load(String)
    case save(String)
    case remove(String)
    case checkSecret(String)
    case add(String)
    case update(String)
    case fetch(String)
    case check(String)
    case delete(String)
}

private final class RecordingSecretStore: SecretStoreManagerProtocol {
    private let keychain: InMemoryKeychain
    private let failsRemoval: Bool
    private let lock = NSLock()
    private var recordedCalls: [KeychainCall] = []

    init(keychain: InMemoryKeychain, failsRemoval: Bool = false) {
        self.keychain = keychain
        self.failsRemoval = failsRemoval
    }

    var calls: [KeychainCall] {
        lock.lock()
        defer { lock.unlock() }
        return recordedCalls
    }

    private func record(_ call: KeychainCall) {
        lock.lock()
        recordedCalls.append(call)
        lock.unlock()
    }

    func loadSecret(
        for identifier: String,
        completionQueue: DispatchQueue,
        completionBlock: @escaping (SecretDataRepresentable?) -> Void
    ) {
        record(.load(identifier))
        keychain.loadSecret(for: identifier, completionQueue: completionQueue, completionBlock: completionBlock)
    }

    func saveSecret(
        _ secret: SecretDataRepresentable,
        for identifier: String,
        completionQueue: DispatchQueue,
        completionBlock: @escaping (Bool) -> Void
    ) {
        record(.save(identifier))
        keychain.saveSecret(secret, for: identifier, completionQueue: completionQueue, completionBlock: completionBlock)
    }

    func removeSecret(
        for identifier: String,
        completionQueue: DispatchQueue,
        completionBlock: @escaping (Bool) -> Void
    ) {
        record(.remove(identifier))
        guard !failsRemoval else {
            completionQueue.async { completionBlock(false) }
            return
        }
        keychain.removeSecret(for: identifier, completionQueue: completionQueue, completionBlock: completionBlock)
    }

    func checkSecret(
        for identifier: String,
        completionQueue: DispatchQueue,
        completionBlock: @escaping (Bool) -> Void
    ) {
        record(.checkSecret(identifier))
        keychain.checkSecret(for: identifier, completionQueue: completionQueue, completionBlock: completionBlock)
    }

    func checkSecret(for identifier: String) -> Bool {
        record(.checkSecret(identifier))
        return keychain.checkSecret(for: identifier)
    }
}

private final class RecordingKeystore: KeystoreProtocol {
    private let keychain: InMemoryKeychain
    private let checkError: Error?
    private let lock = NSLock()
    private var recordedCalls: [KeychainCall] = []

    init(keychain: InMemoryKeychain, checkError: Error? = nil) {
        self.keychain = keychain
        self.checkError = checkError
    }

    var calls: [KeychainCall] {
        lock.lock()
        defer { lock.unlock() }
        return recordedCalls
    }

    private func record(_ call: KeychainCall) {
        lock.lock()
        recordedCalls.append(call)
        lock.unlock()
    }

    func addKey(_ key: Data, with identifier: String) throws {
        record(.add(identifier))
        try keychain.addKey(key, with: identifier)
    }

    func updateKey(_ key: Data, with identifier: String) throws {
        record(.update(identifier))
        try keychain.updateKey(key, with: identifier)
    }

    func fetchKey(for identifier: String) throws -> Data {
        record(.fetch(identifier))
        return try keychain.fetchKey(for: identifier)
    }

    func checkKey(for identifier: String) throws -> Bool {
        record(.check(identifier))
        if let checkError = checkError {
            throw checkError
        }
        return try keychain.checkKey(for: identifier)
    }

    func deleteKey(for identifier: String) throws {
        record(.delete(identifier))
        try keychain.deleteKey(for: identifier)
    }
}

private final class TestProtectedDataMonitor: RootProtectedDataAvailabilityMonitoring {
    private let lock = NSLock()
    private var isAvailable: Bool
    private var actions: [UUID: () -> Void] = [:]

    init(isAvailable: Bool) {
        self.isAvailable = isAvailable
    }

    var isProtectedDataAvailable: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isAvailable
    }

    var observerCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return actions.count
    }

    func observeDidBecomeAvailable(
        _ action: @escaping () -> Void
    ) -> RootProtectedDataAvailabilityObservation {
        let identifier = UUID()
        lock.lock()
        actions[identifier] = action
        lock.unlock()

        return TestProtectedDataObservation { [weak self] in
            self?.removeAction(identifier: identifier)
        }
    }

    func makeAvailable() {
        lock.lock()
        isAvailable = true
        let pendingActions = Array(actions.values)
        lock.unlock()

        pendingActions.forEach { $0() }
    }

    private func removeAction(identifier: UUID) {
        lock.lock()
        actions[identifier] = nil
        lock.unlock()
    }
}

private final class TestProtectedDataObservation: RootProtectedDataAvailabilityObservation {
    private let onInvalidate: () -> Void

    init(onInvalidate: @escaping () -> Void) {
        self.onInvalidate = onInvalidate
    }

    func invalidate() {
        onInvalidate()
    }
}
