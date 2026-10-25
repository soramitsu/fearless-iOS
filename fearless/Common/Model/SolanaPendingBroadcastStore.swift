import Foundation

/// A signed Solana transaction the wallet handed to the cluster. While it exists the wallet
/// signs nothing new for this wallet and network: a retry after a lost reply would otherwise
/// sign a second transaction with a fresh blockhash, and both could land. A Solana transaction
/// using a recent blockhash needs independent expiry evidence from that signed hash and
/// fresh finalized observations; the stored height alone cannot establish that outcome.
/// An unreadable or unbound record cannot establish it either. It holds the signed transaction (public
/// once broadcast) and never key material.
struct SolanaPendingBroadcast: Codable, Equatable {
    let walletId: String
    let chainId: String
    let signature: String
    let transactionBase64: String
    let lastValidBlockHeight: Int64
    let createdAt: Date
    /// The user was told the transfer was sent (a node accepted it) before it was confirmed.
    var reportedAsSent: Bool
    /// Missing on historical records. Never infer it from the currently selected endpoint.
    let genesisHash: String?
    /// Untrusted lookup hint from the original quote. A fresh finalized block must match
    /// the blockhash covered by the transaction signature before it can prove expiry.
    let blockhashContextSlot: Int64?

    init(
        walletId: String,
        chainId: String,
        signature: String,
        transactionBase64: String,
        lastValidBlockHeight: Int64,
        createdAt: Date,
        reportedAsSent: Bool,
        genesisHash: String? = nil,
        blockhashContextSlot: Int64? = nil
    ) {
        self.walletId = walletId
        self.chainId = chainId
        self.signature = signature
        self.transactionBase64 = transactionBase64
        self.lastValidBlockHeight = lastValidBlockHeight
        self.createdAt = createdAt
        self.reportedAsSent = reportedAsSent
        self.genesisHash = genesisHash
        self.blockhashContextSlot = blockhashContextSlot
    }

    /// The height is not covered by the signature. This only rejects impossible values;
    /// a positive stored height is not independently proven expiry information.
    func validatedTransaction(for scope: SolanaPendingBroadcastScope) throws -> ParsedSolanaTransaction {
        guard SolanaPendingBroadcastScope(walletId: walletId, chainId: chainId) == scope,
              lastValidBlockHeight >= 0 else {
            throw SolanaPendingBroadcastStoreError.invalidRecord
        }
        return try SolanaTransactionSigner.verifySerializedTransaction(
            base64: transactionBase64, expectedSignature: signature
        )
    }
}

/// One wallet on one Solana network; chain aliases resolve to the same scope.
struct SolanaPendingBroadcastScope: Hashable {
    let walletId: String
    let chainId: String

    init(walletId: String, chainId: String) {
        self.walletId = walletId
        self.chainId = UniversalWalletChainAccountSupport.canonicalChainId(for: chainId).lowercased()
    }
}

enum SolanaPendingBroadcastReadState: Equatable {
    case absent
    case pending(SolanaPendingBroadcast)
    case unreadable
}

/// The exact bytes read or admitted by one operation. Comparing these bytes preserves
/// metadata changes and unknown historical fields, even when the signature is unchanged.
struct SolanaPendingBroadcastSnapshot {
    let record: SolanaPendingBroadcast
    fileprivate let bytes: Data
    fileprivate let revision: String
}

protocol SolanaPendingBroadcastStoring: AnyObject {
    /// Payment admission must distinguish an absent record from preserved unreadable data.
    func readState(for scope: SolanaPendingBroadcastScope) -> SolanaPendingBroadcastReadState
    func pending(for scope: SolanaPendingBroadcastScope) -> SolanaPendingBroadcast?
    func save(_ record: SolanaPendingBroadcast, for scope: SolanaPendingBroadcastScope) throws
    func snapshot(for scope: SolanaPendingBroadcastScope) throws -> SolanaPendingBroadcastSnapshot?
    func admit(
        _ record: SolanaPendingBroadcast, for scope: SolanaPendingBroadcastScope
    ) throws -> SolanaPendingBroadcastSnapshot
    func markReported(
        _ expected: SolanaPendingBroadcastSnapshot, for scope: SolanaPendingBroadcastScope
    ) throws -> Bool
    func clear(_ expected: SolanaPendingBroadcastSnapshot, for scope: SolanaPendingBroadcastScope) -> Bool
    /// Synchronous convenience only. Asynchronous owners must clear their exact snapshot.
    func clear(signature: String, for scope: SolanaPendingBroadcastScope)
}

extension SolanaPendingBroadcastStoring {
    /// Legacy/injected stores cannot silently claim atomic admission or update support.
    func snapshot(for scope: SolanaPendingBroadcastScope) throws -> SolanaPendingBroadcastSnapshot? {
        guard readState(for: scope) == .absent else { throw SolanaPendingBroadcastStoreError.unreadableRecord }
        return nil
    }

    func admit(
        _: SolanaPendingBroadcast, for _: SolanaPendingBroadcastScope
    ) throws -> SolanaPendingBroadcastSnapshot {
        throw SolanaPendingBroadcastStoreError.notPersisted
    }

    func markReported(_: SolanaPendingBroadcastSnapshot, for _: SolanaPendingBroadcastScope) throws -> Bool {
        false
    }

    func clear(_: SolanaPendingBroadcastSnapshot, for _: SolanaPendingBroadcastScope) -> Bool {
        false
    }

    func readState(for scope: SolanaPendingBroadcastScope) -> SolanaPendingBroadcastReadState {
        pending(for: scope).map(SolanaPendingBroadcastReadState.pending) ?? .absent
    }
}

enum SolanaPendingBroadcastStoreError: Error, Equatable {
    case notPersisted
    case unreadableRecord
    case invalidRecord
    case existingRecord
    case submissionInProgress
}

/// A synchronized app-private journal retains authority independently of the preference cache.
/// Historical preferences remain readable and byte-preserved; they are copied into the journal
/// before they can authorize output or a new payment. Uncertain/corrupt storage fails closed.
final class SolanaPendingBroadcastStore: SolanaPendingBroadcastStoring {
    static let shared = SolanaPendingBroadcastStore(
        userDefaults: .standard, logger: Logger.shared,
        journalFactory: { try SolanaPendingBroadcastJournal.applicationSupport() }
    )

    private static let keyPrefix = "solana.pending_broadcast"
    private static let unreadableKeyPrefix = "solana.pending_broadcast.unreadable"
    private let userDefaults: UserDefaults
    private let logger: LoggerProtocol?
    private let journalFactory: () throws -> SolanaPendingBroadcastJournal
    private let journalLock = NSLock()
    private var cachedJournal: SolanaPendingBroadcastJournal?
    private var openingJournal = false

    init(
        userDefaults: UserDefaults,
        logger: LoggerProtocol? = Logger.shared,
        journal: SolanaPendingBroadcastJournal
    ) {
        self.userDefaults = userDefaults
        self.logger = logger
        journalFactory = { journal }
        cachedJournal = journal
    }

    init(
        userDefaults: UserDefaults,
        logger: LoggerProtocol?,
        journalFactory: @escaping () throws -> SolanaPendingBroadcastJournal
    ) {
        self.userDefaults = userDefaults
        self.logger = logger
        self.journalFactory = journalFactory
    }

    /// Keep only successful acquisition. Protected-data or filesystem unavailability can
    /// recover later without restarting the wallet. No store lock spans filesystem work.
    private func acquireJournal() throws -> SolanaPendingBroadcastJournal {
        journalLock.lock()
        if let cachedJournal {
            journalLock.unlock()
            return cachedJournal
        }
        guard !openingJournal else {
            journalLock.unlock()
            throw SolanaPendingBroadcastStoreError.notPersisted
        }
        openingJournal = true
        journalLock.unlock()
        defer {
            journalLock.lock(); openingJournal = false; journalLock.unlock()
        }
        let journal = try journalFactory()
        journalLock.lock(); cachedJournal = journal; journalLock.unlock()
        return journal
    }

    func pending(for scope: SolanaPendingBroadcastScope) -> SolanaPendingBroadcast? {
        guard case let .pending(record) = readState(for: scope) else { return nil }
        return record
    }

    func readState(for scope: SolanaPendingBroadcastScope) -> SolanaPendingBroadcastReadState {
        do {
            return try snapshot(for: scope).map { .pending($0.record) } ?? .absent
        } catch { return .unreadable }
    }

    func snapshot(for scope: SolanaPendingBroadcastScope) throws -> SolanaPendingBroadcastSnapshot? {
        try acquireJournal().withState(for: scope) { state in
            try snapshotLocked(for: scope, state: state)
        }
    }

    private func snapshotLocked(
        for scope: SolanaPendingBroadcastScope,
        state: SolanaPendingBroadcastJournal.State
    ) throws -> SolanaPendingBroadcastSnapshot? {
        guard !state.blocked else { throw SolanaPendingBroadcastStoreError.unreadableRecord }
        let key = Self.key(for: scope)
        let archiveKey = Self.archiveKey(for: scope)
        let preference = userDefaults.object(forKey: key)
        let archive = userDefaults.object(forKey: archiveKey)
        if archive != nil || (preference != nil && !(preference is Data)) {
            try preserveConflict(preference: preference, archive: archive, scope: scope, state: state)
        }
        let mirror = preference as? Data
        // Once migrated, the journal is authoritative. A byte-exact historical mirror is
        // stale cache, including after clear. A novel external value is ambiguous: retain
        // both histories and block the scope instead of silently choosing a payment.
        if !state.revision.isEmpty, let mirror, mirror != state.bytes,
           !state.containsHistoricalRecord(mirror) {
            try preserveConflict(preference: mirror, archive: nil, scope: scope, state: state)
        }
        let data = state.revision.isEmpty ? mirror : state.bytes
        guard let data else { return nil }
        let record: SolanaPendingBroadcast
        do {
            record = try Self.decoder.decode(SolanaPendingBroadcast.self, from: data)
            _ = try record.validatedTransaction(for: scope)
        } catch {
            logger?.error("Unreadable Solana pending broadcast record was preserved: \(error)")
            try preserveConflict(preference: data, archive: nil, scope: scope, state: state)
            throw SolanaPendingBroadcastStoreError.unreadableRecord
        }
        if state.revision.isEmpty {
            try state.append(data)
        }
        return SolanaPendingBroadcastSnapshot(record: record, bytes: data, revision: state.revision)
    }

    private func preserveConflict(
        preference: Any?, archive: Any?, scope: SolanaPendingBroadcastScope,
        state: SolanaPendingBroadcastJournal.State
    ) throws {
        var conflicts: [SolanaPendingBroadcastJournal.Conflict] = []
        if let preference {
            try conflicts.append(.init(key: Self.key(for: scope), value: preference))
        }
        if let archive {
            try conflicts.append(.init(key: Self.archiveKey(for: scope), value: archive))
        }
        try state.block(conflicts)
        throw SolanaPendingBroadcastStoreError.unreadableRecord
    }

    /// Insert only. An existing valid payment is just as authoritative as unreadable data.
    func save(_ record: SolanaPendingBroadcast, for scope: SolanaPendingBroadcastScope) throws {
        _ = try admit(record, for: scope)
    }

    func admit(
        _ record: SolanaPendingBroadcast, for scope: SolanaPendingBroadcastScope
    ) throws -> SolanaPendingBroadcastSnapshot {
        let data = try Self.encoder.encode(record)
        _ = try record.validatedTransaction(for: scope)
        return try acquireJournal().withState(for: scope) { state in
            guard try snapshotLocked(for: scope, state: state) == nil else {
                throw SolanaPendingBroadcastStoreError.existingRecord
            }
            let key = Self.key(for: scope)
            userDefaults.set(data, forKey: key)
            guard userDefaults.data(forKey: key) == data else { throw SolanaPendingBroadcastStoreError.notPersisted }
            try state.append(data)
            guard userDefaults.data(forKey: key) == data else { throw SolanaPendingBroadcastStoreError.notPersisted }
            return SolanaPendingBroadcastSnapshot(record: record, bytes: data, revision: state.revision)
        }
    }

    func markReported(
        _ expected: SolanaPendingBroadcastSnapshot, for scope: SolanaPendingBroadcastScope
    ) throws -> Bool {
        try acquireJournal().withState(for: scope) { state in
            guard try matchesLocked(expected, scope: scope, state: state) else { return false }
            guard var object = try JSONSerialization.jsonObject(with: expected.bytes) as? [String: Any] else {
                throw SolanaPendingBroadcastStoreError.unreadableRecord
            }
            object["reportedAsSent"] = true
            let data = try JSONSerialization.data(withJSONObject: object, options: .sortedKeys)
            userDefaults.set(data, forKey: Self.key(for: scope))
            guard userDefaults.data(forKey: Self.key(for: scope)) == data else {
                throw SolanaPendingBroadcastStoreError.notPersisted
            }
            try state.append(data)
            return userDefaults.data(forKey: Self.key(for: scope)) == data
        }
    }

    func clear(_ expected: SolanaPendingBroadcastSnapshot, for scope: SolanaPendingBroadcastScope) -> Bool {
        do {
            return try acquireJournal().withState(for: scope) { state in
                guard try matchesLocked(expected, scope: scope, state: state) else { return false }
                userDefaults.removeObject(forKey: Self.key(for: scope))
                guard userDefaults.object(forKey: Self.key(for: scope)) == nil else { return false }
                try state.append(nil)
                return userDefaults.object(forKey: Self.key(for: scope)) == nil
            }
        } catch { return false }
    }

    private func matchesLocked(
        _ expected: SolanaPendingBroadcastSnapshot,
        scope: SolanaPendingBroadcastScope,
        state: SolanaPendingBroadcastJournal.State
    ) throws -> Bool {
        let expectedScope = SolanaPendingBroadcastScope(
            walletId: expected.record.walletId, chainId: expected.record.chainId
        )
        guard expectedScope == scope,
              let current = try snapshotLocked(for: scope, state: state) else { return false }
        return current.bytes == expected.bytes && current.revision == expected.revision
    }

    func clear(signature: String, for scope: SolanaPendingBroadcastScope) {
        guard let expected = try? snapshot(for: scope), expected.record.signature == signature else { return }
        _ = clear(expected, for: scope)
    }

    private static func archiveKey(for scope: SolanaPendingBroadcastScope) -> String {
        [unreadableKeyPrefix, scope.walletId, scope.chainId].joined(separator: ":")
    }

    static func key(for scope: SolanaPendingBroadcastScope) -> String {
        [keyPrefix, scope.walletId, scope.chainId].joined(separator: ":")
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }()
}

/// One transferable attempt per wallet/network. The monitor is never held over RPC awaits.
/// The exact token prevents an obsolete completion from releasing a newer attempt.
final class SolanaSubmissionRegistry {
    static let shared = SolanaSubmissionRegistry()

    final class Attempt {
        fileprivate let scope: SolanaPendingBroadcastScope
        fileprivate init(scope: SolanaPendingBroadcastScope) {
            self.scope = scope
        }
    }

    private let lock = NSLock()
    private var active: [SolanaPendingBroadcastScope: Attempt] = [:]

    func begin(_ scope: SolanaPendingBroadcastScope) -> Attempt? {
        lock.lock()
        defer { lock.unlock() }
        guard active[scope] == nil else { return nil }
        let attempt = Attempt(scope: scope)
        active[scope] = attempt
        return attempt
    }

    func owns(_ attempt: Attempt, scope: SolanaPendingBroadcastScope) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return attempt.scope == scope && active[scope] === attempt
    }

    func end(_ attempt: Attempt) {
        lock.lock()
        defer { lock.unlock() }
        guard active[attempt.scope] === attempt else { return }
        active.removeValue(forKey: attempt.scope)
    }
}
