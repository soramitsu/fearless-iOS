import CoreData
import CryptoKit
import Foundation
import RobinHood
import SoraKeystore

protocol LegacyTonConnectSessionStoring {
    func sessions() async throws -> [LegacyTonConnectSession]
    func save(_ session: LegacyTonConnectSession) async throws
    func remove(_ session: LegacyTonConnectSession) async throws
    func bridgeURL(network: String) async throws -> URL
}

final class LegacyTonConnectStore: LegacyTonConnectSessionStoring {
    private let service: CoreDataServiceProtocol

    init(service: CoreDataServiceProtocol = SubstrateDataStorageFacade.shared.databaseService) {
        self.service = service
    }

    func sessions() async throws -> [LegacyTonConnectSession] {
        try await perform { context in
            let rows = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "CDTonConnectedApp"))
            return rows.compactMap { row in
                // One unreadable or future session must not hide all other sessions.
                try? Self.read(row).validated()
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
                guard existing.count == 1, try Self.read(existing[0]) == session else {
                    throw LegacyTonConnectError.invalidSession
                }
                return
            }
            let row = NSEntityDescription.insertNewObject(forEntityName: "CDTonConnectedApp", into: context)
            row.setValue(session.identifier, forKey: "identifier")
            row.setValue(session.walletId, forKey: "walletId")
            row.setValue(session.clientId, forKey: "clientId")
            row.setValue(session.appUrl, forKey: "appUrl")
            row.setValue(session.name, forKey: "name")
            row.setValue(session.iconUrl, forKey: "iconUrl")
            row.setValue(session.publicKey, forKey: "publicKey")
            row.setValue(session.privateKey, forKey: "privateKey")
            row.setValue(session.connectionType, forKey: "connectionType")
            try context.save()
        }
    }

    func remove(_ session: LegacyTonConnectSession) async throws {
        try await perform { context in
            let fetch = NSFetchRequest<NSManagedObject>(entityName: "CDTonConnectedApp")
            fetch.predicate = NSPredicate(format: "identifier == %@", session.identifier)
            for row in try context.fetch(fetch) {
                guard try Self.read(row) == session else { throw LegacyTonConnectError.invalidSession }
                context.delete(row)
            }
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

    private static func read(_ row: NSManagedObject) throws -> LegacyTonConnectSession {
        var session: LegacyTonConnectSession?
        try SafeObjectiveCExceptionBoundary.perform {
            guard let identifier = row.value(forKey: "identifier") as? String,
                  let walletId = row.value(forKey: "walletId") as? String,
                  let clientId = row.value(forKey: "clientId") as? String,
                  let appUrl = row.value(forKey: "appUrl") as? URL,
                  let publicKey = row.value(forKey: "publicKey") as? Data,
                  let privateKey = row.value(forKey: "privateKey") as? Data else {
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
            session = LegacyTonConnectSession(
                identifier: identifier, walletId: walletId, clientId: clientId, appUrl: appUrl,
                name: name, iconUrl: row.value(forKey: "iconUrl") as? URL,
                publicKey: publicKey, privateKey: privateKey, connectionType: connectionType
            )
        }
        guard let session else { throw LegacyTonConnectError.invalidSession }
        return session
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
