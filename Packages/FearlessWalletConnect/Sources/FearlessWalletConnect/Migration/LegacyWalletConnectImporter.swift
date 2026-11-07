import CryptoKit
import Foundation
import Security

/// What earlier WalletConnect SDKs left on the device, read without changing it.
///
/// Fearless 3.0.5 - 4.1.0 ran WalletConnectSwiftV2: records in the standard user defaults, keys as generic
/// passwords (service `com.walletconnect.sdk`) in the app's default keychain access group. Fearless 4.2.x ran Reown's
/// reown-swift 1.x with the app group: the same records in the group's user defaults and the same keys in the group's
/// keychain access group (Reown moved the earlier records there when it first started).
public protocol LegacyWalletConnectStorage: Sendable {
    /// Every record whose key starts with `prefix`, the app group's first.
    func records(withPrefix prefix: String) -> [(key: String, value: Data)]
    func value(forKey key: String) -> Data?
    /// A key the SDK kept in the keychain, by its account name.
    func keychainItem(account: String) -> Data?
    /// Removes an ended session's or pairing's records and keys, so a downgrade cannot bring it back.
    func removeRecords(keys: [String], keychainAccounts: [String])
}

/// The records of the device: the app group's user defaults and keychain access group, then the app's own.
public final class SystemLegacyWalletConnectStorage: LegacyWalletConnectStorage, @unchecked Sendable {
    public static let keychainService = "com.walletconnect.sdk"

    private let groupDefaults: UserDefaults?
    private let standardDefaults: UserDefaults
    private let accessGroup: String?
    private let service: String

    public init(
        groupIdentifier: String?,
        groupDefaults: UserDefaults? = nil,
        standardDefaults: UserDefaults = .standard,
        keychainService: String = SystemLegacyWalletConnectStorage.keychainService
    ) {
        self.groupDefaults = groupDefaults ?? groupIdentifier.flatMap(UserDefaults.init(suiteName:))
        self.standardDefaults = standardDefaults
        accessGroup = groupIdentifier
        service = keychainService
    }

    private var stores: [UserDefaults] {
        [groupDefaults, standardDefaults].compactMap { $0 }
    }

    public func records(withPrefix prefix: String) -> [(key: String, value: Data)] {
        var seen = Set<String>()
        var result: [(key: String, value: Data)] = []
        for defaults in stores {
            for (key, value) in defaults.dictionaryRepresentation() where key.hasPrefix(prefix) {
                guard let data = value as? Data, seen.insert(key).inserted else {
                    continue
                }
                result.append((key, data))
            }
        }
        return result.sorted { $0.key < $1.key }
    }

    public func value(forKey key: String) -> Data? {
        for defaults in stores {
            if let data = defaults.data(forKey: key) {
                return data
            }
        }
        return nil
    }

    public func keychainItem(account: String) -> Data? {
        // The app group's item first; without an access group the query also finds the default group's.
        for group in [accessGroup, nil] {
            var query: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: account,
                kSecReturnData: true,
                kSecMatchLimit: kSecMatchLimitOne,
                kSecUseDataProtectionKeychain: true
            ]
            if let group {
                query[kSecAttrAccessGroup] = group
            }
            var result: CFTypeRef?
            if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data {
                return data
            }
        }
        return nil
    }

    public func removeRecords(keys: [String], keychainAccounts: [String]) {
        for defaults in stores {
            for key in keys {
                defaults.removeObject(forKey: key)
            }
        }
        for account in keychainAccounts {
            let query: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: account,
                kSecUseDataProtectionKeychain: true
            ]
            SecItemDelete(query as CFDictionary)
        }
    }
}

/// Reads sessions, pairings, their keys and the relay identity from earlier SDKs' records.
struct LegacyWalletConnectImporter {
    static let sessionPrefix = "com.walletconnect.sdk.sessionSequences."
    static let pairingPrefix = "com.walletconnect.sdk.pairingSequences."
    static let clientPublicKeyKey = "com.walletconnect.iridium.client_id.public"
    /// Where WalletConnectSwiftV2 releases before 1.0 kept the relay identity's private key.
    static let oldClientKeyAccount = "com.walletconnect.iridium.client_id"
    static let source = "walletconnect-sdk"

    struct Result {
        var sessions: [StoredSession] = []
        var pairings: [StoredPairing] = []
        var keys: [String: Data] = [:]
        var clientSeed: Data?
        var skippedSessions = 0
        var skippedPairings = 0
    }

    let storage: LegacyWalletConnectStorage

    func read(now: Date, skipping known: Set<String>) -> Result {
        var result = Result()
        let nowSeconds = Int64(now.timeIntervalSince1970)

        for record in storage.records(withPrefix: Self.sessionPrefix) {
            let topic = String(record.key.dropFirst(Self.sessionPrefix.count))
            guard !known.contains(topic) else {
                continue
            }
            guard
                let session = Self.session(from: record.value, topic: topic, now: nowSeconds),
                let key = sessionKey(topic: topic)
            else {
                result.skippedSessions += 1
                continue
            }
            result.sessions.append(session)
            result.keys[topic] = key
        }

        let sessionPairings = Set(result.sessions.map(\.pairingTopic))
        for record in storage.records(withPrefix: Self.pairingPrefix) {
            let topic = String(record.key.dropFirst(Self.pairingPrefix.count))
            guard !known.contains(topic) else {
                continue
            }
            guard
                var pairing = Self.pairing(from: record.value, topic: topic, now: nowSeconds),
                let key = symmetricKey(topic: topic)
            else {
                result.skippedPairings += 1
                continue
            }
            if sessionPairings.contains(topic) {
                pairing.active = true
            }
            result.pairings.append(pairing)
            result.keys[topic] = key
        }

        result.clientSeed = clientSeed()
        return result
    }

    /// The records and keys of an imported session or pairing.
    static func records(forSession session: StoredSession) -> (keys: [String], keychainAccounts: [String]) {
        ([sessionPrefix + session.topic], [session.topic, session.selfParticipant.publicKey])
    }

    static func records(forPairing pairing: StoredPairing) -> (keys: [String], keychainAccounts: [String]) {
        ([pairingPrefix + pairing.topic], [pairing.topic])
    }

    // MARK: - Keys

    /// A session's key: the SDK kept the 32-byte key followed by the 32-byte public key it was agreed with.
    private func sessionKey(topic: String) -> Data? {
        guard let item = storage.keychainItem(account: topic), item.count == 64 || item.count == 32 else {
            return nil
        }
        let key = Data(item.prefix(32))
        return WalletConnectCrypto.topic(forSymmetricKey: key) == topic ? key : nil
    }

    /// A pairing's key. Unlike a session's topic, a pairing's topic need not be the key's SHA-256: the Swift SDKs
    /// chose pairing topics at random.
    private func symmetricKey(topic: String) -> Data? {
        guard let item = storage.keychainItem(account: topic), item.count == 32 else {
            return nil
        }
        return item
    }

    /// The relay identity: the Ed25519 public key in user defaults and its private key in the keychain under the
    /// public key's SHA-256, or the oldest releases' single keychain item.
    private func clientSeed() -> Data? {
        if
            let publicKey = storage.value(forKey: Self.clientPublicKeyKey),
            publicKey.count == 32,
            let seed = storage.keychainItem(account: Hex.encode(Data(SHA256.hash(data: publicKey)))),
            seed.count == 32,
            let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: seed),
            key.publicKey.rawRepresentation == publicKey {
            return seed
        }

        if
            let seed = storage.keychainItem(account: Self.oldClientKeyAccount),
            seed.count == 32,
            (try? Curve25519.Signing.PrivateKey(rawRepresentation: seed)) != nil {
            return seed
        }
        return nil
    }

    // MARK: - Records

    private struct LegacyRelay: Decodable {
        let `protocol`: String?
    }

    private struct LegacyRedirect: Decodable {
        let native: String?
        let universal: String?
        let linkMode: Bool?
    }

    private struct LegacyMetadata: Decodable {
        let name: String?
        let description: String?
        let url: String?
        let icons: [String]?
        let verifyUrl: String?
        let redirect: LegacyRedirect?

        var metadata: AppMetadata? {
            guard let name, let url else {
                return nil
            }
            return AppMetadata(
                name: name,
                description: description ?? "",
                url: url,
                icons: icons ?? [],
                verifyUrl: verifyUrl,
                redirect: redirect.map { AppMetadata.Redirect(native: $0.native, universal: $0.universal, linkMode: $0.linkMode) }
            )
        }
    }

    private struct LegacyParticipant: Decodable {
        let publicKey: String
        let metadata: LegacyMetadata?
    }

    private struct LegacyPeer: Decodable {
        let publicKey: String
    }

    private struct LegacyNamespace: Decodable {
        let chains: [String]?
        let accounts: [String]?
        let methods: [String]?
        let events: [String]?
    }

    private struct LegacySession: Decodable {
        let topic: String
        let pairingTopic: String?
        let relay: LegacyRelay?
        let selfParticipant: LegacyParticipant
        let peerParticipant: LegacyParticipant
        let controller: LegacyPeer
        let namespaces: [String: LegacyNamespace]
        let requiredNamespaces: [String: LegacyNamespace]?
        let sessionProperties: [String: String]?
        let acknowledged: Bool?
        /// `JSONEncoder`'s default: seconds since 2001-01-01.
        let expiryDate: Double
    }

    private struct LegacyPairing: Decodable {
        let topic: String
        let relay: LegacyRelay?
        let expiryDate: Double
        let active: Bool?
        let requestReceived: Bool?
        let methods: [String]?
        let peerMetadata: LegacyMetadata?
    }

    static func session(from data: Data, topic: String, now: Int64) -> StoredSession? {
        guard
            Hex.isKey(topic),
            let legacy = try? JSONDecoder().decode(LegacySession.self, from: data),
            legacy.topic == topic,
            Hex.isKey(legacy.selfParticipant.publicKey),
            Hex.isKey(legacy.peerParticipant.publicKey),
            // Fearless only ever was the wallet in these sessions.
            legacy.controller.publicKey == legacy.selfParticipant.publicKey,
            let selfMetadata = legacy.selfParticipant.metadata?.metadata,
            let peerMetadata = legacy.peerParticipant.metadata?.metadata
        else {
            return nil
        }

        let expiry = Int64(Date(timeIntervalSinceReferenceDate: legacy.expiryDate).timeIntervalSince1970)
        guard expiry > now else {
            return nil
        }

        var namespaces: [String: SessionNamespace] = [:]
        for (key, namespace) in legacy.namespaces {
            let accounts = (namespace.accounts ?? []).compactMap(Account.init)
            guard CAIP.isNamespaceKey(key), !accounts.isEmpty else {
                continue
            }
            namespaces[key] = SessionNamespace(
                chains: namespace.chains.map { $0.compactMap(Blockchain.init) },
                accounts: accounts,
                methods: Set(namespace.methods ?? []),
                events: Set(namespace.events ?? [])
            )
        }
        guard !namespaces.isEmpty else {
            return nil
        }

        var required: [String: ProposalNamespace] = [:]
        for (key, namespace) in legacy.requiredNamespaces ?? [:] where CAIP.isNamespaceKey(key) {
            required[key] = ProposalNamespace(
                chains: namespace.chains.map { $0.compactMap(Blockchain.init) },
                methods: Set(namespace.methods ?? []),
                events: Set(namespace.events ?? [])
            )
        }

        let pairingTopic = legacy.pairingTopic.flatMap { Hex.isKey($0) ? $0 : nil } ?? topic
        return StoredSession(
            topic: topic,
            pairingTopic: pairingTopic,
            relayProtocol: legacy.relay?.protocol ?? "irn",
            expiry: expiry,
            acknowledged: legacy.acknowledged ?? true,
            controller: legacy.controller.publicKey,
            namespaces: namespaces,
            requiredNamespaces: required,
            optionalNamespaces: nil,
            sessionProperties: legacy.sessionProperties,
            selfParticipant: StoredParticipant(publicKey: legacy.selfParticipant.publicKey, metadata: selfMetadata),
            peer: StoredParticipant(publicKey: legacy.peerParticipant.publicKey, metadata: peerMetadata),
            importedFrom: source
        )
    }

    static func pairing(from data: Data, topic: String, now: Int64) -> StoredPairing? {
        guard
            Hex.isKey(topic),
            let legacy = try? JSONDecoder().decode(LegacyPairing.self, from: data),
            legacy.topic == topic
        else {
            return nil
        }
        let expiry = Int64(Date(timeIntervalSinceReferenceDate: legacy.expiryDate).timeIntervalSince1970)
        guard expiry > now else {
            return nil
        }
        return StoredPairing(
            topic: topic,
            expiry: expiry,
            relayProtocol: legacy.relay?.protocol ?? "irn",
            active: legacy.active ?? legacy.requestReceived ?? false,
            peerMetadata: legacy.peerMetadata?.metadata,
            methods: legacy.methods,
            importedFrom: source
        )
    }
}
