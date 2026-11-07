import CryptoKit
import FearlessWalletConnect
import Security
import UIKit
import XCTest
@testable import fearless

/// Every public release with WalletConnect (3.0.5 up to 4.0.5 and 4.1.0) stored WalletConnectSwiftV2 data outside
/// the app group: sequences and the client id public key in `UserDefaults.standard`, keys as generic passwords in
/// the default keychain access group. 4.2.x ran Reown 1.8.0 with the app group, which moved the same records into
/// the group. This release runs the app's own client, which carries over what either left. These tests seed exactly
/// what those releases wrote and run the real `WalletConnectServiceImpl.setup()` to prove that nothing a user still
/// had a live connection for is lost on upgrade, and that the earlier records stay where they were.
///
/// Fixture layouts follow the WalletConnectSwiftV2 source each release resolved: 1.9.9 for 3.3.1 and later,
/// main@7cf45ea8 (1.9.5) for 3.0.7 - 3.2.4 and main@13446a81 (1.8.4) for 3.0.5 - 3.0.6. They differ only in the
/// keychain accessibility class; storage identifiers, `CodableStore` key layout and the `WCSession`/`WCPairing`
/// JSON are the same. Reown 1.8.0 adds `transportType`, `verifyContext` and `scopedProperties` to `WCSession`.
///
/// `liveUpgrade()` seeds and runs the real setup a single time per test process, and each test asserts one aspect
/// of the result.
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
        // The protocol counts expiry in whole seconds; Reown wrote whole seconds, this fixture has a fraction.
        XCTAssertEqual(
            session.expiryDate.timeIntervalSinceReferenceDate,
            fixture.liveSession.expiryDate.timeIntervalSinceReferenceDate,
            accuracy: 1
        )
        XCTAssertEqual(
            Set(session.namespaces.keys),
            ["eip155", "polkadot"]
        )
    }

    func testTheClientCarriesOverTheRelayIdentity() throws {
        let upgrade = try Self.liveUpgrade()

        // The same Ed25519 identity, so the relay treats the new client as the one that subscribed.
        XCTAssertEqual(
            upgrade.clientId,
            Self.didKey(publicKey: upgrade.fixture.clientId.publicKey)
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

    func testEarlierRecordsStayWhereTheyWere() throws {
        let upgrade = try Self.liveUpgrade()
        let fixture = upgrade.fixture

        // Nothing is moved or removed, so an earlier build still finds its records.
        for key in [
            fixture.liveSession.defaultsKey,
            fixture.expiredSession.defaultsKey,
            fixture.pairing.defaultsKey,
            fixture.malformedSessionDefaultsKey,
            LegacyWalletConnectFixture.clientIdPublicKeyKey
        ] {
            XCTAssertTrue(upgrade.standardKeysAfterSetup.contains(key), key)
        }
        XCTAssertEqual(UserDefaults.standard.data(forKey: fixture.liveSession.defaultsKey), fixture.liveSession.json)

        for account in [
            fixture.liveSession.topic,
            fixture.liveSession.selfPublicKeyHex,
            fixture.pairing.topic,
            fixture.clientId.storageId
        ] {
            let locations = Self.keychainLocations(service: LegacyWalletConnectFixture.keychainService, account: account)
            XCTAssertEqual(Set(locations.map(\.accessGroup)), upgrade.legacyAccessGroups, account)
        }
    }

    func testSessionAndPairingKeysAreKeptInTheClientsKeychainItemInTheAppGroup() throws {
        let upgrade = try Self.liveUpgrade()
        let fixture = upgrade.fixture

        let locations = Self.keychainLocations(
            service: KeychainSecretStore.defaultService,
            account: KeychainSecretStore.defaultAccount
        )
        XCTAssertEqual(locations.map(\.accessGroup), [upgrade.groupIdentifier])
        XCTAssertEqual(locations.map(\.accessible), [kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String])

        let data = try XCTUnwrap(KeychainSecretStore(accessGroup: upgrade.groupIdentifier).loadSecrets())
        let secrets = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let keys = try XCTUnwrap(secrets["keys"] as? [String: String])
        // The SDK kept the session key followed by a public key; the topic is the key's SHA-256.
        XCTAssertEqual(keys[fixture.liveSession.topic], Self.hex(fixture.liveSession.agreementKeys.prefix(32)))
        XCTAssertEqual(keys[fixture.pairing.topic], Self.hex(fixture.pairing.symmetricKey))
        XCTAssertNil(keys[fixture.expiredSession.topic])
        XCTAssertEqual(
            SHA256.hash(data: fixture.liveSession.agreementKeys.prefix(32)).map { String(format: "%02x", $0) }.joined(),
            fixture.liveSession.topic
        )
    }

    // MARK: - Reown 1.8.0 in the app group (4.2.x)

    func testReownSessionsInTheAppGroupCarryOver() async throws {
        let groupIdentifier = try Self.groupIdentifier()
        let suite = "reown.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let service = "com.walletconnect.sdk.reown.\(UUID().uuidString)"
        defer {
            defaults.removePersistentDomain(forName: suite)
            Self.deleteKeychainItems(service: service)
        }

        let fixture = try LegacyWalletConnectFixture.make(reown: true)
        fixture.seedSequences(in: defaults)
        for (account, data) in fixture.keychainItems {
            try Self.addKeychainItem(service: service, account: account, data: data, accessGroup: groupIdentifier)
        }

        let legacy = SystemLegacyWalletConnectStorage(
            groupIdentifier: groupIdentifier,
            groupDefaults: defaults,
            standardDefaults: defaults,
            keychainService: service
        )
        let store = InMemoryWalletConnectStore()
        let client = WalletConnectClient(
            configuration: .init(
                projectId: "",
                metadata: AppMetadata.createFearlessMetadata(),
                bundleId: Bundle.main.bundleIdentifier,
                userAgent: "wc-2/fearless-wallet-ios-tests"
            ),
            stateStore: store,
            secretStore: store,
            legacyStorage: legacy,
            transportFactory: OfflineRelayTransportFactory()
        )
        try await client.start()
        defer { Task { await client.stop() } }

        let session = try XCTUnwrap(client.currentSessions.first)
        XCTAssertEqual(client.currentSessions.map(\.topic), [fixture.liveSession.topic])
        XCTAssertEqual(session.peer.name, LegacyWalletConnectFixture.peerName)
        XCTAssertEqual(session.accounts.map(\.absoluteString).sorted(), [
            "eip155:1:0xab16a96D359eC26a11e2C2b3d8f8B8942d5Bfcdb",
            "polkadot:91b171bb158e2d3848fa23a9f1c25182:15oF4uVJwmo4TdGW7VfQxNLavjCXviqxT9S1MgbjMNHr6Sp5"
        ])
        let clientId = try await client.clientId()
        XCTAssertEqual(clientId, Self.didKey(publicKey: fixture.clientId.publicKey))

        // Ending the session removes its earlier records and keys, so a downgrade cannot bring it back.
        try await client.disconnect(topic: fixture.liveSession.topic)
        XCTAssertNil(defaults.data(forKey: fixture.liveSession.defaultsKey))
        XCTAssertTrue(Self.keychainLocations(service: service, account: fixture.liveSession.topic).isEmpty)
        XCTAssertTrue(Self.keychainLocations(service: service, account: fixture.liveSession.selfPublicKeyHex).isEmpty)
        XCTAssertNotNil(defaults.data(forKey: fixture.pairing.defaultsKey))
    }

    // MARK: - Keychain layouts of every shipped WalletConnectSwiftV2 revision

    func testEveryShippedLegacyKeychainLayoutIsReadWithoutMovingIt() throws {
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

            let storage = SystemLegacyWalletConnectStorage(groupIdentifier: groupIdentifier, keychainService: service)
            XCTAssertEqual(storage.keychainItem(account: account), data, layout.release)

            let locations = Self.keychainLocations(service: service, account: account)
            XCTAssertEqual(locations.map(\.accessGroup), [legacyGroup], layout.release)
            XCTAssertEqual(locations.map(\.accessible), [layout.accessible as String], layout.release)
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
        let clientId: String
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

        // The real client with the app group's stores; only its relay connection is offline.
        let service = WalletConnectServiceImpl(clientFactory: { groupIdentifier in
            guard let groupDefaults = UserDefaults(suiteName: groupIdentifier) else {
                return nil
            }
            return WalletConnectClient(
                configuration: .init(
                    projectId: "",
                    metadata: AppMetadata.createFearlessMetadata(),
                    bundleId: Bundle.main.bundleIdentifier,
                    userAgent: "wc-2/fearless-wallet-ios-tests"
                ),
                stateStore: UserDefaultsStateStore(defaults: groupDefaults),
                secretStore: KeychainSecretStore(accessGroup: groupIdentifier),
                legacyStorage: SystemLegacyWalletConnectStorage(groupIdentifier: groupIdentifier, groupDefaults: groupDefaults),
                transportFactory: OfflineRelayTransportFactory()
            )
        })
        service.setup()
        let client = try XCTUnwrap(service.client)
        // The start ends on the main actor, so the main run loop keeps turning while it is awaited.
        try runBlocking { await service.startTask?.value }
        let clientId = try runBlocking { try await client.clientId() }

        let upgrade = LiveUpgrade(
            groupIdentifier: groupIdentifier,
            fixture: fixture,
            legacyAccessGroups: legacyAccessGroups,
            sessions: service.getSessions(),
            needingReconnect: service.legacySessionsNeedingReconnect(),
            standardKeysAfterSetup: Set(UserDefaults.standard.dictionaryRepresentation().keys),
            clientId: clientId
        )
        service.throttle()
        return upgrade
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

    /// Test host only: clears what earlier runs left: the SDKs' records and flags and the client's own record and keys.
    static func removeWalletConnectState(groupDefaults: UserDefaults) {
        for defaults in [UserDefaults.standard, groupDefaults] {
            for key in defaults.dictionaryRepresentation().keys
                where key.hasPrefix("com.walletconnect.") || key.hasPrefix("hasMigratedToGroup_com.walletconnect.") {
                defaults.removeObject(forKey: key)
            }
            defaults.removeObject(forKey: UserDefaultsStateStore.defaultKey)
        }
        UserDefaults.standard.removeObject(forKey: WalletConnectLegacyStorageMigrator.legacySessionsKey)
        deleteKeychainItems(service: LegacyWalletConnectFixture.keychainService)
        deleteKeychainItems(service: KeychainSecretStore.defaultService)
    }

    static func didKey(publicKey: Data) -> String {
        // did:key, multibase base58btc of the Ed25519 multicodec prefix and the key.
        let bytes = [UInt8]([0xED, 0x01] + publicKey)
        let alphabet = Array("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")
        var digits: [Int] = []
        for byte in bytes {
            var carry = Int(byte)
            for index in digits.indices {
                carry += digits[index] << 8
                digits[index] = carry % 58
                carry /= 58
            }
            while carry > 0 {
                digits.append(carry % 58)
                carry /= 58
            }
        }
        let zeros = bytes.prefix { $0 == 0 }.count
        return "did:key:z" + String(repeating: "1", count: zeros) + String(digits.reversed().map { alphabet[$0] })
    }

    static func hex<D: Sequence>(_ bytes: D) -> String where D.Element == UInt8 {
        bytes.map { String(format: "%02x", $0) }.joined()
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

    /// Writes a generic password the way Reown 1.8.0's `KeychainStorage` did: in the app group's access group.
    static func addKeychainItem(service: String, account: String, data: Data, accessGroup: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecAttrIsInvisible: true,
            kSecUseDataProtectionKeychain: true,
            kSecAttrService: service,
            kSecAttrAccessGroup: accessGroup,
            kSecAttrAccount: account,
            kSecValueData: data
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainFixtureError.status(status)
        }
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
    static let peerName = "Continuity dApp"
    static let peerURL = "https://dapp.example"
    static let malformedJSON = Data(#"{"topic":"#.utf8)

    let liveSession: SessionRecord
    let expiredSession: SessionRecord
    let pairing: PairingRecord
    let malformedSessionTopic: String
    let clientId: ClientId

    var malformedSessionDefaultsKey: String { "com.walletconnect.sdk.sessionSequences.\(malformedSessionTopic)" }

    static func make(now: Date = Date(), reown: Bool = false) throws -> LegacyWalletConnectFixture {
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
                expiryDate: now.addingTimeInterval(5 * 24 * 3600),
                reown: reown
            ),
            expiredSession: try session(
                pairingTopic: pairingTopic,
                timestamp: now.addingTimeInterval(-9 * 24 * 3600),
                expiryDate: now.addingTimeInterval(-2 * 24 * 3600),
                reown: reown
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

    var keychainItems: [(account: String, data: Data)] {
        [
            (liveSession.topic, liveSession.agreementKeys),
            (liveSession.selfPublicKeyHex, liveSession.selfPrivateKey),
            (expiredSession.topic, expiredSession.agreementKeys),
            (expiredSession.selfPublicKeyHex, expiredSession.selfPrivateKey),
            (pairing.topic, pairing.symmetricKey),
            (clientId.storageId, clientId.privateKey)
        ]
    }

    /// Returns the access groups the keychain assigned to the legacy items.
    func seedKeychain() throws -> Set<String> {
        try Set(keychainItems.map { item in
            try WalletConnectLegacyStorageContinuityTests.addLegacyKeychainItem(
                service: Self.keychainService,
                account: item.account,
                data: item.data
            )
        })
    }

    /// `WCSession` as 1.9.9's `encode(to:)` wrote it with a default `JSONEncoder`; `reown` adds Reown 1.8.0's fields.
    private static func session(pairingTopic: String, timestamp: Date, expiryDate: Date, reown: Bool) throws -> SessionRecord {
        let selfKey = Curve25519.KeyAgreement.PrivateKey()
        let peerKey = Curve25519.KeyAgreement.PrivateKey()
        let sharedKey = try selfKey.sharedSecretFromKeyAgreement(with: peerKey.publicKey)
            .withUnsafeBytes { Data($0) }
        let topic = SHA256.hash(data: sharedKey).map { String(format: "%02x", $0) }.joined()
        let selfPublicKeyHex = hex(selfKey.publicKey.rawRepresentation)

        var record: [String: Any] = [
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
        ]
        if reown {
            record["scopedProperties"] = NSNull()
            record["transportType"] = ["relay": [String: String]()]
            record["verifyContext"] = ["origin": peerURL, "validation": "VALID", "verifyUrl": "https://verify.walletconnect.org"]
        }
        let json = try JSONSerialization.data(withJSONObject: record)

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

/// A relay that is never reachable: the client's connection attempts fail at once.
final class OfflineRelayTransportFactory: RelayTransportFactory {
    func makeTransport() -> RelayTransport {
        OfflineRelayTransport()
    }
}

private final class OfflineRelayTransport: RelayTransport, @unchecked Sendable {
    let events: AsyncStream<RelayTransportEvent>
    private let continuation: AsyncStream<RelayTransportEvent>.Continuation

    init() {
        var continuation: AsyncStream<RelayTransportEvent>.Continuation!
        events = AsyncStream { continuation = $0 }
        self.continuation = continuation
    }

    func connect(request _: URLRequest) {
        continuation.yield(.failed("offline"))
        continuation.finish()
    }

    func send(text _: String) async throws {
        throw RelayTransportError.notConnected
    }

    func sendPing() async throws {
        throw RelayTransportError.notConnected
    }

    func close() {
        continuation.finish()
    }
}

private final class BlockingResultBox<T> {
    var result: Result<T, Error>?
}

/// Runs async work from a synchronous test, turning the current run loop until it finishes so main-actor work
/// it waits for can run.
private func runBlocking<T>(timeout: TimeInterval = 30, _ operation: @escaping () async throws -> T) throws -> T {
    let box = BlockingResultBox<T>()
    Task {
        do {
            box.result = .success(try await operation())
        } catch {
            box.result = .failure(error)
        }
    }
    let deadline = Date(timeIntervalSinceNow: timeout)
    while box.result == nil, Date() < deadline {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
    }
    guard let result = box.result else {
        throw CancellationError()
    }
    return try result.get()
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

/// The update from a build that ran Reown 1.8.0 on the same simulator, against a dApp on the live relay
/// (`scripts/walletconnect/reference-dapp-upgrade.mjs`). The earlier build settled the session and wrote its records;
/// this build must go on serving it. Skipped unless `FEARLESS_WC_UPGRADE_LIVE=1`.
final class WalletConnectReownUpgradeLiveTests: XCTestCase {
    private final class Recorder: WalletConnectServiceDelegate {
        private(set) var declined: [Request] = []

        func signingUnavailable(request: Request, session _: Session?) {
            declined.append(request)
        }
    }

    private func waitForFile(_ url: URL, timeout: TimeInterval) throws -> String {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while Date() < deadline {
            if let text = try? String(contentsOf: url, encoding: .utf8), !text.isEmpty {
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))
        }
        throw CancellationError()
    }

    private func spin(timeout: TimeInterval, until condition: () -> Bool) throws {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while !condition() {
            guard Date() < deadline else {
                throw CancellationError()
            }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        }
    }

    func testTheUpdatedAppKeepsServingTheSessionReownSettled() throws {
        let environment = ProcessInfo.processInfo.environment
        guard
            environment["FEARLESS_WC_UPGRADE_LIVE"] == "1",
            let exchangePath = environment["FEARLESS_WC_EXCHANGE"],
            let projectId = environment["WALLETCONNECT_PROJECT_ID"]
        else {
            throw XCTSkip("The live upgrade check runs only with FEARLESS_WC_UPGRADE_LIVE=1")
        }
        let exchange = URL(fileURLWithPath: exchangePath)
        let topic = try waitForFile(exchange.appendingPathComponent("phase-a-session.txt"), timeout: 10)
        let groupIdentifier = try XCTUnwrap(
            WalletConnectGroupIdentifierResolver.resolve(bundleIdentifier: Bundle.main.bundleIdentifier)
        )
        let groupDefaults = try XCTUnwrap(UserDefaults(suiteName: groupIdentifier))
        let sessionRecordKey = "com.walletconnect.sdk.sessionSequences.\(topic)"

        // What Reown saved is there, and this client never ran on the device.
        XCTAssertNotNil(groupDefaults.data(forKey: sessionRecordKey))
        XCTAssertNil(groupDefaults.data(forKey: UserDefaultsStateStore.defaultKey))
        _ = try waitForFile(exchange.appendingPathComponent("dapp-held-request-sent.txt"), timeout: 120)

        let recorder = Recorder()
        let service = WalletConnectServiceImpl(clientFactory: { groupIdentifier in
            guard let defaults = UserDefaults(suiteName: groupIdentifier) else {
                return nil
            }
            return WalletConnectClient(
                configuration: .init(
                    projectId: projectId,
                    metadata: AppMetadata.createFearlessMetadata(),
                    bundleId: Bundle.main.bundleIdentifier,
                    userAgent: "wc-2/fearless-wallet-ios-upgrade-check"
                ),
                stateStore: UserDefaultsStateStore(defaults: defaults),
                secretStore: KeychainSecretStore(accessGroup: groupIdentifier),
                legacyStorage: SystemLegacyWalletConnectStorage(groupIdentifier: groupIdentifier, groupDefaults: defaults)
            )
        })
        service.set(listener: recorder)
        service.setup()
        try runBlocking { await service.startTask?.value }
        let client = try XCTUnwrap(service.client)

        let session = try XCTUnwrap(service.getSessions().first { $0.topic == topic })
        XCTAssertEqual(session.peer.name, "Fearless upgrade dApp")
        XCTAssertEqual(Set(session.namespaces.keys), ["eip155", "polkadot"])

        // The request the dApp sent while no wallet ran reaches this client, which declines it (signing is off).
        try spin(timeout: 300) { !recorder.declined.isEmpty }
        XCTAssertEqual(recorder.declined.first?.method, "personal_sign")
        XCTAssertEqual(recorder.declined.first?.topic, topic)

        _ = try waitForFile(exchange.appendingPathComponent("dapp-ping-done.txt"), timeout: 180)
        try runBlocking { try await client.ping(topic: topic) }
        try runBlocking { try await service.disconnect(topic: topic) }

        // Ending the session removed Reown's record and keys of it, so a downgrade cannot bring it back.
        XCTAssertNil(groupDefaults.data(forKey: sessionRecordKey))
        let result = try waitForFile(exchange.appendingPathComponent("result.json"), timeout: 180)
        let parsed = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(result.utf8)) as? [String: Any])
        XCTAssertEqual(parsed["ok"] as? Bool, true, result)

        let identity = try runBlocking { try await client.clientId() }
        let evidence: [String: Any] = [
            "sessionCarriedOver": true,
            "clientId": identity,
            "heldRequestDeclined": recorder.declined.first?.method ?? "",
            "reownSessionRecordRemoved": groupDefaults.data(forKey: sessionRecordKey) == nil
        ]
        try JSONSerialization.data(withJSONObject: evidence, options: [.sortedKeys, .prettyPrinted])
            .write(to: exchange.appendingPathComponent("phase-b.json"))
        service.throttle()
    }
}
