import Commons
import CryptoKit
import Security
import UIKit
import WalletConnectKMS
import WalletConnectRelay
import WalletConnectSign
import XCTest
@testable import fearless

/// Every public release with WalletConnect (3.0.5 up to 4.0.5 and 4.1.0) stored WalletConnectSwiftV2 data outside
/// the app group: sequences and the client id public key in `UserDefaults.standard`, keys as generic passwords in
/// the default keychain access group. 4.2.0 configures Reown 1.8.0 with the app group. These tests seed exactly
/// what those releases wrote and run the real `WalletConnectServiceImpl.setup()` to prove that nothing a user still
/// had a live connection for is lost on upgrade.
///
/// Fixture layouts follow the WalletConnectSwiftV2 source each release resolved: 1.9.9 for 3.3.1 and later,
/// main@7cf45ea8 (1.9.5) for 3.0.7 - 3.2.4 and main@13446a81 (1.8.4) for 3.0.5 - 3.0.6. They differ only in the
/// keychain accessibility class; storage identifiers, `CodableStore` key layout and the `WCSession`/`WCPairing`
/// JSON are the same.
///
/// Reown keeps process-wide singletons, so the SDK can run its one-time migrations only once per test process:
/// `liveUpgrade()` seeds and runs the real setup a single time, and each test asserts one aspect of the result.
final class WalletConnectLegacyStorageContinuityTests: XCTestCase {
    private static var liveUpgradeResult: Result<LiveUpgrade, Error>?

    override class func tearDown() {
        if let groupDefaults = try? Self.groupDefaults() {
            Self.removeWalletConnectState(groupDefaults: groupDefaults)
        }
        super.tearDown()
    }

    // MARK: - Real setup over a 4.0.4 (WalletConnectSwiftV2 1.9.9) installation

    func testLegacyFixturesStartOutsideTheAppGroup() throws {
        let upgrade = try Self.liveUpgrade()

        XCTAssertFalse(upgrade.legacyAccessGroups.isEmpty)
        XCTAssertFalse(upgrade.legacyAccessGroups.contains(upgrade.groupIdentifier))
    }

    func testLiveLegacySessionIsListedAfterSetup() throws {
        let upgrade = try Self.liveUpgrade()
        let fixture = upgrade.fixture

        let session = try XCTUnwrap(upgrade.sessions.first { $0.topic == fixture.liveSession.topic })
        XCTAssertEqual(session.peer.name, LegacyWalletConnectFixture.peerName)
        XCTAssertEqual(session.peer.url, LegacyWalletConnectFixture.peerURL)
        XCTAssertEqual(
            session.expiryDate.timeIntervalSinceReferenceDate,
            fixture.liveSession.expiryDate.timeIntervalSinceReferenceDate,
            accuracy: 0.001
        )
        XCTAssertEqual(
            Set(session.namespaces.keys),
            ["eip155", "polkadot"]
        )
    }

    func testSetupSwitchesReownTelemetryOff() throws {
        _ = try Self.liveUpgrade()

        XCTAssertEqual(
            UserDefaults.standard.object(forKey: "com.walletconnect.sdk.telemetryEnabled") as? Bool,
            false
        )
    }

    func testExpiredAndMalformedLegacySessionsAreDroppedAndOfferedForReconnect() throws {
        let upgrade = try Self.liveUpgrade()
        let fixture = upgrade.fixture
        let listedTopics = Set(upgrade.sessions.map(\.topic))

        XCTAssertFalse(listedTopics.contains(fixture.expiredSession.topic))
        XCTAssertFalse(listedTopics.contains(fixture.malformedSessionTopic))

        let needingReconnect = Dictionary(
            uniqueKeysWithValues: upgrade.needingReconnect.map { ($0.topic, $0) }
        )
        XCTAssertEqual(
            Set(needingReconnect.keys),
            [fixture.expiredSession.topic, fixture.malformedSessionTopic]
        )
        XCTAssertEqual(
            needingReconnect[fixture.expiredSession.topic]?.peerName,
            LegacyWalletConnectFixture.peerName
        )
        XCTAssertEqual(
            needingReconnect[fixture.expiredSession.topic]?.peerURL,
            LegacyWalletConnectFixture.peerURL
        )
        XCTAssertNil(needingReconnect[fixture.malformedSessionTopic]?.peerName)
        XCTAssertNil(needingReconnect[fixture.malformedSessionTopic]?.expiryDate)
    }

    func testSequencesAreMovedIntoTheAppGroupByTheSdk() throws {
        let upgrade = try Self.liveUpgrade()
        let fixture = upgrade.fixture
        let groupDefaults = try Self.groupDefaults()

        // The SDK moves (copies, then removes) every legacy sequence; the app removes nothing itself.
        for (key, data) in [
            (fixture.liveSession.defaultsKey, fixture.liveSession.json),
            (fixture.pairing.defaultsKey, fixture.pairing.json),
            (fixture.malformedSessionDefaultsKey, LegacyWalletConnectFixture.malformedJSON)
        ] {
            XCTAssertFalse(upgrade.standardKeysAfterSetup.contains(key), key)
            XCTAssertEqual(groupDefaults.data(forKey: key), data, key)
        }

        // Reown deletes an expired sequence when it reads it, as 1.9.9 did.
        XCTAssertFalse(upgrade.standardKeysAfterSetup.contains(fixture.expiredSession.defaultsKey))
        XCTAssertNil(groupDefaults.data(forKey: fixture.expiredSession.defaultsKey))
    }

    func testClientIdCarriesOverInsteadOfBeingRegenerated() throws {
        let upgrade = try Self.liveUpgrade()
        let fixture = upgrade.fixture
        let groupDefaults = try Self.groupDefaults()

        XCTAssertFalse(upgrade.standardKeysAfterSetup.contains(LegacyWalletConnectFixture.clientIdPublicKeyKey))
        XCTAssertEqual(
            groupDefaults.data(forKey: LegacyWalletConnectFixture.clientIdPublicKeyKey),
            fixture.clientId.publicKey
        )

        // The relay signs its auth token with the client id during setup, which moves the private key.
        XCTAssertEqual(upgrade.clientIdKeyAccessGroupsAfterSetup, [upgrade.groupIdentifier])
        let storage = KeychainStorage(
            serviceIdentifier: LegacyWalletConnectFixture.keychainService,
            accessGroup: upgrade.groupIdentifier
        )
        XCTAssertEqual(try storage.readData(key: fixture.clientId.storageId), fixture.clientId.privateKey)
    }

    func testSessionKeysReadBackThroughReownKeychainStorageFromTheAppGroup() throws {
        let upgrade = try Self.liveUpgrade()
        let fixture = upgrade.fixture
        let storage = KeychainStorage(
            serviceIdentifier: LegacyWalletConnectFixture.keychainService,
            accessGroup: upgrade.groupIdentifier
        )

        for (account, data) in [
            (fixture.liveSession.topic, fixture.liveSession.agreementKeys),
            (fixture.liveSession.selfPublicKeyHex, fixture.liveSession.selfPrivateKey),
            (fixture.pairing.topic, fixture.pairing.symmetricKey)
        ] {
            XCTAssertEqual(try storage.readData(key: account), data, account)

            // Reown moves the item into the group (SecItemUpdate of the access group), it does not copy it.
            let locations = Self.keychainLocations(service: LegacyWalletConnectFixture.keychainService, account: account)
            XCTAssertEqual(locations.map(\.accessGroup), [upgrade.groupIdentifier], account)
            XCTAssertEqual(
                locations.map(\.accessible),
                [kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String],
                account
            )
        }

        let agreementKeys: AgreementKeys = try storage.read(key: fixture.liveSession.topic)
        XCTAssertEqual(agreementKeys.derivedTopic(), fixture.liveSession.topic)
    }

    // MARK: - Keychain layouts of every shipped WalletConnectSwiftV2 revision

    func testReownMovesEveryShippedLegacyKeychainLayoutIntoTheAppGroup() throws {
        let groupIdentifier = try Self.groupIdentifier()
        let layouts: [(release: String, accessible: CFString)] = [
            ("3.3.1 - 4.1.0 (1.9.9)", kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly),
            ("3.0.7 - 3.2.4 (main@7cf45ea8)", kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly),
            ("3.0.5 - 3.0.6 (main@13446a81)", kSecAttrAccessibleWhenUnlockedThisDeviceOnly)
        ]

        for layout in layouts {
            let service = "com.walletconnect.sdk.ik9.\(UUID().uuidString)"
            defer { Self.deleteKeychainItems(service: service) }

            let account = Self.randomHex(count: 32)
            let data = Self.randomData(count: 32)
            let legacyGroup = try Self.addLegacyKeychainItem(
                service: service,
                account: account,
                data: data,
                accessible: layout.accessible
            )
            XCTAssertNotEqual(legacyGroup, groupIdentifier, layout.release)

            let storage = KeychainStorage(serviceIdentifier: service, accessGroup: groupIdentifier)
            XCTAssertEqual(try storage.readData(key: account), data, layout.release)

            let locations = Self.keychainLocations(service: service, account: account)
            XCTAssertEqual(locations.map(\.accessGroup), [groupIdentifier], layout.release)
            XCTAssertEqual(
                locations.map(\.accessible),
                [kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String],
                layout.release
            )
        }
    }

    // MARK: - Recording legacy sessions for the reconnect notice

    func testRecorderCapturesLegacySessionsWithoutChangingLegacyStorage() throws {
        let suites = IsolatedDefaults()
        defer { suites.remove() }
        let fixture = try LegacyWalletConnectFixture.make()
        fixture.seedSequences(in: suites.legacy)
        suites.legacy.set("not data", forKey: WalletConnectLegacyStorageMigrator.legacySessionKeyPrefix + "string")
        let before = suites.legacyEntries()

        let migrator = WalletConnectLegacyStorageMigrator(
            legacyDefaults: suites.legacy,
            groupDefaults: suites.group
        )
        migrator.recordLegacySessionsIfNeeded()

        var after = suites.legacyEntries()
        XCTAssertNotNil(after.removeValue(forKey: WalletConnectLegacyStorageMigrator.legacySessionsKey))
        XCTAssertEqual(after as NSDictionary, before as NSDictionary)
        XCTAssertTrue(suites.groupEntries().isEmpty)

        let recorded = Dictionary(uniqueKeysWithValues: migrator.recordedLegacySessions().map { ($0.topic, $0) })
        XCTAssertEqual(
            Set(recorded.keys),
            [fixture.liveSession.topic, fixture.expiredSession.topic, fixture.malformedSessionTopic]
        )
        XCTAssertEqual(
            recorded[fixture.liveSession.topic],
            WalletConnectLegacySession(
                topic: fixture.liveSession.topic,
                peerName: LegacyWalletConnectFixture.peerName,
                peerURL: LegacyWalletConnectFixture.peerURL,
                expiryDate: fixture.liveSession.expiryDate
            )
        )
        XCTAssertEqual(recorded[fixture.expiredSession.topic]?.expiryDate, fixture.expiredSession.expiryDate)
        XCTAssertEqual(
            recorded[fixture.malformedSessionTopic],
            WalletConnectLegacySession(topic: fixture.malformedSessionTopic, peerName: nil, peerURL: nil, expiryDate: nil)
        )
    }

    func testSessionsThatCarriedOverNeedNoReconnect() throws {
        let suites = IsolatedDefaults()
        defer { suites.remove() }
        let fixture = try LegacyWalletConnectFixture.make()
        fixture.seedSequences(in: suites.legacy)

        let migrator = WalletConnectLegacyStorageMigrator(legacyDefaults: suites.legacy, groupDefaults: suites.group)
        migrator.recordLegacySessionsIfNeeded()

        XCTAssertEqual(
            Set(migrator.legacySessionsNeedingReconnect(activeTopics: [fixture.liveSession.topic]).map(\.topic)),
            [fixture.expiredSession.topic, fixture.malformedSessionTopic]
        )
        XCTAssertTrue(
            migrator.legacySessionsNeedingReconnect(
                activeTopics: [fixture.liveSession.topic, fixture.expiredSession.topic, fixture.malformedSessionTopic]
            ).isEmpty
        )
    }

    func testRecorderRecordsOnlyOnce() throws {
        let suites = IsolatedDefaults()
        defer { suites.remove() }
        let fixture = try LegacyWalletConnectFixture.make()
        fixture.seedSequences(in: suites.legacy)

        let migrator = WalletConnectLegacyStorageMigrator(legacyDefaults: suites.legacy, groupDefaults: suites.group)
        migrator.recordLegacySessionsIfNeeded()
        let recorded = migrator.recordedLegacySessions()

        let later = try LegacyWalletConnectFixture.make()
        later.seedSequences(in: suites.legacy)
        migrator.recordLegacySessionsIfNeeded()

        XCTAssertEqual(migrator.recordedLegacySessions(), recorded)
    }

    func testRecorderSkipsInstallationsWhoseSessionsAlreadyLiveInTheAppGroup() throws {
        // TestFlight 2026.7.x and later already ran Reown with the app group.
        let suites = IsolatedDefaults()
        defer { suites.remove() }
        let fixture = try LegacyWalletConnectFixture.make()
        fixture.seedSequences(in: suites.legacy)
        suites.group.set(true, forKey: WalletConnectLegacyStorageMigrator.groupSessionsMigratedKey)

        let migrator = WalletConnectLegacyStorageMigrator(legacyDefaults: suites.legacy, groupDefaults: suites.group)
        migrator.recordLegacySessionsIfNeeded()

        XCTAssertNil(suites.legacy.object(forKey: WalletConnectLegacyStorageMigrator.legacySessionsKey))
        XCTAssertTrue(migrator.legacySessionsNeedingReconnect(activeTopics: []).isEmpty)
    }

    func testInstallationWithoutLegacySessionsNeedsNoReconnect() {
        let suites = IsolatedDefaults()
        defer { suites.remove() }
        let logger = RecordingLogger()

        let migrator = WalletConnectLegacyStorageMigrator(
            legacyDefaults: suites.legacy,
            groupDefaults: suites.group,
            logger: logger
        )
        migrator.recordLegacySessionsIfNeeded()
        migrator.logContinuity(activeTopics: [])

        XCTAssertEqual(migrator.recordedLegacySessions(), [])
        XCTAssertTrue(migrator.legacySessionsNeedingReconnect(activeTopics: []).isEmpty)
        XCTAssertTrue(logger.messages.isEmpty)
    }

    func testContinuityLogHasCountsButNoTopicsOrPeerNames() throws {
        let suites = IsolatedDefaults()
        defer { suites.remove() }
        let fixture = try LegacyWalletConnectFixture.make()
        fixture.seedSequences(in: suites.legacy)
        let logger = RecordingLogger()

        let migrator = WalletConnectLegacyStorageMigrator(
            legacyDefaults: suites.legacy,
            groupDefaults: suites.group,
            logger: logger
        )
        migrator.recordLegacySessionsIfNeeded()
        migrator.logContinuity(activeTopics: [fixture.liveSession.topic])

        XCTAssertEqual(logger.messages, ["WalletConnect legacy sessions: 3 recorded, 2 need reconnecting"])
    }
}

// MARK: - Live upgrade

private extension WalletConnectLegacyStorageContinuityTests {
    struct LiveUpgrade {
        let groupIdentifier: String
        let fixture: LegacyWalletConnectFixture
        let legacyAccessGroups: Set<String>
        let sessions: [Session]
        let needingReconnect: [WalletConnectLegacySession]
        let standardKeysAfterSetup: Set<String>
        let clientIdKeyAccessGroupsAfterSetup: [String]
    }

    static func liveUpgrade() throws -> LiveUpgrade {
        if let result = liveUpgradeResult {
            return try result.get()
        }

        let result = Result { try performLiveUpgrade() }
        liveUpgradeResult = result
        return try result.get()
    }

    static func performLiveUpgrade() throws -> LiveUpgrade {
        let groupIdentifier = try groupIdentifier()
        let groupDefaults = try groupDefaults()
        removeWalletConnectState(groupDefaults: groupDefaults)

        let fixture = try LegacyWalletConnectFixture.make()
        fixture.seedSequences(in: .standard)
        let legacyAccessGroups = try fixture.seedKeychain()
        // Keep the SDK's telemetry upload off the network; the socket below never connects either.
        UserDefaults.standard.set(false, forKey: LegacyWalletConnectFixture.telemetryEnabledKey)

        let service = WalletConnectServiceImpl(socketFactory: OfflineWebSocketFactory())
        service.setup()

        return LiveUpgrade(
            groupIdentifier: groupIdentifier,
            fixture: fixture,
            legacyAccessGroups: legacyAccessGroups,
            sessions: service.getSessions(),
            needingReconnect: service.legacySessionsNeedingReconnect(),
            standardKeysAfterSetup: Set(UserDefaults.standard.dictionaryRepresentation().keys),
            clientIdKeyAccessGroupsAfterSetup: keychainLocations(
                service: LegacyWalletConnectFixture.keychainService,
                account: fixture.clientId.storageId
            ).map(\.accessGroup)
        )
    }

    static func groupIdentifier() throws -> String {
        try XCTUnwrap(
            WalletConnectGroupIdentifierResolver.resolve(bundleIdentifier: Bundle.main.bundleIdentifier),
            "The test host must be the development app"
        )
    }

    static func groupDefaults() throws -> UserDefaults {
        try XCTUnwrap(UserDefaults(suiteName: groupIdentifier()))
    }

    /// Test host only: clears what earlier runs left, including the SDK's one-time migration flags.
    static func removeWalletConnectState(groupDefaults: UserDefaults) {
        for defaults in [UserDefaults.standard, groupDefaults] {
            for key in defaults.dictionaryRepresentation().keys
                where key.hasPrefix("com.walletconnect.") || key.hasPrefix("hasMigratedToGroup_com.walletconnect.") {
                defaults.removeObject(forKey: key)
            }
        }
        UserDefaults.standard.removeObject(forKey: WalletConnectLegacyStorageMigrator.legacySessionsKey)
        deleteKeychainItems(service: LegacyWalletConnectFixture.keychainService)
    }
}

// MARK: - Keychain helpers

private extension WalletConnectLegacyStorageContinuityTests {
    struct KeychainLocation {
        let accessGroup: String
        let accessible: String
    }

    /// Writes a generic password with the base query of WalletConnectSwiftV2's `KeychainStorage`, which sets no
    /// access group, and returns the access group the keychain assigned.
    @discardableResult
    static func addLegacyKeychainItem(
        service: String,
        account: String,
        data: Data,
        accessible: CFString = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    ) throws -> String {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccessible: accessible,
            kSecAttrIsInvisible: true,
            kSecUseDataProtectionKeychain: true,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: data
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainFixtureError.status(status)
        }

        let locations = keychainLocations(service: service, account: account)
        guard locations.count == 1, let location = locations.first else {
            throw KeychainFixtureError.unexpectedLocations(locations.count)
        }
        return location.accessGroup
    }

    static func keychainLocations(service: String, account: String) -> [KeychainLocation] {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnAttributes: true,
            kSecMatchLimit: kSecMatchLimitAll
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let items = result as? [[String: Any]] else {
            return []
        }

        return items.map {
            KeychainLocation(
                accessGroup: $0[kSecAttrAccessGroup as String] as? String ?? "",
                accessible: $0[kSecAttrAccessible as String] as? String ?? ""
            )
        }
    }

    static func deleteKeychainItems(service: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service
        ]
        SecItemDelete(query as CFDictionary)
    }

    static func randomData(count: Int) -> Data {
        Data((0 ..< count).map { _ in UInt8.random(in: 0 ... UInt8.max) })
    }

    static func randomHex(count: Int) -> String {
        randomData(count: count).map { String(format: "%02x", $0) }.joined()
    }

    enum KeychainFixtureError: Error {
        case status(OSStatus)
        case unexpectedLocations(Int)
    }
}

// MARK: - Fixture

/// What WalletConnectSwiftV2 1.9.9 left on a device: one live session, its pairing, an expired session that had
/// not been pruned yet, a corrupt session record and the relay client id.
private struct LegacyWalletConnectFixture {
    struct SessionRecord {
        let topic: String
        let expiryDate: Date
        let selfPublicKeyHex: String
        let selfPrivateKey: Data
        let agreementKeys: Data
        let json: Data

        var defaultsKey: String { "com.walletconnect.sdk.sessionSequences.\(topic)" }
    }

    struct PairingRecord {
        let topic: String
        let symmetricKey: Data
        let json: Data

        var defaultsKey: String { "com.walletconnect.sdk.pairingSequences.\(topic)" }
    }

    struct ClientId {
        let publicKey: Data
        let privateKey: Data

        var storageId: String {
            SHA256.hash(data: publicKey).map { String(format: "%02x", $0) }.joined()
        }
    }

    static let keychainService = "com.walletconnect.sdk"
    static let clientIdPublicKeyKey = "com.walletconnect.iridium.client_id.public"
    static let telemetryEnabledKey = "com.walletconnect.sdk.telemetryEnabled"
    static let peerName = "Continuity dApp"
    static let peerURL = "https://dapp.example"
    static let malformedJSON = Data(#"{"topic":"#.utf8)

    let liveSession: SessionRecord
    let expiredSession: SessionRecord
    let pairing: PairingRecord
    let malformedSessionTopic: String
    let clientId: ClientId

    var malformedSessionDefaultsKey: String { "com.walletconnect.sdk.sessionSequences.\(malformedSessionTopic)" }

    static func make(now: Date = Date()) throws -> LegacyWalletConnectFixture {
        let pairingTopic = randomHex()
        let pairingExpiry = now.addingTimeInterval(20 * 24 * 3600)
        let pairing = PairingRecord(
            topic: pairingTopic,
            symmetricKey: randomData(),
            json: try JSONSerialization.data(withJSONObject: [
                "topic": pairingTopic,
                "relay": ["protocol": "irn"],
                "peerMetadata": peerMetadata(),
                "expiryDate": pairingExpiry.timeIntervalSinceReferenceDate,
                "active": true,
                "requestReceived": false
            ])
        )

        let signingKey = Curve25519.Signing.PrivateKey()

        return LegacyWalletConnectFixture(
            liveSession: try session(
                pairingTopic: pairingTopic,
                timestamp: now.addingTimeInterval(-2 * 24 * 3600),
                expiryDate: now.addingTimeInterval(5 * 24 * 3600)
            ),
            expiredSession: try session(
                pairingTopic: pairingTopic,
                timestamp: now.addingTimeInterval(-9 * 24 * 3600),
                expiryDate: now.addingTimeInterval(-2 * 24 * 3600)
            ),
            pairing: pairing,
            malformedSessionTopic: randomHex(),
            clientId: ClientId(
                publicKey: signingKey.publicKey.rawRepresentation,
                privateKey: signingKey.rawRepresentation
            )
        )
    }

    func seedSequences(in defaults: UserDefaults) {
        defaults.set(liveSession.json, forKey: liveSession.defaultsKey)
        defaults.set(expiredSession.json, forKey: expiredSession.defaultsKey)
        defaults.set(pairing.json, forKey: pairing.defaultsKey)
        defaults.set(Self.malformedJSON, forKey: malformedSessionDefaultsKey)
        defaults.set(clientId.publicKey, forKey: Self.clientIdPublicKeyKey)
    }

    /// Returns the access groups the keychain assigned to the legacy items.
    func seedKeychain() throws -> Set<String> {
        let items: [(account: String, data: Data)] = [
            (liveSession.topic, liveSession.agreementKeys),
            (liveSession.selfPublicKeyHex, liveSession.selfPrivateKey),
            (expiredSession.topic, expiredSession.agreementKeys),
            (expiredSession.selfPublicKeyHex, expiredSession.selfPrivateKey),
            (pairing.topic, pairing.symmetricKey),
            (clientId.storageId, clientId.privateKey)
        ]

        return try Set(items.map { item in
            try WalletConnectLegacyStorageContinuityTests.addLegacyKeychainItem(
                service: Self.keychainService,
                account: item.account,
                data: item.data
            )
        })
    }

    /// `WCSession` as 1.9.9's `encode(to:)` wrote it with a default `JSONEncoder`.
    private static func session(pairingTopic: String, timestamp: Date, expiryDate: Date) throws -> SessionRecord {
        let selfKey = Curve25519.KeyAgreement.PrivateKey()
        let peerKey = Curve25519.KeyAgreement.PrivateKey()
        let sharedKey = try selfKey.sharedSecretFromKeyAgreement(with: peerKey.publicKey)
            .withUnsafeBytes { Data($0) }
        let topic = SHA256.hash(data: sharedKey).map { String(format: "%02x", $0) }.joined()
        let selfPublicKeyHex = hex(selfKey.publicKey.rawRepresentation)

        let json = try JSONSerialization.data(withJSONObject: [
            "topic": topic,
            "pairingTopic": pairingTopic,
            "relay": ["protocol": "irn"],
            "controller": ["publicKey": selfPublicKeyHex],
            "selfParticipant": [
                "publicKey": selfPublicKeyHex,
                "metadata": [
                    "name": "Fearless wallet",
                    "description": "Defi wallet",
                    "url": "https://fearlesswallet.io",
                    "icons": ["https://fearlesswallet.io/icon.png"],
                    "redirect": ["native": "fearless://"]
                ]
            ],
            "peerParticipant": [
                "publicKey": hex(peerKey.publicKey.rawRepresentation),
                "metadata": peerMetadata()
            ],
            "namespaces": [
                "eip155": [
                    "accounts": ["eip155:1:0xab16a96D359eC26a11e2C2b3d8f8B8942d5Bfcdb"],
                    "methods": ["eth_sendTransaction", "personal_sign"],
                    "events": ["accountsChanged", "chainChanged"]
                ],
                "polkadot": [
                    "accounts": [
                        "polkadot:91b171bb158e2d3848fa23a9f1c25182:15oF4uVJwmo4TdGW7VfQxNLavjCXviqxT9S1MgbjMNHr6Sp5"
                    ],
                    "methods": ["polkadot_signTransaction", "polkadot_signMessage"],
                    "events": []
                ]
            ],
            "sessionProperties": NSNull(),
            "acknowledged": true,
            "expiryDate": expiryDate.timeIntervalSinceReferenceDate,
            "timestamp": timestamp.timeIntervalSinceReferenceDate,
            "requiredNamespaces": [
                "eip155": [
                    "chains": ["eip155:1"],
                    "methods": ["eth_sendTransaction", "personal_sign"],
                    "events": ["accountsChanged", "chainChanged"]
                ]
            ]
        ])

        return SessionRecord(
            topic: topic,
            expiryDate: expiryDate,
            selfPublicKeyHex: selfPublicKeyHex,
            selfPrivateKey: selfKey.rawRepresentation,
            agreementKeys: sharedKey + peerKey.publicKey.rawRepresentation,
            json: json
        )
    }

    private static func peerMetadata() -> [String: Any] {
        [
            "name": peerName,
            "description": "IK-9 continuity fixture",
            "url": peerURL,
            "icons": ["https://dapp.example/icon.png"],
            "redirect": ["native": "dapp://", "universal": "https://dapp.example/wc"]
        ]
    }

    private static func randomData() -> Data {
        WalletConnectLegacyStorageContinuityTests.randomData(count: 32)
    }

    private static func randomHex() -> String {
        hex(randomData())
    }

    private static func hex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Test doubles

private final class IsolatedDefaults {
    let legacyName = "ik9.legacy.\(UUID().uuidString)"
    let groupName = "ik9.group.\(UUID().uuidString)"
    let legacy: UserDefaults
    let group: UserDefaults

    init() {
        legacy = UserDefaults(suiteName: legacyName)!
        group = UserDefaults(suiteName: groupName)!
    }

    func legacyEntries() -> [String: Any] {
        legacy.persistentDomain(forName: legacyName) ?? [:]
    }

    func groupEntries() -> [String: Any] {
        group.persistentDomain(forName: groupName) ?? [:]
    }

    func remove() {
        legacy.removePersistentDomain(forName: legacyName)
        group.removePersistentDomain(forName: groupName)
    }
}

private final class RecordingLogger: LoggerProtocol {
    private(set) var messages: [String] = []

    func verbose(message: String, file _: String, function _: String, line _: Int) {
        messages.append(message)
    }

    func debug(message: String, file _: String, function _: String, line _: Int) {
        messages.append(message)
    }

    func info(message: String, file _: String, function _: String, line _: Int) {
        messages.append(message)
    }

    func warning(message: String, file _: String, function _: String, line _: Int) {
        messages.append(message)
    }

    func error(message: String, file _: String, function _: String, line _: Int) {
        messages.append(message)
    }

    func customError(error: Error, file _: String, function _: String, line _: Int) {
        messages.append("\(error)")
    }
}

private final class OfflineWebSocketFactory: WebSocketFactory {
    func create(with url: URL) -> WebSocketConnecting {
        OfflineWebSocket(request: URLRequest(url: url))
    }
}

private final class OfflineWebSocket: WebSocketConnecting {
    var isConnected = false
    var onConnect: (() -> Void)?
    var onDisconnect: ((Error?) -> Void)?
    var onText: ((String) -> Void)?
    var request: URLRequest

    init(request: URLRequest) {
        self.request = request
    }

    func connect() {}

    func disconnect() {}

    func write(string _: String, completion: (() -> Void)?) {
        completion?()
    }
}

/// WalletConnect signing is unavailable in this release (`WalletConnectSigningPolicy`): a
/// dApp request is declined before any confirmation opens or any key is read, no signature
/// can reach a dApp, and the user is told once that nothing was signed.
final class WalletConnectSigningPolicyTests: XCTestCase {
    func testProductionPolicy_isDisabled() {
        XCTAssertFalse(WalletConnectSigningPolicy.production.isEnabled)
    }

    func testRequest_whenSigningUnavailable_thenDeclinesWithoutOpeningConfirmation() throws {
        let declined = expectation(description: "dApp told the user rejected the request")
        let responses = ResponseRecorder { declined.fulfill() }
        let service = WalletConnectServiceImpl(signingPolicy: .production, respond: responses.record)
        let listener = DelegateRecorder()
        service.set(listener: listener)
        let request = try Self.makeRequest()

        service.handle(request: request, session: nil)

        wait(for: [declined], timeout: 3)
        XCTAssertEqual(responses.recorded.map(\.request), [request])
        XCTAssertEqual(responses.recorded.map(\.response), [.error(.userRejected)])
        XCTAssertEqual(listener.unavailableRequests, [request])
        XCTAssertTrue(listener.signRequests.isEmpty)
    }

    #if DEBUG
        func testRequest_whenSigningEnabled_thenOpensConfirmationWithoutResponding() throws {
            // Negative control: the request reaches the confirmation and is only
            // declined by the policy.
            let responses = ResponseRecorder()
            let service = WalletConnectServiceImpl(signingPolicy: .enabledForTests, respond: responses.record)
            let listener = DelegateRecorder()
            service.set(listener: listener)
            let request = try Self.makeRequest()

            service.handle(request: request, session: nil)

            XCTAssertEqual(listener.signRequests, [request])
            XCTAssertTrue(listener.unavailableRequests.isEmpty)
            XCTAssertTrue(responses.recorded.isEmpty)
        }
    #endif

    func testSignedDecision_whenSigningUnavailable_thenNoSignatureReachesTheDApp() async throws {
        let responses = ResponseRecorder()
        let service = WalletConnectServiceImpl(signingPolicy: .production, respond: responses.record)
        let request = try Self.makeRequest()

        do {
            try await service.submit(signDecision: .signed(request: request, signature: AnyCodable("0x01")))
            XCTFail("A signature must not be sent while signing is unavailable")
        } catch WalletConnectSigningError.unavailable {}

        XCTAssertTrue(responses.recorded.isEmpty)
    }

    func testRejectedDecision_whenSigningUnavailable_thenIsStillSent() async throws {
        let responses = ResponseRecorder()
        let service = WalletConnectServiceImpl(signingPolicy: .production, respond: responses.record)
        let request = try Self.makeRequest()

        try await service.submit(signDecision: .rejected(request: request, error: .userRejected))

        XCTAssertEqual(responses.recorded.map(\.response), [.error(.userRejected)])
    }

    func testSigner_whenSigningUnavailable_thenFailsBeforeReadingKeys() async {
        let signer = WalletConnectSignerImpl(wallet: AccountGenerator.generateMetaAccount(), policy: .production)
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let methods: [WalletConnectMethod] = [
            .polkadotSignMessage,
            .polkadotSignTransaction,
            .ethereumPersonalSign,
            .ethereumSignTypeDataV4,
            .ethereumSignTransaction,
            .ethereumSendTransaction
        ]

        for method in methods {
            do {
                _ = try await signer.sign(params: AnyCodable("0x00"), chain: chain, method: method)
                XCTFail("\(method) must not sign while signing is unavailable")
            } catch WalletConnectSigningError.unavailable {
                // A missing account or key would throw a different error, so this also
                // shows the policy is checked before the wallet's keys are looked up.
            } catch {
                XCTFail("\(method) failed with \(error) instead of the signing policy")
            }
        }
    }

    func testUnavailableNotice_saysNothingWasSignedAndOffersOnlyClose() {
        let locale = Locale(identifier: "en")
        let viewModel = WalletConnectSigningUnavailableNoticePresenter.makeViewModel(locale: locale)

        XCTAssertEqual(viewModel.title, "WalletConnect signing isn't available in this version")
        XCTAssertEqual(
            viewModel.message,
            "A connected app asked Fearless to sign. The request was declined and nothing was signed. " +
                "You can keep using your wallet as usual and disconnect apps from WalletConnect in your profile."
        )
        XCTAssertTrue(viewModel.actions.isEmpty)
        XCTAssertEqual(
            viewModel.closeAction,
            R.string.localizable.commonClose(preferredLanguages: locale.rLanguages)
        )
        XCTAssertFalse(viewModel.isInfo)
    }

    func testUnavailableNotice_isTranslatedInEveryShippedLocale() {
        let english = WalletConnectSigningUnavailableNoticePresenter.makeViewModel(locale: Locale(identifier: "en"))
        let shipped = Bundle.main.localizations.filter { $0 != "en" && $0 != "Base" }
        XCTAssertFalse(shipped.isEmpty)
        for identifier in shipped {
            let viewModel = WalletConnectSigningUnavailableNoticePresenter.makeViewModel(
                locale: Locale(identifier: identifier)
            )

            XCTAssertNotEqual(viewModel.title, english.title, identifier)
            XCTAssertNotEqual(viewModel.message, english.message, identifier)
            XCTAssertTrue(viewModel.message?.contains("WalletConnect") == true, identifier)
        }
    }

    func testUnavailableNotice_whenRequestsArriveInBackground_thenShowsOneNoticeOnActivation() throws {
        let (window, root) = try hostInAppScene()
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }
        var isActive = false
        let notice = WalletConnectSigningUnavailableNoticePresenter(
            topViewController: { root },
            isApplicationActive: { isActive }
        )

        notice.requestNotice()
        notice.requestNotice()
        XCTAssertTrue(notice.isNoticePending)
        XCTAssertNil(root.presentedViewController)

        isActive = true
        notice.presentPendingNoticeIfPossible()
        XCTAssertFalse(notice.isNoticePending)
        let sheet = try XCTUnwrap(root.presentedViewController as? SheetAletViewController)
        waitUntil { !sheet.isBeingPresented }

        // A request that arrives while the notice is on screen shares it.
        notice.requestNotice()
        XCTAssertFalse(notice.isNoticePending)
        XCTAssertTrue(root.presentedViewController === sheet)
        root.dismiss(animated: false)
    }

    // MARK: - Helpers

    private static func makeRequest() throws -> Request {
        try Request(
            topic: "walletconnect-signing-policy",
            method: WalletConnectMethod.polkadotSignMessage.rawValue,
            params: AnyCodable("0x00"),
            chainId: XCTUnwrap(Blockchain("polkadot:91b171bb158e2d3848fa23a9f1c25182"))
        )
    }

    private func waitUntil(timeout: TimeInterval = 3, _ condition: () -> Bool) {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while !condition(), Date() < deadline {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.02))
        }
    }

    private func hostInAppScene() throws -> (UIWindow, UIViewController) {
        // Presentations only complete in a window of the host app's scene.
        let scene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
        let root = UIViewController()
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        window.rootViewController = root
        window.makeKeyAndVisible()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        return (window, root)
    }
}

private final class ResponseRecorder {
    struct Response {
        let request: Request
        let response: RPCResult
    }

    private let lock = NSLock()
    private var responses: [Response] = []
    private let onRecord: () -> Void

    init(onRecord: @escaping () -> Void = {}) {
        self.onRecord = onRecord
    }

    var recorded: [Response] {
        lock.lock()
        defer { lock.unlock() }
        return responses
    }

    func record(_ request: Request, _ response: RPCResult) async throws {
        lock.lock()
        responses.append(Response(request: request, response: response))
        lock.unlock()
        onRecord()
    }
}

private final class DelegateRecorder: WalletConnectServiceDelegate {
    private(set) var signRequests: [Request] = []
    private(set) var unavailableRequests: [Request] = []

    func sign(request: Request, session _: Session?) {
        signRequests.append(request)
    }

    func signingUnavailable(request: Request, session _: Session?) {
        unavailableRequests.append(request)
    }
}
