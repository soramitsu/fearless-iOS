import Foundation
import CryptoKit
import IrohaCrypto
import SoraKeystore

protocol KeystoreMigrating: AnyObject {
    func switchVersion() throws
    func registerLegacyAccountRow() throws
    func throwIfResourceLimitExceeded() throws
    func fetchKey(for identifier: String) throws -> Data?
    func deleteKey(for identifier: String)
    func save(key: Data, for identifier: String)
    func prepare() throws
    func finalize() throws
}

extension KeystoreMigrating {
    func registerLegacyAccountRow() throws {}
    func throwIfResourceLimitExceeded() throws {}
}

enum KeystoreMigrationResource: String {
    case legacyAccountRows
    case stagedKeyCount
    case identifierUTF8Bytes
    case stagedKeyBytes
    case deletionCount
    case cleanupJournalBytes
}

struct KeystoreMigrationResourceLimits {
    // A v1 row can produce at most seven v2 keys and four legacy deletions.
    // The byte ceilings remain intentionally independent so a small number of
    // adversarially large keychain values or identifiers still fail closed.
    static let production = KeystoreMigrationResourceLimits(
        maximumLegacyAccountRows: 1024,
        maximumStagedKeyCount: 7168,
        maximumIdentifierUTF8Bytes: 2 * 1024 * 1024,
        maximumStagedKeyBytes: 8 * 1024 * 1024,
        maximumDeletionCount: 4096,
        maximumCleanupJournalBytes: 2 * 1024 * 1024
    )

    let maximumLegacyAccountRows: Int
    let maximumStagedKeyCount: Int
    let maximumIdentifierUTF8Bytes: Int
    let maximumStagedKeyBytes: Int
    let maximumDeletionCount: Int
    let maximumCleanupJournalBytes: Int

    init(
        maximumLegacyAccountRows: Int,
        maximumStagedKeyCount: Int,
        maximumIdentifierUTF8Bytes: Int,
        maximumStagedKeyBytes: Int,
        maximumDeletionCount: Int,
        maximumCleanupJournalBytes: Int
    ) {
        precondition(maximumLegacyAccountRows >= 0)
        precondition(maximumStagedKeyCount >= 0)
        precondition(maximumIdentifierUTF8Bytes >= 0)
        precondition(maximumStagedKeyBytes >= 0)
        precondition(maximumDeletionCount >= 0)
        precondition(maximumCleanupJournalBytes >= 0)

        self.maximumLegacyAccountRows = maximumLegacyAccountRows
        self.maximumStagedKeyCount = maximumStagedKeyCount
        self.maximumIdentifierUTF8Bytes = maximumIdentifierUTF8Bytes
        self.maximumStagedKeyBytes = maximumStagedKeyBytes
        self.maximumDeletionCount = maximumDeletionCount
        self.maximumCleanupJournalBytes = maximumCleanupJournalBytes
    }
}

enum KeystoreMigratingError: LocalizedError {
    case nextVersionMissing
    case destinationNotReached
    case notPrepared
    case resourceLimitExceeded(
        resource: KeystoreMigrationResource,
        maximum: Int
    )
    case stagedKeyConflict(String)
    case stagedKeyVerificationFailed(String)
    case cleanupJournalVerificationFailed
    case invalidCleanupJournalVersion(String)
    case invalidCleanupJournal(String)
    case cleanupDestinationKeyMissing(String)
    case cleanupDestinationKeyVerificationFailed(String)

    var errorDescription: String? {
        switch self {
        case .nextVersionMissing:
            return "The next user-storage version is unavailable"
        case .destinationNotReached:
            return "The user-storage migration did not reach its destination version"
        case .notPrepared:
            return "Replacement keys were not staged before user-storage cleanup"
        case let .resourceLimitExceeded(resource, maximum):
            return """
            The user-storage key migration exceeded the \(resource.rawValue) \
            safety limit of \(maximum)
            """
        case let .stagedKeyConflict(identifier):
            return "Refusing to overwrite an unrelated keychain item at \(identifier)"
        case let .stagedKeyVerificationFailed(identifier):
            return "Unable to verify staged keychain item at \(identifier)"
        case .cleanupJournalVerificationFailed:
            return "Unable to verify the user-storage key cleanup journal"
        case let .invalidCleanupJournalVersion(version):
            return "The user-storage key cleanup journal contains an invalid version: \(version)"
        case let .invalidCleanupJournal(reason):
            return "The user-storage key cleanup journal is invalid: \(reason)"
        case let .cleanupDestinationKeyMissing(identifier):
            return "The migrated keychain item required for cleanup is missing: \(identifier)"
        case let .cleanupDestinationKeyVerificationFailed(identifier):
            return "The migrated keychain item required for cleanup failed verification: \(identifier)"
        }
    }
}

class KeystoreMigrator {
    static let pendingCleanupIdentifier = "io.fearless.user-storage-migration.pending-key-cleanup"
    private static let cleanupJournalSchemaVersion = 1
    private static let legacyDeletionSuffixes = [
        "-secretKey",
        "-entropy",
        "-deriv",
        "-seed"
    ]
    private static let destinationKeySuffixes = [
        "-substrateSecretKey",
        "-ethereumSecretKey",
        "-substrateSeed",
        "-ethereumSeed",
        "-substrateDeriv",
        "-ethereumDeriv",
        "-entropy"
    ]

    private struct CleanupJournal: Codable {
        let schemaVersion: Int
        let sourceVersion: String
        let destinationVersion: String
        let identifiersToRemove: [String]
        let stagedIdentifiers: [String]
        let destinationKeyProofs: [DestinationKeyProof]
    }

    private struct DestinationKeyProof: Codable {
        let identifier: String
        let sha256: Data
    }

    private struct CleanupJournalEnvelope: Decodable {
        let schemaVersion: Int?
        let destinationKeyProofs: [DestinationKeyProof]?
    }

    private struct LegacyCleanupJournal: Decodable {
        let sourceVersion: String
        let destinationVersion: String
        let identifiersToRemove: [String]
        let stagedIdentifiers: [String]
    }

    let sourceVersion: UserStorageVersion
    let destinationVersion: UserStorageVersion
    let keystore: KeystoreProtocol
    let resourceLimits: KeystoreMigrationResourceLimits

    private(set) var currentVersion: UserStorageVersion

    private(set) var identifiersToRemoveOnFinalize: Set<String> = []
    private(set) var tempKeystore: [String: Data] = [:]
    private(set) var isPrepared = false
    private var identifiersStagedDuringPrepare = Set<String>()
    private var stagedKeyConflicts = Set<String>()
    private var migratedLegacyAccountRowCount = 0
    private var retainedIdentifierUTF8ByteCount = 0
    private var stagedKeyByteCount = 0
    // save/delete cannot throw. The first violation is retained and freezes
    // every later mutation until the throwing migration boundary observes it.
    private var resourceLimitError: KeystoreMigratingError?

    init(
        sourceVersion: UserStorageVersion,
        destinationVersion: UserStorageVersion,
        keystore: KeystoreProtocol,
        resourceLimits: KeystoreMigrationResourceLimits = .production
    ) {
        self.sourceVersion = sourceVersion
        self.destinationVersion = destinationVersion
        currentVersion = sourceVersion
        self.keystore = keystore
        self.resourceLimits = resourceLimits
    }
}

extension KeystoreMigrator: KeystoreMigrating {
    func switchVersion() throws {
        if let resourceLimitError {
            throw resourceLimitError
        }

        guard let nextVersion = currentVersion.nextVersion() else {
            throw KeystoreMigratingError.nextVersionMissing
        }

        currentVersion = nextVersion
    }

    func registerLegacyAccountRow() throws {
        if let resourceLimitError {
            throw resourceLimitError
        }

        guard
            let nextCount = checkedAdding(
                1,
                to: migratedLegacyAccountRowCount,
                resource: .legacyAccountRows,
                maximum: resourceLimits.maximumLegacyAccountRows
            )
        else {
            throw resourceLimitError ?? KeystoreMigratingError
                .resourceLimitExceeded(
                    resource: .legacyAccountRows,
                    maximum: resourceLimits.maximumLegacyAccountRows
                )
        }

        migratedLegacyAccountRowCount = nextCount
    }

    func throwIfResourceLimitExceeded() throws {
        if let resourceLimitError {
            throw resourceLimitError
        }
    }

    func fetchKey(for identifier: String) throws -> Data? {
        if let resourceLimitError {
            throw resourceLimitError
        }

        if sourceVersion.nextVersion() == currentVersion {
            do {
                return try keystore.fetchKey(for: identifier)
            } catch KeystoreError.noKeyFound {
                return nil
            }
        } else {
            return tempKeystore[identifier]
        }
    }

    func deleteKey(for identifier: String) {
        guard resourceLimitError == nil else {
            return
        }

        let stagedKey = tempKeystore[identifier]
        let isAlreadyScheduledForDeletion =
            identifiersToRemoveOnFinalize.contains(identifier)

        guard !isAlreadyScheduledForDeletion else {
            return
        }

        guard
            checkedAdding(
                1,
                to: identifiersToRemoveOnFinalize.count,
                resource: .deletionCount,
                maximum: resourceLimits.maximumDeletionCount
            ) != nil
        else {
            return
        }

        if stagedKey == nil {
            guard
                checkedAdding(
                    identifier.utf8.count,
                    to: retainedIdentifierUTF8ByteCount,
                    resource: .identifierUTF8Bytes,
                    maximum: resourceLimits.maximumIdentifierUTF8Bytes
                ) != nil
            else {
                return
            }
        }

        tempKeystore[identifier] = nil
        identifiersToRemoveOnFinalize.insert(identifier)

        if let stagedKey {
            stagedKeyByteCount -= stagedKey.count
        } else {
            retainedIdentifierUTF8ByteCount += identifier.utf8.count
        }
    }

    func save(key: Data, for identifier: String) {
        guard resourceLimitError == nil else {
            return
        }

        if let stagedKey = tempKeystore[identifier], stagedKey != key {
            stagedKeyConflicts.insert(identifier)
            return
        }

        if tempKeystore[identifier] != nil {
            return
        }

        guard
            checkedAdding(
                1,
                to: tempKeystore.count,
                resource: .stagedKeyCount,
                maximum: resourceLimits.maximumStagedKeyCount
            ) != nil
        else {
            return
        }

        let isMovingFromDeletion =
            identifiersToRemoveOnFinalize.contains(identifier)

        if !isMovingFromDeletion {
            guard
                checkedAdding(
                    identifier.utf8.count,
                    to: retainedIdentifierUTF8ByteCount,
                    resource: .identifierUTF8Bytes,
                    maximum: resourceLimits.maximumIdentifierUTF8Bytes
                ) != nil
            else {
                return
            }
        }

        guard
            checkedAdding(
                key.count,
                to: stagedKeyByteCount,
                resource: .stagedKeyBytes,
                maximum: resourceLimits.maximumStagedKeyBytes
            ) != nil
        else {
            return
        }

        tempKeystore[identifier] = key
        identifiersToRemoveOnFinalize.remove(identifier)
        stagedKeyByteCount += key.count

        if !isMovingFromDeletion {
            retainedIdentifierUTF8ByteCount += identifier.utf8.count
        }
    }

    func prepare() throws {
        if let resourceLimitError {
            throw resourceLimitError
        }

        guard currentVersion == destinationVersion else {
            throw KeystoreMigratingError.destinationNotReached
        }

        if let identifier = stagedKeyConflicts.sorted().first {
            throw KeystoreMigratingError.stagedKeyConflict(identifier)
        }

        guard !tempKeystore.isEmpty || !identifiersToRemoveOnFinalize.isEmpty else {
            isPrepared = true
            return
        }

        var identifiersNeedingWrite = Set<String>()

        for identifier in tempKeystore.keys.sorted() {
            guard let key = tempKeystore[identifier] else {
                continue
            }

            if try keystore.checkKey(for: identifier) {
                guard try keystore.fetchKey(for: identifier) == key else {
                    throw KeystoreMigratingError.stagedKeyConflict(identifier)
                }
            } else {
                identifiersNeedingWrite.insert(identifier)
            }
        }

        identifiersStagedDuringPrepare.formUnion(identifiersNeedingWrite)

        let journal = CleanupJournal(
            schemaVersion: Self.cleanupJournalSchemaVersion,
            sourceVersion: sourceVersion.rawValue,
            destinationVersion: destinationVersion.rawValue,
            identifiersToRemove: identifiersToRemoveOnFinalize.sorted(),
            stagedIdentifiers: identifiersStagedDuringPrepare.sorted(),
            destinationKeyProofs: tempKeystore
                .map { identifier, key in
                    DestinationKeyProof(
                        identifier: identifier,
                        sha256: Self.digest(for: key)
                    )
                }
                .sorted { $0.identifier < $1.identifier }
        )
        try Self.validate(
            journal,
            resourceLimits: resourceLimits
        )

        let journalData = try Self.encode(journal)
        guard
            journalData.count <=
            resourceLimits.maximumCleanupJournalBytes
        else {
            let error = recordResourceLimitError(
                resource: .cleanupJournalBytes,
                maximum: resourceLimits.maximumCleanupJournalBytes
            )
            throw error
        }

        try keystore.saveKey(journalData, with: Self.pendingCleanupIdentifier)

        guard
            try keystore.fetchKey(for: Self.pendingCleanupIdentifier) == journalData
        else {
            throw KeystoreMigratingError.cleanupJournalVerificationFailed
        }

        for identifier in identifiersNeedingWrite.sorted() {
            guard let key = tempKeystore[identifier] else {
                continue
            }

            try keystore.addKey(key, with: identifier)
        }

        for identifier in tempKeystore.keys.sorted() {
            guard
                let expectedKey = tempKeystore[identifier],
                try keystore.fetchKey(for: identifier) == expectedKey
            else {
                throw KeystoreMigratingError.stagedKeyVerificationFailed(identifier)
            }
        }

        isPrepared = true
    }

    func finalize() throws {
        if let resourceLimitError {
            throw resourceLimitError
        }

        guard currentVersion == destinationVersion else {
            throw KeystoreMigratingError.destinationNotReached
        }

        guard isPrepared else {
            throw KeystoreMigratingError.notPrepared
        }

        guard !tempKeystore.isEmpty || !identifiersToRemoveOnFinalize.isEmpty else {
            return
        }

        try Self.verifyDestinationKeys(
            CleanupJournal(
                schemaVersion: Self.cleanupJournalSchemaVersion,
                sourceVersion: sourceVersion.rawValue,
                destinationVersion: destinationVersion.rawValue,
                identifiersToRemove: identifiersToRemoveOnFinalize.sorted(),
                stagedIdentifiers: identifiersStagedDuringPrepare.sorted(),
                destinationKeyProofs: tempKeystore
                    .map { identifier, key in
                        DestinationKeyProof(
                            identifier: identifier,
                            sha256: Self.digest(for: key)
                        )
                    }
                    .sorted { $0.identifier < $1.identifier }
            ).destinationKeyProofs,
            in: keystore,
            resourceLimits: resourceLimits
        )

        try Self.removeKeys(
            identifiersToRemoveOnFinalize.sorted(),
            from: keystore
        )
        try Self.deleteKeyIfPresent(
            Self.pendingCleanupIdentifier,
            from: keystore
        )
    }
}

private extension KeystoreMigrator {
    func checkedAdding(
        _ increment: Int,
        to current: Int,
        resource: KeystoreMigrationResource,
        maximum: Int
    ) -> Int? {
        let (result, overflow) = current.addingReportingOverflow(increment)

        guard !overflow, result <= maximum else {
            _ = recordResourceLimitError(
                resource: resource,
                maximum: maximum
            )

            return nil
        }

        return result
    }

    func recordResourceLimitError(
        resource: KeystoreMigrationResource,
        maximum: Int
    ) -> KeystoreMigratingError {
        if let resourceLimitError {
            return resourceLimitError
        }

        let error = KeystoreMigratingError.resourceLimitExceeded(
            resource: resource,
            maximum: maximum
        )
        resourceLimitError = error

        return error
    }
}

extension KeystoreMigrator {
    static func recoverPendingCleanup(
        keystore: KeystoreProtocol,
        currentVersion: UserStorageVersion
    ) throws {
        let journalData: Data

        do {
            journalData = try keystore.fetchKey(for: pendingCleanupIdentifier)
        } catch KeystoreError.noKeyFound {
            return
        }

        guard
            journalData.count <=
            KeystoreMigrationResourceLimits.production
            .maximumCleanupJournalBytes
        else {
            throw KeystoreMigratingError.resourceLimitExceeded(
                resource: .cleanupJournalBytes,
                maximum: KeystoreMigrationResourceLimits.production
                    .maximumCleanupJournalBytes
            )
        }

        let decoder = JSONDecoder()
        let envelope = try decoder.decode(
            CleanupJournalEnvelope.self,
            from: journalData
        )

        if envelope.schemaVersion == nil {
            guard envelope.destinationKeyProofs == nil else {
                throw KeystoreMigratingError.invalidCleanupJournal(
                    "a destination proof list has no schema version"
                )
            }

            let legacyJournal = try decoder.decode(
                LegacyCleanupJournal.self,
                from: journalData
            )
            try recoverLegacyCleanupJournal(
                legacyJournal,
                keystore: keystore,
                currentVersion: currentVersion
            )
            return
        }

        let journal = try decoder.decode(CleanupJournal.self, from: journalData)
        try validate(
            journal,
            resourceLimits: .production
        )

        guard let sourceVersion = UserStorageVersion(rawValue: journal.sourceVersion) else {
            throw KeystoreMigratingError.invalidCleanupJournalVersion(journal.sourceVersion)
        }

        guard let destinationVersion = UserStorageVersion(rawValue: journal.destinationVersion) else {
            throw KeystoreMigratingError.invalidCleanupJournalVersion(journal.destinationVersion)
        }

        if currentVersion.isSameOrNewer(than: destinationVersion) {
            try verifyDestinationKeys(
                journal.destinationKeyProofs,
                in: keystore,
                resourceLimits: .production
            )
            try removeKeys(journal.identifiersToRemove, from: keystore)
            try deleteKeyIfPresent(pendingCleanupIdentifier, from: keystore)
        } else if currentVersion == sourceVersion {
            try verifyAndRemoveRollbackKeys(
                journal.stagedIdentifiers,
                destinationKeyProofs: journal.destinationKeyProofs,
                from: keystore,
                resourceLimits: .production
            )
            try deleteKeyIfPresent(pendingCleanupIdentifier, from: keystore)
        } else {
            throw KeystoreMigratingError.invalidCleanupJournal(
                "the database version does not match the journal boundary"
            )
        }
    }

    private static func recoverLegacyCleanupJournal(
        _ journal: LegacyCleanupJournal,
        keystore: KeystoreProtocol,
        currentVersion: UserStorageVersion
    ) throws {
        try validateResourceLimits(
            identifiersToRemove: journal.identifiersToRemove,
            stagedIdentifiers: journal.stagedIdentifiers,
            destinationProofIdentifiers: journal.stagedIdentifiers,
            resourceLimits: .production
        )

        let versions = try validateVersions(
            sourceVersion: journal.sourceVersion,
            destinationVersion: journal.destinationVersion
        )
        let identifiersToRemove = Set(journal.identifiersToRemove)
        let stagedIdentifiers = Set(journal.stagedIdentifiers)

        guard identifiersToRemove.count == journal.identifiersToRemove.count else {
            throw KeystoreMigratingError.invalidCleanupJournal(
                "duplicate legacy identifiers"
            )
        }

        guard stagedIdentifiers.count == journal.stagedIdentifiers.count else {
            throw KeystoreMigratingError.invalidCleanupJournal(
                "duplicate staged identifiers"
            )
        }

        let allIdentifiers = identifiersToRemove.union(stagedIdentifiers)

        guard !allIdentifiers.contains(where: \.isEmpty) else {
            throw KeystoreMigratingError.invalidCleanupJournal(
                "empty keychain identifier"
            )
        }

        guard !allIdentifiers.contains(pendingCleanupIdentifier) else {
            throw KeystoreMigratingError.invalidCleanupJournal(
                "the cleanup journal identifier is reserved"
            )
        }

        guard identifiersToRemove.isDisjoint(with: stagedIdentifiers) else {
            throw KeystoreMigratingError.invalidCleanupJournal(
                "a staged identifier appears in the legacy deletion list"
            )
        }

        try validateLegacyDeletionIdentifiers(identifiersToRemove)
        try validateDestinationIdentifiers(stagedIdentifiers)

        guard
            currentVersion == versions.source ||
            currentVersion.isSameOrNewer(than: versions.destination)
        else {
            throw KeystoreMigratingError.invalidCleanupJournal(
                "the database version does not match the journal boundary"
            )
        }

        // Legacy journals contain no integrity proof. Clearing only the journal
        // preserves every user and staged key while allowing a source store to
        // rerun migration with the current verified two-phase protocol.
        try deleteKeyIfPresent(pendingCleanupIdentifier, from: keystore)
    }

    private static func validate(
        _ journal: CleanupJournal,
        resourceLimits: KeystoreMigrationResourceLimits
    ) throws {
        try validateResourceLimits(
            identifiersToRemove: journal.identifiersToRemove,
            stagedIdentifiers: journal.stagedIdentifiers,
            destinationProofIdentifiers:
            journal.destinationKeyProofs.map(\.identifier),
            resourceLimits: resourceLimits
        )

        guard journal.schemaVersion == cleanupJournalSchemaVersion else {
            throw KeystoreMigratingError.invalidCleanupJournal(
                "unsupported schema version \(journal.schemaVersion)"
            )
        }

        _ = try validateVersions(
            sourceVersion: journal.sourceVersion,
            destinationVersion: journal.destinationVersion
        )

        let identifiersToRemove = Set(journal.identifiersToRemove)
        let stagedIdentifiers = Set(journal.stagedIdentifiers)
        let destinationIdentifiers = Set(journal.destinationKeyProofs.map(\.identifier))

        guard identifiersToRemove.count == journal.identifiersToRemove.count else {
            throw KeystoreMigratingError.invalidCleanupJournal(
                "duplicate legacy identifiers"
            )
        }

        guard stagedIdentifiers.count == journal.stagedIdentifiers.count else {
            throw KeystoreMigratingError.invalidCleanupJournal(
                "duplicate staged identifiers"
            )
        }

        guard destinationIdentifiers.count == journal.destinationKeyProofs.count else {
            throw KeystoreMigratingError.invalidCleanupJournal(
                "duplicate destination key proofs"
            )
        }

        let allIdentifiers = identifiersToRemove
            .union(stagedIdentifiers)
            .union(destinationIdentifiers)

        guard !allIdentifiers.contains(where: \.isEmpty) else {
            throw KeystoreMigratingError.invalidCleanupJournal(
                "empty keychain identifier"
            )
        }

        guard !allIdentifiers.contains(pendingCleanupIdentifier) else {
            throw KeystoreMigratingError.invalidCleanupJournal(
                "the cleanup journal identifier is reserved"
            )
        }

        guard identifiersToRemove.isDisjoint(with: destinationIdentifiers) else {
            throw KeystoreMigratingError.invalidCleanupJournal(
                "a destination identifier appears in the legacy deletion list"
            )
        }

        try validateLegacyDeletionIdentifiers(identifiersToRemove)
        try validateDestinationIdentifiers(destinationIdentifiers)

        guard stagedIdentifiers.isSubset(of: destinationIdentifiers) else {
            throw KeystoreMigratingError.invalidCleanupJournal(
                "a staged identifier has no destination integrity proof"
            )
        }

        guard identifiersToRemove.isEmpty || !destinationIdentifiers.isEmpty else {
            throw KeystoreMigratingError.invalidCleanupJournal(
                "legacy deletion has no destination integrity proof"
            )
        }

        guard journal.destinationKeyProofs.allSatisfy({ $0.sha256.count == SHA256.byteCount }) else {
            throw KeystoreMigratingError.invalidCleanupJournal(
                "a destination integrity proof has an invalid digest"
            )
        }
    }

    private static func validateVersions(
        sourceVersion: String,
        destinationVersion: String
    ) throws -> (
        source: UserStorageVersion,
        destination: UserStorageVersion
    ) {
        guard
            let source = UserStorageVersion(rawValue: sourceVersion),
            let destination = UserStorageVersion(rawValue: destinationVersion),
            source != destination,
            destination.isSameOrNewer(than: source)
        else {
            throw KeystoreMigratingError.invalidCleanupJournal(
                "source and destination versions do not form a valid forward migration"
            )
        }

        return (source, destination)
    }

    private static func validateResourceLimits(
        identifiersToRemove: [String],
        stagedIdentifiers: [String],
        destinationProofIdentifiers: [String],
        resourceLimits: KeystoreMigrationResourceLimits
    ) throws {
        guard
            identifiersToRemove.count <=
            resourceLimits.maximumDeletionCount
        else {
            throw KeystoreMigratingError.resourceLimitExceeded(
                resource: .deletionCount,
                maximum: resourceLimits.maximumDeletionCount
            )
        }

        guard
            stagedIdentifiers.count <=
            resourceLimits.maximumStagedKeyCount,
            destinationProofIdentifiers.count <=
            resourceLimits.maximumStagedKeyCount
        else {
            throw KeystoreMigratingError.resourceLimitExceeded(
                resource: .stagedKeyCount,
                maximum: resourceLimits.maximumStagedKeyCount
            )
        }

        let uniqueIdentifiers = Set(
            identifiersToRemove +
                stagedIdentifiers +
                destinationProofIdentifiers
        )
        var aggregateIdentifierBytes = 0

        for identifier in uniqueIdentifiers {
            let (nextCount, overflow) =
                aggregateIdentifierBytes.addingReportingOverflow(
                    identifier.utf8.count
                )

            guard
                !overflow,
                nextCount <=
                resourceLimits.maximumIdentifierUTF8Bytes
            else {
                throw KeystoreMigratingError.resourceLimitExceeded(
                    resource: .identifierUTF8Bytes,
                    maximum: resourceLimits
                        .maximumIdentifierUTF8Bytes
                )
            }

            aggregateIdentifierBytes = nextCount
        }
    }

    private static func encode(_ journal: CleanupJournal) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        return try encoder.encode(journal)
    }

    private static func validateLegacyDeletionIdentifiers(
        _ identifiers: Set<String>
    ) throws {
        guard identifiers.allSatisfy(isLegacyDeletionIdentifier) else {
            throw KeystoreMigratingError.invalidCleanupJournal(
                "the legacy deletion list contains a non-migration keychain identifier"
            )
        }
    }

    private static func validateDestinationIdentifiers(
        _ identifiers: Set<String>
    ) throws {
        guard identifiers.allSatisfy(isDestinationMigrationIdentifier) else {
            throw KeystoreMigratingError.invalidCleanupJournal(
                "the destination list contains a non-migration keychain identifier"
            )
        }
    }

    private static func isLegacyDeletionIdentifier(
        _ identifier: String
    ) -> Bool {
        guard
            let suffix = legacyDeletionSuffixes.first(
                where: identifier.hasSuffix
            ),
            identifier.count > suffix.count
        else {
            return false
        }

        let address = String(identifier.dropLast(suffix.count))

        do {
            _ = try SS58AddressFactory().accountId(from: address)
            return true
        } catch {
            return false
        }
    }

    private static func isDestinationMigrationIdentifier(
        _ identifier: String
    ) -> Bool {
        guard
            let suffix = destinationKeySuffixes.first(
                where: identifier.hasSuffix
            ),
            identifier.count > suffix.count
        else {
            return false
        }

        let metaId = String(identifier.dropLast(suffix.count))

        return UUID(uuidString: metaId) != nil
    }

    private static func verifyDestinationKeys(
        _ proofs: [DestinationKeyProof],
        in keystore: KeystoreProtocol,
        resourceLimits: KeystoreMigrationResourceLimits
    ) throws {
        var aggregateKeyBytes = 0

        for proof in proofs {
            let key: Data

            do {
                key = try keystore.fetchKey(for: proof.identifier)
            } catch KeystoreError.noKeyFound {
                throw KeystoreMigratingError.cleanupDestinationKeyMissing(
                    proof.identifier
                )
            }

            aggregateKeyBytes = try checkedResourceTotal(
                aggregateKeyBytes,
                adding: key.count,
                resource: .stagedKeyBytes,
                maximum: resourceLimits.maximumStagedKeyBytes
            )

            guard digest(for: key) == proof.sha256 else {
                throw KeystoreMigratingError.cleanupDestinationKeyVerificationFailed(
                    proof.identifier
                )
            }
        }
    }

    private static func verifyAndRemoveRollbackKeys(
        _ identifiers: [String],
        destinationKeyProofs: [DestinationKeyProof],
        from keystore: KeystoreProtocol,
        resourceLimits: KeystoreMigrationResourceLimits
    ) throws {
        let proofsByIdentifier = Dictionary(
            uniqueKeysWithValues: destinationKeyProofs.map {
                ($0.identifier, $0)
            }
        )
        var identifiersPresent = [String]()
        var aggregateKeyBytes = 0

        for identifier in identifiers {
            guard let proof = proofsByIdentifier[identifier] else {
                throw KeystoreMigratingError.invalidCleanupJournal(
                    "a staged identifier has no destination integrity proof"
                )
            }

            let key: Data

            do {
                key = try keystore.fetchKey(for: identifier)
            } catch KeystoreError.noKeyFound {
                continue
            }

            aggregateKeyBytes = try checkedResourceTotal(
                aggregateKeyBytes,
                adding: key.count,
                resource: .stagedKeyBytes,
                maximum: resourceLimits.maximumStagedKeyBytes
            )

            guard digest(for: key) == proof.sha256 else {
                throw KeystoreMigratingError.cleanupDestinationKeyVerificationFailed(
                    identifier
                )
            }

            identifiersPresent.append(identifier)
        }

        try removeKeys(identifiersPresent, from: keystore)
    }

    private static func checkedResourceTotal(
        _ current: Int,
        adding increment: Int,
        resource: KeystoreMigrationResource,
        maximum: Int
    ) throws -> Int {
        let (result, overflow) = current.addingReportingOverflow(increment)

        guard !overflow, result <= maximum else {
            throw KeystoreMigratingError.resourceLimitExceeded(
                resource: resource,
                maximum: maximum
            )
        }

        return result
    }

    private static func digest(for key: Data) -> Data {
        Data(SHA256.hash(data: key))
    }

    private static func removeKeys(
        _ identifiers: [String],
        from keystore: KeystoreProtocol
    ) throws {
        for identifier in identifiers {
            try deleteKeyIfPresent(identifier, from: keystore)
        }
    }

    private static func deleteKeyIfPresent(
        _ identifier: String,
        from keystore: KeystoreProtocol
    ) throws {
        guard try keystore.checkKey(for: identifier) else {
            return
        }

        do {
            try keystore.deleteKey(for: identifier)
        } catch KeystoreError.noKeyFound {
            // Another cleanup attempt already removed it.
        }
    }
}

private extension UserStorageVersion {
    func isSameOrNewer(than version: UserStorageVersion) -> Bool {
        var candidate: UserStorageVersion? = version

        while let unwrappedCandidate = candidate {
            if unwrappedCandidate == self {
                return true
            }

            candidate = unwrappedCandidate.nextVersion()
        }

        return false
    }
}
