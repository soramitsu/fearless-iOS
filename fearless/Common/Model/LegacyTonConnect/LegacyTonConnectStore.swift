import CoreData
import CryptoKit
import Foundation
import RobinHood
import Security
import SoraKeystore
import TweetNacl

protocol LegacyTonConnectSessionStoring {
    func sessions() async throws -> [LegacyTonConnectSession]
    /// Listed sessions whose key was moved out of a row that held it raw, and whose offer to reconnect the user has
    /// not answered yet. Copies of the store from before the move may still hold those keys.
    func sessionsToReconnect() async throws -> [LegacyTonConnectSession]
    /// The user answered the offer to reconnect these sessions, so it is not made again. Only rows that still wait
    /// for that answer and name these sessions' own items change; a session's key and identity never do.
    func finishReconnectOffer(for sessions: [LegacyTonConnectSession]) async throws
    func save(_ session: LegacyTonConnectSession) async throws
    func remove(_ session: LegacyTonConnectSession) async throws
    func bridgeURL(network: String) async throws -> URL
}

/// Keeps TON Connect bridge sessions. Each session's transport (NaCl box) private key lives in its own device-only,
/// non-synchronizing Keychain item; the row's `privateKey` column holds only a reference to it.
///
/// Rows written before this release hold the raw 32-byte key. They are read as before and moved one at a time:
/// the key is written to the Keychain, read back and checked against the row's public key, and only then is the
/// column replaced by the reference, in a single Core Data save. Any failure leaves the row exactly as it was and
/// usable, and the move is tried again on the next read. Rows restored from a retained or older store are legacy
/// input like any other. Wallet keys are never read or written here.
///
/// A moved row is marked in the same save (`LegacyTonConnectSessionKeyReference.movedColumn`): the raw key can
/// outlive the move in SQLite free pages, the write-ahead log, device backups and retained store archives, so the
/// user is offered, once, to disconnect and connect the application again, which retires that key everywhere.
/// The store is not vacuumed for this: a vacuum cannot reach archives or backups, rewrites a store that can be
/// hundreds of megabytes while the wallet starts, and changes the files the cache-recovery transaction verifies by
/// SHA-256. Apple's SQLite already zeroes the replaced cell in the page the move rewrites (`secure_delete` FAST).
final class LegacyTonConnectStore: LegacyTonConnectSessionStoring {
    /// Points where a test can stop a key move, as an interrupted process would.
    enum KeyMigrationBoundary: Equatable {
        /// The key is in the Keychain and verified; the row still holds the raw key.
        case keyStored
        /// The row holds the reference in memory; the Core Data save has not run.
        case rowUpdated
    }

    private static let operationLock = NSLock()

    private let service: CoreDataServiceProtocol
    private let keys: LegacyTonConnectSessionKeyStoring
    private let migrationBoundaryHook: (KeyMigrationBoundary) throws -> Void

    init(
        service: CoreDataServiceProtocol = SubstrateDataStorageFacade.shared.databaseService,
        keys: LegacyTonConnectSessionKeyStoring = LegacyTonConnectSessionKeychain(),
        migrationBoundaryHook: @escaping (KeyMigrationBoundary) throws -> Void = { _ in }
    ) {
        self.service = service
        self.keys = keys
        self.migrationBoundaryHook = migrationBoundaryHook
    }

    /// Throws `invalidSession` when the Keychain cannot answer (for example while the device is locked), so callers
    /// retry instead of treating every moved session as gone.
    func sessions() async throws -> [LegacyTonConnectSession] {
        try await perform { context in
            try self.listed(in: context).map(\.session)
        }
    }

    func sessionsToReconnect() async throws -> [LegacyTonConnectSession] {
        try await perform { context in
            try self.listed(in: context).filter(\.wasMoved).map(\.session)
        }
    }

    func finishReconnectOffer(for sessions: [LegacyTonConnectSession]) async throws {
        guard !sessions.isEmpty else { return }
        try await perform { context in
            var changed = false
            for session in sessions {
                let reference = LegacyTonConnectSessionKeyReference(identifier: session.identifier, publicKey: session.publicKey)
                let fetch = NSFetchRequest<NSManagedObject>(entityName: "CDTonConnectedApp")
                fetch.predicate = NSPredicate(format: "identifier == %@", session.identifier)
                for row in try context.fetch(fetch) {
                    var waits = false
                    try SafeObjectiveCExceptionBoundary.perform {
                        waits = row.value(forKey: "publicKey") as? Data == session.publicKey
                            && row.value(forKey: "privateKey") as? Data == reference.movedColumn
                    }
                    guard waits else { continue }
                    // The same item, no longer waiting for an answer.
                    row.setValue(reference.column, forKey: "privateKey")
                    changed = true
                }
            }
            if changed {
                try context.save()
            }
        }
    }

    func save(_ session: LegacyTonConnectSession) async throws {
        _ = try session.validated()
        try await perform { context in
            let fetch = NSFetchRequest<NSManagedObject>(entityName: "CDTonConnectedApp")
            fetch.predicate = NSPredicate(format: "identifier == %@", session.identifier)
            let existing = try context.fetch(fetch)
            if !existing.isEmpty {
                guard existing.count == 1 else { throw LegacyTonConnectError.invalidSession }
                let stored = try self.read(existing[0])
                guard stored.session == session else { throw LegacyTonConnectError.invalidSession }
                if stored.isLegacy {
                    self.moveKeyToKeychain(row: existing[0], key: LegacyKey(session), in: context)
                }
                return
            }
            let reference = LegacyTonConnectSessionKeyReference(identifier: session.identifier, publicKey: session.publicKey)
            let createdItem = try self.keys.loadKey(reference: reference.account) == nil
            do {
                try self.storeVerified(LegacyKey(session), reference: reference)
                let row = NSEntityDescription.insertNewObject(forEntityName: "CDTonConnectedApp", into: context)
                row.setValue(session.identifier, forKey: "identifier")
                row.setValue(session.walletId, forKey: "walletId")
                row.setValue(session.clientId, forKey: "clientId")
                row.setValue(session.appUrl, forKey: "appUrl")
                row.setValue(session.name, forKey: "name")
                row.setValue(session.iconUrl, forKey: "iconUrl")
                row.setValue(session.publicKey, forKey: "publicKey")
                row.setValue(reference.column, forKey: "privateKey")
                row.setValue(session.connectionType, forKey: "connectionType")
                try context.save()
            } catch {
                // Nothing refers to an item this save created (store operations are serialized); an item that was
                // already there may belong to a row in a retained store and stays.
                if createdItem {
                    try? self.keys.deleteKey(reference: reference.account)
                }
                throw error
            }
        }
    }

    func remove(_ session: LegacyTonConnectSession) async throws {
        try await perform { context in
            let fetch = NSFetchRequest<NSManagedObject>(entityName: "CDTonConnectedApp")
            fetch.predicate = NSPredicate(format: "identifier == %@", session.identifier)
            let rows = try context.fetch(fetch)
            let reference = LegacyTonConnectSessionKeyReference(identifier: session.identifier, publicKey: session.publicKey)
            for row in rows {
                let matches: Bool
                do {
                    matches = try self.read(row).session == session
                } catch LegacyTonConnectError.invalidSession {
                    // An earlier disconnect was cut short: finish it.
                    matches = try self.isUnfinishedRemoval(row, of: session, reference: reference)
                }
                guard matches else { throw LegacyTonConnectError.invalidSession }
            }
            guard !rows.isEmpty else { return }
            // 1. The rows are marked as being removed, durably, so no read lists them again and a later read
            //    finishes the removal if this one is cut short.
            rows.forEach { $0.setValue(reference.removingColumn, forKey: "privateKey") }
            try context.save()
            // 2. The key goes, a key left by an interrupted move included. If the Keychain cannot delete it, the
            //    disconnect is reported as failed and the next read retries; the session is already unusable.
            try self.keys.deleteKey(reference: reference.account)
            // 3. The rows go.
            rows.forEach(context.delete)
            try context.save()
        }
    }

    func bridgeURL(network: String) async throws -> URL {
        guard ["-239", "-3"].contains(network) else { throw LegacyTonConnectError.unavailableBridge }
        return try await perform { context in
            let fetch = NSFetchRequest<NSManagedObject>(entityName: "CDChain")
            fetch.predicate = NSPredicate(format: "chainId == %@", network)
            guard let row = try context.fetch(fetch).first,
                  let url = row.value(forKey: "tonBridgeUrl") as? URL,
                  LegacyTonConnectBridgeTransport.validBridgeURL(url) else {
                throw LegacyTonConnectError.unavailableBridge
            }
            return url
        }
    }

    private struct StoredSession {
        let session: LegacyTonConnectSession
        /// The row still holds the raw key.
        let isLegacy: Bool
        /// The key was moved out of this row, and the offer to reconnect has not been answered.
        let wasMoved: Bool
    }

    /// Every session a read lists, in row order. Finishes interrupted disconnects and moves raw keys on the way.
    private func listed(in context: NSManagedObjectContext) throws -> [StoredSession] {
        let rows = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "CDTonConnectedApp"))
        var sessions: [StoredSession] = []
        for row in rows {
            // A disconnect that could not finish earlier is finished now, never listed.
            if finishRemovalIfMarked(row, in: context) {
                continue
            }
            // A released row's key leaves SQLite whenever its key pair is sound, even if the row is not listed
            // (for example an unknown connection type).
            if let legacy = Self.legacyKey(in: row) {
                moveKeyToKeychain(row: row, key: legacy, in: context)
            }
            let stored: StoredSession
            do {
                stored = try read(row)
                _ = try stored.session.validated()
            } catch LegacyTonConnectSessionKeyError.keychainUnavailable(_) {
                throw LegacyTonConnectError.invalidSession
            } catch {
                // One unreadable or future session must not hide all other sessions.
                continue
            }
            sessions.append(stored)
        }
        return sessions
    }

    /// The row's identity columns match and it is either marked as being removed, or names this session's Keychain
    /// item, which is confirmed gone.
    private func isUnfinishedRemoval(
        _ row: NSManagedObject,
        of session: LegacyTonConnectSession,
        reference: LegacyTonConnectSessionKeyReference
    ) throws -> Bool {
        var identityMatches = false
        var column: Data?
        try SafeObjectiveCExceptionBoundary.perform {
            identityMatches = row.value(forKey: "identifier") as? String == session.identifier
                && row.value(forKey: "walletId") as? String == session.walletId
                && row.value(forKey: "clientId") as? String == session.clientId
                && row.value(forKey: "appUrl") as? URL == session.appUrl
                && row.value(forKey: "publicKey") as? Data == session.publicKey
            column = row.value(forKey: "privateKey") as? Data
        }
        guard identityMatches else { return false }
        if column == reference.removingColumn { return true }
        guard column == reference.column || column == reference.movedColumn else { return false }
        return try keys.loadKey(reference: reference.account) == nil
    }

    /// Finishes a disconnect that was cut short: deletes the key, then the row. Returns whether the row was marked.
    /// Any failure leaves the mark for the next read.
    private func finishRemovalIfMarked(_ row: NSManagedObject, in context: NSManagedObjectContext) -> Bool {
        var marked: (identifier: String, publicKey: Data, digest: Data)?
        try? SafeObjectiveCExceptionBoundary.perform {
            guard let column = row.value(forKey: "privateKey") as? Data,
                  case let .removing(digest) = LegacyTonConnectSessionKeyReference.Column(column) else {
                return
            }
            marked = (
                (row.value(forKey: "identifier") as? String) ?? "",
                (row.value(forKey: "publicKey") as? Data) ?? Data(),
                digest
            )
        }
        guard let marked else { return false }
        let reference = LegacyTonConnectSessionKeyReference(identifier: marked.identifier, publicKey: marked.publicKey)
        do {
            // Only the item this row's own identity names.
            if reference.digest == marked.digest {
                try keys.deleteKey(reference: reference.account)
            }
            context.delete(row)
            try context.save()
        } catch {
            context.rollback()
        }
        return true
    }

    /// A released row's raw key with what it is bound to.
    private struct LegacyKey {
        let identifier: String
        let publicKey: Data
        let privateKey: Data

        init(identifier: String, publicKey: Data, privateKey: Data) {
            self.identifier = identifier
            self.publicKey = publicKey
            self.privateKey = privateKey
        }

        init(_ session: LegacyTonConnectSession) {
            self.init(identifier: session.identifier, publicKey: session.publicKey, privateKey: session.privateKey)
        }
    }

    /// The row's raw key, when the row still holds one whose key pair is sound. Nothing else in the row is checked.
    private static func legacyKey(in row: NSManagedObject) -> LegacyKey? {
        var key: LegacyKey?
        try? SafeObjectiveCExceptionBoundary.perform {
            guard let identifier = row.value(forKey: "identifier") as? String, !identifier.isEmpty,
                  let publicKey = row.value(forKey: "publicKey") as? Data, publicKey.count == 32,
                  let column = row.value(forKey: "privateKey") as? Data,
                  case let .legacy(privateKey) = LegacyTonConnectSessionKeyReference.Column(column),
                  try NaclBox.keyPair(fromSecretKey: privateKey).publicKey == publicKey else {
                return
            }
            key = LegacyKey(identifier: identifier, publicKey: publicKey, privateKey: privateKey)
        }
        return key
    }

    /// Moves one legacy row's key into the Keychain. On any failure the row keeps its raw key and stays usable.
    /// The row is marked as moved in the same save, so the offer to reconnect is never lost to an interruption.
    private func moveKeyToKeychain(row: NSManagedObject, key: LegacyKey, in context: NSManagedObjectContext) {
        let reference = LegacyTonConnectSessionKeyReference(identifier: key.identifier, publicKey: key.publicKey)
        do {
            try storeVerified(key, reference: reference)
            try migrationBoundaryHook(.keyStored)
            row.setValue(reference.movedColumn, forKey: "privateKey")
            try migrationBoundaryHook(.rowUpdated)
            try context.save()
        } catch {
            // The Keychain item, if written, holds the same key and is reused by the next attempt.
            context.rollback()
            Logger.shared.warning("TON Connect session key stays in its row for now; the move is retried later")
        }
    }

    /// Writes the key, reads it back and checks it still opens the session: same bytes, same public key.
    private func storeVerified(_ key: LegacyKey, reference: LegacyTonConnectSessionKeyReference) throws {
        try keys.saveKey(key.privateKey, reference: reference.account)
        guard let stored = try keys.loadKey(reference: reference.account),
              stored == key.privateKey,
              try NaclBox.keyPair(fromSecretKey: stored).publicKey == key.publicKey else {
            throw LegacyTonConnectSessionKeyError.mismatch
        }
    }

    private func read(_ row: NSManagedObject) throws -> StoredSession {
        var stored: StoredSession?
        // Swift errors, a Keychain error included, pass through the boundary unchanged.
        try SafeObjectiveCExceptionBoundary.perform {
            guard let identifier = row.value(forKey: "identifier") as? String,
                  let walletId = row.value(forKey: "walletId") as? String,
                  let clientId = row.value(forKey: "clientId") as? String,
                  let appUrl = row.value(forKey: "appUrl") as? URL,
                  let publicKey = row.value(forKey: "publicKey") as? Data,
                  let column = row.value(forKey: "privateKey") as? Data else {
                throw LegacyTonConnectError.invalidSession
            }
            let privateKey: Data
            let isLegacy: Bool
            var wasMoved = false
            let parsed = LegacyTonConnectSessionKeyReference.Column(column)
            switch parsed {
            case let .legacy(key):
                privateKey = key
                isLegacy = true
            case let .keychain(digest), let .moved(digest):
                if case .moved = parsed {
                    wasMoved = true
                }
                // The row may only name the item made for its own identifier and public key.
                let reference = LegacyTonConnectSessionKeyReference(identifier: identifier, publicKey: publicKey)
                guard digest == reference.digest else { throw LegacyTonConnectError.invalidSession }
                guard let loaded = try self.keys.loadKey(reference: reference.account) else {
                    // The item is gone, for example after a disconnect, while a retained copy of the row came back.
                    throw LegacyTonConnectError.invalidSession
                }
                privateKey = loaded
                isLegacy = false
            case .removing, .none:
                throw LegacyTonConnectError.invalidSession
            }
            // Before 4.0.4 the released model had no connectionType. HTTP peers
            // used their 32-byte hex key; the JS presenter generated a UUID.
            let connectionType: String
            if let storedType = row.value(forKey: "connectionType") as? String {
                connectionType = storedType
            } else if LegacyTonConnectProtocol.clientKey(clientId) != nil {
                connectionType = "http"
            } else if UUID(uuidString: clientId) != nil {
                connectionType = "js"
            } else {
                throw LegacyTonConnectError.invalidSession
            }
            let name = (row.value(forKey: "name") as? String) ?? appUrl.host ?? appUrl.absoluteString
            stored = StoredSession(
                session: LegacyTonConnectSession(
                    identifier: identifier, walletId: walletId, clientId: clientId, appUrl: appUrl,
                    name: name, iconUrl: row.value(forKey: "iconUrl") as? URL,
                    publicKey: publicKey, privateKey: privateKey, connectionType: connectionType
                ),
                isLegacy: isLegacy,
                wasMoved: wasMoved
            )
        }
        guard let stored else { throw LegacyTonConnectError.invalidSession }
        return stored
    }

    private func perform<T>(_ action: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            service.performAsync { shared, error in
                guard let coordinator = shared?.persistentStoreCoordinator else {
                    continuation.resume(throwing: error ?? LegacyTonConnectError.invalidSession)
                    return
                }
                // Isolate failed session writes from unrelated wallet/chain changes.
                let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
                context.persistentStoreCoordinator = coordinator
                context.perform {
                    // One store operation at a time across contexts and store instances: a Keychain write, the row
                    // that names it and any clean-up never interleave with another operation.
                    Self.operationLock.lock()
                    defer { Self.operationLock.unlock() }
                    do {
                        let result = try action(context)
                        continuation.resume(returning: result)
                    } catch {
                        context.rollback()
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
}

enum LegacyTonConnectSessionKeyError: Error, Equatable {
    /// The Keychain could not answer; nothing is known about the item.
    case keychainUnavailable(OSStatus)
    /// The key read back is not the key written, or does not match the session's public key.
    case mismatch
}

/// Where TON Connect session transport keys are kept, apart from every wallet key.
protocol LegacyTonConnectSessionKeyStoring: AnyObject {
    /// Adds the item, or replaces the value of an existing one with the same reference.
    func saveKey(_ key: Data, reference: String) throws
    /// Nil when there is no such item. Throws `keychainUnavailable` when the Keychain cannot answer.
    func loadKey(reference: String) throws -> Data?
    /// Succeeds when there is no such item.
    func deleteKey(reference: String) throws
}

/// One generic-password item per session under its own service: accessible only while the device is unlocked,
/// never synchronized and never restored to another device. Wallet keys are application-tagged key items, which
/// these queries cannot match.
final class LegacyTonConnectSessionKeychain: LegacyTonConnectSessionKeyStoring {
    static let service = "jp.co.soramitsu.fearless.tonconnect.session-key.v1"

    func saveKey(_ key: Data, reference: String) throws {
        let attributes: [String: Any] = [
            kSecValueData as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        var status = SecItemAdd(query(reference).merging(attributes) { _, new in new } as CFDictionary, nil)
        if status == errSecDuplicateItem {
            status = SecItemUpdate(query(reference) as CFDictionary, attributes as CFDictionary)
        }
        guard status == errSecSuccess else { throw LegacyTonConnectSessionKeyError.keychainUnavailable(status) }
    }

    func loadKey(reference: String) throws -> Data? {
        var lookup = query(reference)
        lookup[kSecReturnData as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        var value: CFTypeRef?
        let status = SecItemCopyMatching(lookup as CFDictionary, &value)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = value as? Data else {
            throw LegacyTonConnectSessionKeyError.keychainUnavailable(status)
        }
        return data
    }

    func deleteKey(reference: String) throws {
        let status = SecItemDelete(query(reference) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw LegacyTonConnectSessionKeyError.keychainUnavailable(status)
        }
    }

    /// The stored item's attributes, for checking how it is protected.
    func attributes(reference: String) throws -> [String: Any]? {
        var lookup = query(reference)
        lookup[kSecReturnAttributes as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        var value: CFTypeRef?
        let status = SecItemCopyMatching(lookup as CFDictionary, &value)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let attributes = value as? [String: Any] else {
            throw LegacyTonConnectSessionKeyError.keychainUnavailable(status)
        }
        return attributes
    }

    private func query(_ reference: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: reference,
            kSecAttrSynchronizable as String: false,
            kSecUseDataProtectionKeychain as String: true
        ]
    }
}

/// Names a session's Keychain item from its identifier and public key, and the value its row keeps in place of the
/// raw key. A released row holds exactly 32 key bytes; a reference has another length and a fixed prefix.
struct LegacyTonConnectSessionKeyReference: Equatable {
    static let columnPrefix = Data("fwtck1".utf8)
    /// Like `columnPrefix`, for a key moved out of a row that held it raw, until the user answers the offer to
    /// reconnect the application.
    static let movedPrefix = Data("fwtck2".utf8)
    /// A disconnect has begun: the row is no longer a session, and its key and then the row are being removed.
    static let removingPrefix = Data("fwtck0".utf8)

    enum Column: Equatable {
        case legacy(Data)
        case keychain(Data)
        case moved(Data)
        case removing(Data)

        init?(_ value: Data) {
            let prefixLength = LegacyTonConnectSessionKeyReference.columnPrefix.count
            if value.count == 32 {
                self = .legacy(value)
            } else if value.count == prefixLength + 32,
                      value.prefix(prefixLength) == LegacyTonConnectSessionKeyReference.columnPrefix {
                self = .keychain(Data(value.suffix(32)))
            } else if value.count == prefixLength + 32,
                      value.prefix(prefixLength) == LegacyTonConnectSessionKeyReference.movedPrefix {
                self = .moved(Data(value.suffix(32)))
            } else if value.count == prefixLength + 32,
                      value.prefix(prefixLength) == LegacyTonConnectSessionKeyReference.removingPrefix {
                self = .removing(Data(value.suffix(32)))
            } else {
                return nil
            }
        }
    }

    let digest: Data

    init(identifier: String, publicKey: Data) {
        var input = Data("fearless-tonconnect-session-key-v1".utf8)
        input.append(0)
        input.append(Data(identifier.utf8))
        input.append(0)
        input.append(publicKey)
        digest = Data(SHA256.hash(data: input))
    }

    /// The Keychain item's account.
    var account: String {
        digest.map { String(format: "%02x", $0) }.joined()
    }

    /// What the row's `privateKey` column holds once the key is in the Keychain.
    var column: Data {
        Self.columnPrefix + digest
    }

    /// What the row's `privateKey` column holds once a raw key has been moved to the Keychain, until the user has
    /// answered the offer to reconnect.
    var movedColumn: Data {
        Self.movedPrefix + digest
    }

    /// What the row's `privateKey` column holds while its disconnect is being finished.
    var removingColumn: Data {
        Self.removingPrefix + digest
    }
}

struct LegacyTonConnectSessionContext: Codable, Equatable {
    let bridgeURL: URL
    let network: String
    var lastEventId: String?
}

struct LegacyTonConnectDurableReply: Codable, Equatable {
    let requestDigest: Data
    let response: Data
    let messageHashHex: String?
}

/// A response is committed before the transfer journal can be acknowledged.
/// These are separate new Keychain tags; legacy signing and session keys remain intact.
final class LegacyTonConnectReplyStore {
    private let keystore: KeystoreProtocol
    private let lock = NSLock()

    init(keystore: KeystoreProtocol = Keychain()) {
        self.keystore = keystore
    }

    func context(sessionId: String) throws -> LegacyTonConnectSessionContext? {
        lock.lock()
        defer { lock.unlock() }
        return try load(LegacyTonConnectSessionContext.self, tag: tag(kind: "context", identity: sessionId))
    }

    func save(context: LegacyTonConnectSessionContext, sessionId: String) throws {
        guard LegacyTonConnectBridgeTransport.validBridgeURL(context.bridgeURL), ["-239", "-3"].contains(context.network),
              context.lastEventId.map({ $0.utf8.count <= 256 }) ?? true else { throw LegacyTonConnectError.invalidSession }
        lock.lock()
        defer { lock.unlock() }
        let identifier = tag(kind: "context", identity: sessionId)
        if let existing: LegacyTonConnectSessionContext = try load(LegacyTonConnectSessionContext.self, tag: identifier) {
            guard existing.bridgeURL == context.bridgeURL, existing.network == context.network else {
                throw LegacyTonConnectError.invalidSession
            }
            if existing == context { return }
        }
        try keystore.saveKey(JSONEncoder().encode(context), with: identifier)
    }

    func reply(sessionId: String, requestId: String, request: Data) throws -> LegacyTonConnectDurableReply? {
        lock.lock()
        defer { lock.unlock() }
        let identifier = tag(kind: "reply", identity: sessionId + "\u{0}" + requestId)
        guard let saved: LegacyTonConnectDurableReply = try load(LegacyTonConnectDurableReply.self, tag: identifier) else { return nil }
        guard saved.requestDigest == Data(SHA256.hash(data: request)) else { throw LegacyTonConnectError.invalidRequest }
        return saved
    }

    func save(response: Data, messageHashHex: String? = nil, sessionId: String, requestId: String, request: Data) throws {
        guard response.count <= LegacyTonConnectProtocol.maximumMessageBytes,
              request.count <= LegacyTonConnectProtocol.maximumMessageBytes else { throw LegacyTonConnectError.invalidRequest }
        lock.lock()
        defer { lock.unlock() }
        let identifier = tag(kind: "reply", identity: sessionId + "\u{0}" + requestId)
        let value = LegacyTonConnectDurableReply(requestDigest: Data(SHA256.hash(data: request)), response: response, messageHashHex: messageHashHex)
        if let saved: LegacyTonConnectDurableReply = try load(LegacyTonConnectDurableReply.self, tag: identifier) {
            guard saved == value else { throw LegacyTonConnectError.invalidRequest }
            return
        }
        try keystore.addKey(JSONEncoder().encode(value), with: identifier)
    }

    private func tag(kind: String, identity: String) -> String {
        "fearless-tonconnect-v1-" + kind + "-" + SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func load<T: Decodable>(_ type: T.Type, tag: String) throws -> T? {
        do {
            let data = try keystore.fetchKey(for: tag)
            guard data.count <= 2 * LegacyTonConnectProtocol.maximumMessageBytes else { throw LegacyTonConnectError.invalidSession }
            return try JSONDecoder().decode(type, from: data)
        } catch KeystoreError.noKeyFound {
            return nil
        }
    }
}
