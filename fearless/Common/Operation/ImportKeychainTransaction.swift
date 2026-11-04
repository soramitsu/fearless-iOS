import Foundation
import RobinHood
import SoraKeystore
import SSFModels

/// Binds a Keychain mutation to the later wallet-store save performed by the
/// import/confirmation interactors. The operation writes first so a persisted
/// account never lacks its signer, then restores the exact prior Keychain state
/// if wallet persistence fails.
protocol PersistenceBoundKeychainOperation: AnyObject {
    func commitKeychainChanges()
    func rollbackKeychainChanges() throws
}

enum ImportKeychainPersistence {
    @discardableResult
    static func rollback(_ operation: BaseOperation<MetaAccountModel>, after error: Error) -> Error {
        do {
            try (operation as? PersistenceBoundKeychainOperation)?.rollbackKeychainChanges()
            return error
        } catch let rollbackError {
            Logger.shared.error("Import failed and key rollback failed: " +
                "\(error.localizedDescription); \(rollbackError.localizedDescription)")
            return rollbackError
        }
    }
}

/// Coordinates issued import writes until the wallet store acknowledges them.
/// Revisions are scoped to the underlying Keychain domain, not the factory instance.
/// This protects overlapping imports in this process; it is not a crash journal.
final class ImportKeychainTransaction: KeystoreProtocol {
    private enum Domain: Hashable { case system, object(ObjectIdentifier) }
    private struct Tag: Hashable { let domain: Domain; let name: String }
    private enum State { case pending, committed, rolledBack }
    private struct Revision { let owner: UUID; let value: Data; var state: State }
    private struct Entry {
        let store: KeystoreProtocol // Retains injected store identity until outstanding revisions settle.
        let original: Data?
        var visible: Data?
        var revisions: [Revision]
        var desired: Data? {
            revisions.last(where: { $0.state != .rolledBack })?.value ?? original
        }
    }

    /// These identities follow the actual KeystoreTagV2 namespace. Metadata, network
    /// aliases and unrelated inventory edits cannot hide a still-referenced signer.
    private enum AccountIdentity: Hashable {
        case substrate(String), ethereum(String), ton(String), chain(String, Data)
    }

    private struct PublicationKey: Hashable { let domain: Domain; let identity: AccountIdentity }
    private struct Publication {
        weak var store: AnyObject?
        let requiredTags: Set<String>
    }

    private static let lock = NSRecursiveLock()
    private static var entries: [Tag: Entry] = [:]
    /// Only identities issued in this process are tracked. No historical/view-only model
    /// is reclassified by inferred missing-key rules; no secret bytes are retained here.
    private static var publications: [PublicationKey: Publication] = [:]

    private let keystore: KeystoreProtocol
    private let domain: Domain
    private let owner = UUID()
    private var touched: Set<Tag> = []
    private var written: Set<Tag> = []
    private var state = State.pending
    private var inheritedRequirements: [AccountIdentity: Set<String>] = [:]

    init(keystore: KeystoreProtocol) {
        self.keystore = keystore
        // SoraKeystore.Keychain instances address the same application-tag namespace.
        domain = keystore is Keychain ? .system : .object(ObjectIdentifier(keystore))
    }

    private func value(for name: String) throws -> Data? {
        do { return try keystore.fetchKey(for: name) }
        catch KeystoreError.noKeyFound { return nil }
    }

    private static func retainOrFinish(_ entry: Entry, for tag: Tag) {
        if !entry.revisions.contains(where: { $0.state == .pending }), entry.visible == entry.desired {
            entries.removeValue(forKey: tag)
        } else {
            entries[tag] = entry
        }
    }

    private func write(_ value: Data, tag name: String, updating: Bool) throws {
        Self.lock.lock()
        defer { Self.lock.unlock() }
        guard state == .pending else { throw KeystoreError.unexpectedFail }
        let tag = Tag(domain: domain, name: name)
        let prior = try self.value(for: name)
        guard (prior != nil) == updating else {
            throw updating ? KeystoreError.noKeyFound : KeystoreError.duplicatedItem
        }
        // A nonparticipant changed the item: retain its current value as the new baseline.
        // Never restore an old snapshot over a different observed owner.
        var entry = Self.entries[tag].flatMap { $0.visible == prior ? $0 : nil }
            ?? Entry(store: keystore, original: prior, visible: prior, revisions: [])
        entry.revisions.append(Revision(owner: owner, value: value, state: .pending))
        entry.visible = value
        touched.insert(tag)
        written.insert(tag)
        Self.entries[tag] = entry
        do {
            if updating {
                try keystore.updateKey(value, with: name)
            } else {
                try keystore.addKey(value, with: name)
            }
        } catch {
            // A backend may throw after mutation. Keep that attempted revision so
            // rollback owns it. If it provably did not write, discard only this attempt.
            if let observed = try? self.value(for: name), observed != value {
                if observed == prior {
                    entry.revisions.removeLast()
                    entry.visible = prior
                    Self.retainOrFinish(entry, for: tag)
                } else {
                    Self.entries.removeValue(forKey: tag)
                }
            }
            throw error
        }
    }

    /// Keep the exact model's still-provisional keys alive while a newer import uses it.
    /// Acquisition shares rollback's lock, including the existence check for previously
    /// issued material. An already rolled-back provisional model cannot be published.
    func acquireDependencies(of wallet: MetaAccountModel) throws {
        Self.lock.lock(); defer { Self.lock.unlock() }
        guard state == .pending else { throw KeystoreError.unexpectedFail }
        for identity in Self.secretTagGroups(for: wallet).keys {
            let key = PublicationKey(domain: domain, identity: identity)
            if let publication = Self.publications[key],
               domain == .system || publication.store === keystore {
                for name in publication.requiredTags {
                    guard try value(for: name) != nil else { throw KeystoreError.noKeyFound }
                }
                inheritedRequirements[identity] = publication.requiredTags
            }
        }
        for name in Self.secretTags(for: wallet) {
            let tag = Tag(domain: domain, name: name)
            guard var entry = Self.entries[tag], let observed = try value(for: name),
                  observed == entry.visible else { continue }
            entry.revisions.append(Revision(owner: owner, value: observed, state: .pending))
            touched.insert(tag)
            Self.entries[tag] = entry
        }
    }

    func publish(_ wallet: MetaAccountModel, replacing previous: MetaAccountModel?) throws {
        Self.lock.lock(); defer { Self.lock.unlock() }
        let allowed = Self.secretTags(for: wallet)
        let discarded = Set(touched.filter { !written.contains($0) && !allowed.contains($0.name) })
        // A replacement may no longer reference an old provisional chain account.
        // Its temporary read lease must not turn unrelated keys into orphaned durable data.
        try rollback(discarded)
        touched.subtract(discarded)
        let previousIdentities = Set(previous.map { Self.secretTagGroups(for: $0).keys.map { $0 } } ?? [])
        for (identity, tags) in Self.secretTagGroups(for: wallet) {
            let inherited = inheritedRequirements[identity] ?? []
            let newlyIssued = previousIdentities.contains(identity) ? Set<String>() : Set(touched.map(\.name))
            let required = inherited.union(newlyIssued).intersection(tags)
            guard !required.isEmpty else { continue }
            Self.publications[PublicationKey(domain: domain, identity: identity)] = Publication(
                store: keystore, requiredTags: required
            )
        }
        // Drop expired injected-store records without retaining test/application stores.
        Self.publications = Self.publications.filter { $0.key.domain == .system || $0.value.store != nil }
    }

    private static func secretTags(for wallet: MetaAccountModel) -> Set<String> {
        Set(secretTagGroups(for: wallet).values.flatMap { $0 })
    }

    private static func secretTagGroups(for wallet: MetaAccountModel) -> [AccountIdentity: Set<String>] {
        let metaId = wallet.metaId
        let entropy = KeystoreTagV2.entropyTagForMetaId(metaId)
        let rootSeed = KeystoreTagV2.substrateSeedTagForMetaId(metaId)
        let bridge = KeystoreTagV2.universalWalletSecretSourceTagForMetaId(metaId)
        var groups: [AccountIdentity: Set<String>] = [:]
        if wallet.substratePublicKey != nil || wallet.substrateAccountId != nil {
            groups[.substrate(metaId)] = [entropy, rootSeed, bridge,
                                          KeystoreTagV2.substrateSecretKeyTagForMetaId(metaId),
                                          KeystoreTagV2.substrateDerivationTagForMetaId(metaId)]
        }
        if wallet.ethereumPublicKey != nil || wallet.ethereumAddress != nil {
            groups[.ethereum(metaId)] = [entropy,
                                         KeystoreTagV2.ethereumSecretKeyTagForMetaId(metaId),
                                         KeystoreTagV2.ethereumDerivationTagForMetaId(metaId),
                                         KeystoreTagV2.ethereumSeedTagForMetaId(metaId)]
        }
        if wallet.legacyTonAccount != nil {
            groups[.ton(metaId)] = [entropy, KeystoreTagV2.tonSecretKeyTagForMetaId(metaId)]
        }
        for account in wallet.chainAccounts {
            let accountId = account.accountId
            var tags: Set<String> = [
                KeystoreTagV2.substrateSecretKeyTagForMetaId(metaId, accountId: accountId),
                KeystoreTagV2.ethereumSecretKeyTagForMetaId(metaId, accountId: accountId),
                KeystoreTagV2.tonSecretKeyTagForMetaId(metaId, accountId: accountId),
                KeystoreTagV2.entropyTagForMetaId(metaId, accountId: accountId),
                KeystoreTagV2.substrateDerivationTagForMetaId(metaId, accountId: accountId),
                KeystoreTagV2.ethereumDerivationTagForMetaId(metaId, accountId: accountId),
                KeystoreTagV2.substrateSeedTagForMetaId(metaId, accountId: accountId),
                KeystoreTagV2.ethereumSeedTagForMetaId(metaId, accountId: accountId)
            ]
            if UniversalWalletRegistry.bitcoinNetwork(for: account.chainId) != nil ||
                UniversalWalletChainAccountSupport.chainId(account.chainId, matches: UniversalWalletRegistry.solanaMainnet.chainId) ||
                UniversalWalletChainAccountSupport.chainId(account.chainId, matches: UniversalWalletRegistry.taira.chainId) {
                // A password wallet derives these accounts with the `///password` its paths carry.
                tags.formUnion([
                    entropy, rootSeed, bridge,
                    KeystoreTagV2.substrateDerivationTagForMetaId(metaId),
                    KeystoreTagV2.ethereumDerivationTagForMetaId(metaId)
                ])
            }
            groups[.chain(metaId, accountId), default: []].formUnion(tags)
        }
        return groups
    }

    func addKey(_ key: Data, with identifier: String) throws {
        try write(key, tag: identifier, updating: false)
    }

    func updateKey(_ key: Data, with identifier: String) throws {
        try write(key, tag: identifier, updating: true)
    }

    func fetchKey(for identifier: String) throws -> Data {
        Self.lock.lock(); defer { Self.lock.unlock() }
        return try keystore.fetchKey(for: identifier)
    }

    func checkKey(for identifier: String) throws -> Bool {
        Self.lock.lock(); defer { Self.lock.unlock() }
        return try keystore.checkKey(for: identifier)
    }

    func deleteKey(for _: String) throws {
        // Import plans only add/update. Arbitrary deletes must not bypass revision ownership.
        throw KeystoreError.unexpectedFail
    }

    func commit() {
        Self.lock.lock(); defer { Self.lock.unlock() }
        guard state == .pending else { return }
        state = .committed
        for tag in touched {
            guard var entry = Self.entries[tag] else { continue }
            for index in entry.revisions.indices where entry.revisions[index].owner == owner {
                entry.revisions[index].state = .committed
            }
            Self.retainOrFinish(entry, for: tag)
        }
    }

    func rollback() throws {
        Self.lock.lock(); defer { Self.lock.unlock() }
        guard state != .committed else { return }
        state = .rolledBack
        try rollback(touched)
    }

    private func rollback(_ tags: Set<Tag>) throws {
        var firstError: Error?
        for tag in tags.sorted(by: { $0.name < $1.name }) {
            guard var entry = Self.entries[tag], entry.revisions.contains(where: { $0.owner == owner }) else { continue }
            for index in entry.revisions.indices where entry.revisions[index].owner == owner {
                entry.revisions[index].state = .rolledBack
            }
            Self.entries[tag] = entry
            do {
                let observed = try value(for: tag.name)
                let desired = entry.desired
                guard observed == entry.visible || observed == desired else {
                    // A different observed write owns the current bytes.
                    Self.entries.removeValue(forKey: tag)
                    continue
                }
                if observed != desired {
                    if let desired {
                        try keystore.saveKey(desired, with: tag.name)
                    } else {
                        try keystore.deleteKeyIfExists(for: tag.name)
                    }
                }
                entry.visible = desired
                Self.retainOrFinish(entry, for: tag)
            } catch {
                // Retain the revision for an explicit retry; do not call failed cleanup success.
                if firstError == nil {
                    firstError = error
                }
            }
        }
        if let firstError {
            throw firstError
        }
    }

    deinit {
        do { try rollback() }
        catch { Logger.shared.error("Import key rollback failed after owner release: \(error.localizedDescription)") }
    }
}

final class PersistenceBoundImportOperation: BaseOperation<MetaAccountModel>, PersistenceBoundKeychainOperation {
    private let transaction: ImportKeychainTransaction
    private let body: (KeystoreProtocol) throws -> MetaAccountModel
    private let previous: MetaAccountModel?

    init(
        keystore: KeystoreProtocol,
        replacing previous: MetaAccountModel? = nil,
        body: @escaping (KeystoreProtocol) throws -> MetaAccountModel
    ) {
        self.previous = previous
        transaction = ImportKeychainTransaction(keystore: keystore)
        self.body = body
        super.init()
    }

    override func main() {
        super.main()
        guard !isCancelled, result == nil else { return }
        do {
            if let previous {
                try transaction.acquireDependencies(of: previous)
            }
            let account = try body(transaction)
            guard !isCancelled else { throw BaseOperationError.parentOperationCancelled }
            try transaction.publish(account, replacing: previous)
            result = .success(account)
        } catch {
            do { try transaction.rollback(); result = .failure(error) }
            catch { result = .failure(error) }
        }
    }

    func commitKeychainChanges() {
        guard case .success? = result else { return }
        transaction.commit()
    }

    func rollbackKeychainChanges() throws {
        try transaction.rollback()
    }
}
