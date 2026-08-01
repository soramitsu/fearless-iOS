import CoreData
import CryptoKit
import Darwin
import Foundation
import SQLite3

enum SubstrateStorageMigrationOperation: String {
    case sourceMetadata = "source metadata inspection"
    case sourceCheckpoint = "private source checkpoint"
    case transformableSanitization = "private source transformable repair"
    case sourceRowInspection = "private source row inspection"
    case protectedDataInspection = "protected local-data inspection"
    case stagedMigration = "staged migration"
    case stagedValidation = "staged-store validation"
}

enum SubstrateStorageMigrationError: LocalizedError {
    case metadataUnreadable(URL, Error)
    case unknownStoreVersion(URL)
    case modelUnavailable(SubstrateStorageVersion)
    case migrationPathUnavailable(SubstrateStorageVersion, SubstrateStorageVersion)
    case mappingUnavailable(SubstrateStorageVersion, SubstrateStorageVersion, Error)
    case sourceSnapshotFailed(URL, Error)
    case walCheckpointFailed(URL, Error)
    case transformableSanitizationFailed(SubstrateStorageVersion, Error)
    case unsupportedTransformableAttribute(SubstrateStorageVersion, String, String)
    case objectiveCException(SubstrateStorageMigrationOperation)
    case temporaryDirectoryCreationFailed(URL, Error)
    case temporaryStoreCleanupFailed(URL, Error)
    case migrationStepFailed(SubstrateStorageVersion, SubstrateStorageVersion, Error)
    case sourceStoreInspectionFailed(URL, Error)
    case protectedDataInspectionRejected(URL, Error)
    case stagedStoreMetadataUnreadable(URL, Error)
    case stagedStoreInvalid(URL, SubstrateStorageVersion)
    case stagedStoreInspectionFailed(URL, Error)
    case stagedStoreRowCountMismatch(String, Int, Int)
    case stagedStoreProtectedDataMismatch
    case storeReplacementFailed(URL, Error)
    case cacheRecoveryBlockedByProtectedData(URL, Error, [String: Int])
    case pendingCacheRecoveryFailed(URL, Error)
    case cacheRecoveryFailed(URL, Error, Error)

    var errorDescription: String? {
        switch self {
        case let .metadataUnreadable(url, error):
            return "Unable to read Substrate store metadata at \(url.path): \(error.localizedDescription)"
        case let .unknownStoreVersion(url):
            return "Unsupported Substrate store version at \(url.path)"
        case let .modelUnavailable(version):
            return "Substrate store model is unavailable for \(version.rawValue)"
        case let .migrationPathUnavailable(source, destination):
            return "No forward Substrate store migration path from \(source.rawValue) to \(destination.rawValue)"
        case let .mappingUnavailable(source, destination, error):
            return """
            Unable to create the Substrate store mapping from \(source.rawValue) \
            to \(destination.rawValue): \(error.localizedDescription)
            """
        case let .sourceSnapshotFailed(url, error):
            return """
            Unable to create a private Substrate store snapshot for \(url.path): \
            \(error.localizedDescription)
            """
        case let .walCheckpointFailed(url, error):
            return "Unable to checkpoint Substrate store at \(url.path): \(error.localizedDescription)"
        case let .transformableSanitizationFailed(version, error):
            return """
            Unable to safely repair cached values in the private \(version.rawValue) \
            Substrate store copy: \(error.localizedDescription)
            """
        case let .unsupportedTransformableAttribute(version, entityName, attributeName):
            return """
            The \(version.rawValue) Substrate model contains an unsupported cached value at \
            \(entityName).\(attributeName)
            """
        case let .objectiveCException(operation):
            return "Substrate storage safely stopped during \(operation.rawValue)"
        case let .temporaryDirectoryCreationFailed(url, error):
            return "Unable to create Substrate migration directory at \(url.path): \(error.localizedDescription)"
        case let .temporaryStoreCleanupFailed(url, error):
            return """
            Unable to remove a completed temporary Substrate migration store at \
            \(url.path): \(error.localizedDescription)
            """
        case let .migrationStepFailed(source, destination, error):
            return """
            Substrate store migration from \(source.rawValue) to \(destination.rawValue) \
            failed: \(error.localizedDescription)
            """
        case let .sourceStoreInspectionFailed(url, error):
            return "Unable to inspect Substrate store rows at \(url.path): \(error.localizedDescription)"
        case let .protectedDataInspectionRejected(url, error):
            return """
            Protected-data inspection rejected the store at \(url.path): \
            \(error.localizedDescription)
            """
        case let .stagedStoreMetadataUnreadable(url, error):
            return "Unable to read staged Substrate store metadata at \(url.path): \(error.localizedDescription)"
        case let .stagedStoreInvalid(url, destination):
            return "Staged Substrate store at \(url.path) is not compatible with \(destination.rawValue)"
        case let .stagedStoreInspectionFailed(url, error):
            return "Unable to inspect staged Substrate store rows at \(url.path): \(error.localizedDescription)"
        case let .stagedStoreRowCountMismatch(entity, expected, actual):
            return """
            Staged Substrate store changed the \(entity) row count from \(expected) to \(actual)
            """
        case .stagedStoreProtectedDataMismatch:
            return """
            Staged Substrate store changed protected local values or node relationships
            """
        case let .storeReplacementFailed(url, error):
            return "Unable to replace Substrate store at \(url.path): \(error.localizedDescription)"
        case let .cacheRecoveryBlockedByProtectedData(url, migrationError, counts):
            let protectedData = counts
                .filter { $0.value > 0 }
                .sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: ", ")

            return """
            Refusing to rebuild the Substrate store at \(url.path) after \
            \(migrationError.localizedDescription) because it contains protected local data: \
            \(protectedData)
            """
        case let .pendingCacheRecoveryFailed(url, error):
            return """
            Unable to reconcile an interrupted Substrate cache recovery at \(url.path): \
            \(error.localizedDescription)
            """
        case let .cacheRecoveryFailed(url, migrationError, recoveryError):
            return """
            Unable to quarantine the rebuildable Substrate cache at \(url.path) after \
            \(migrationError.localizedDescription): \(recoveryError.localizedDescription)
            """
        }
    }

    var allowsCacheRebuild: Bool {
        switch self {
        case .modelUnavailable,
             .migrationPathUnavailable,
             .sourceSnapshotFailed,
             .temporaryDirectoryCreationFailed,
             .temporaryStoreCleanupFailed,
             .metadataUnreadable,
             .unknownStoreVersion,
             .transformableSanitizationFailed,
             .unsupportedTransformableAttribute,
             .objectiveCException,
             .sourceStoreInspectionFailed,
             .protectedDataInspectionRejected,
             .stagedStoreProtectedDataMismatch,
             .storeReplacementFailed,
             .cacheRecoveryBlockedByProtectedData,
             .pendingCacheRecoveryFailed,
             .cacheRecoveryFailed:
            return false
        case .mappingUnavailable,
             .walCheckpointFailed,
             .migrationStepFailed,
             .stagedStoreMetadataUnreadable,
             .stagedStoreInvalid,
             .stagedStoreInspectionFailed,
             .stagedStoreRowCountMismatch:
            return true
        }
    }
}

private enum SubstrateCustomMappingError: LocalizedError {
    case resourceUnavailable(String)
    case resourceUnreadable(String)
    case incompatible(String)
    case policyUnavailable(String, String)

    var errorDescription: String? {
        switch self {
        case let .resourceUnavailable(resourceName):
            return "Required Substrate mapping \(resourceName).cdm is not bundled"
        case let .resourceUnreadable(resourceName):
            return "Required Substrate mapping \(resourceName).cdm cannot be loaded"
        case let .incompatible(resourceName):
            return "Required Substrate mapping \(resourceName).cdm does not match the bundled models"
        case let .policyUnavailable(resourceName, policyClassName):
            return """
            Required Substrate mapping \(resourceName).cdm does not use \
            \(policyClassName) for CDChain
            """
        }
    }
}

enum SubstrateCacheRecoveryBoundary: Equatable {
    case markerPersisted
    case familyMemberMoved(String)
    case legacyFamilyMemberRestored(String)
    case markerRemoved
    case retentionMarkerPersisted(String)
    case retentionFamilyMemberRemoved(String, String)
    case retentionMarkerRemoved(String)
    case retentionArchiveRemoved(String)
}

enum SubstrateCacheRecoveryInterruption: Error {
    /// Test-only fault used to emulate process death without Swift unwinding.
    case simulatedProcessDeath
}

enum SubstrateCacheRecoveryTransactionError: LocalizedError {
    case sourceStoreMissing
    case unsafeFile(URL)
    case unsafeDirectory(URL)
    case invalidMarker
    case markerTooLarge
    case familyMismatch
    case multiplePendingTransactions
    case archiveScanLimitExceeded(Int)
    case archiveByteScanLimitExceeded(UInt64)
    case backupExclusionFailed(URL, Error)
    case fileSynchronizationFailed(URL, Error)
    case directorySynchronizationFailed(URL, Error)

    var errorDescription: String? {
        switch self {
        case .sourceStoreMissing:
            return "The rebuildable Substrate cache store is missing"
        case .unsafeFile:
            return "The Substrate cache recovery transaction contains an unsafe file"
        case .unsafeDirectory:
            return "The Substrate cache recovery transaction contains an unsafe directory"
        case .invalidMarker:
            return "The Substrate cache recovery marker is invalid"
        case .markerTooLarge:
            return "The Substrate cache recovery marker is too large"
        case .familyMismatch:
            return "The Substrate cache family does not match its durable recovery manifest"
        case .multiplePendingTransactions:
            return "More than one Substrate cache recovery transaction is pending"
        case let .archiveScanLimitExceeded(maximum):
            return """
            Substrate cache recovery contains more than \(maximum) archive \
            directories and cannot be scanned safely
            """
        case let .archiveByteScanLimitExceeded(maximum):
            return """
            Substrate cache recovery exceeds the safe \(maximum)-byte archive \
            inspection budget
            """
        case let .backupExclusionFailed(url, error):
            return """
            Unable to exclude the Substrate cache recovery archive at \(url.path) \
            from device backup: \(error.localizedDescription)
            """
        case let .fileSynchronizationFailed(_, error):
            return "Unable to synchronize a Substrate cache recovery file: \(error.localizedDescription)"
        case let .directorySynchronizationFailed(_, error):
            return "Unable to synchronize a Substrate cache recovery directory: \(error.localizedDescription)"
        }
    }
}

/// Moves a verified cache-only SQLite family into quarantine using a durable,
/// bounded transaction. A relaunch deterministically finishes any family move
/// or retention deletion interrupted after its marker became durable.
/// Completed archives are excluded from backup and the newest two are retained
/// subject to a combined 128 MiB byte budget.
/// Recovery invariants remain in one auditable state machine.
final class CrashConsistentSubstrateCacheRecovery { // swiftlint:disable:this type_body_length
    private enum Operation: String {
        case quarantine
        case restoreLegacy = "restore-legacy"
        case deleteArchive = "delete-archive"
    }

    private struct FamilyMember: Equatable {
        let suffix: String
        let byteCount: UInt64
        let sha256: String
    }

    private struct Marker: Equatable {
        let operation: Operation
        let storePathSHA256: String
        let family: [FamilyMember]
        let restoreSuffixes: [String]
    }

    private enum PathKind {
        case missing
        case regularFile
        case directory
        case symbolicLink
        case other
    }

    private struct FileIdentity: Hashable {
        let deviceID: UInt64
        let inode: UInt64
    }

    private struct ArchiveCompletionTime: Equatable {
        let seconds: Int64
        let nanoseconds: Int64
    }

    private struct CompletedArchive {
        let url: URL
        let family: [FamilyMember]
        let byteCount: UInt64
        let completionTime: ArchiveCompletionTime
    }

    private struct CompletedArchivePreflight {
        let url: URL
        let byteCount: UInt64
        let completionTime: ArchiveCompletionTime
    }

    static let storeFamilySuffixes = ["", "-wal", "-shm", "-journal"]

    private static let markerHeader = "fearless-substrate-cache-recovery-v1"
    private static let markerFileName = "recovery-transaction"
    private static let markerTemporaryFileName = "recovery-transaction.pending"
    private static let maximumMarkerByteCount: UInt64 = 4 * 1024
    private static let digestChunkByteCount = 1024 * 1024
    private static let recoveryRootName = "SubstrateStoreRecovery"
    private static let restorationTemporarySuffix =
        ".cache-recovery-restore.pending"
    private static let maximumArchiveDirectoryScanCount = 64
    private static let maximumArchiveByteScanCount: UInt64 =
        512 * 1024 * 1024
    static let defaultRetainedArchiveCount = 2
    static let defaultRetainedArchiveByteCount: UInt64 =
        128 * 1024 * 1024

    let storeURL: URL
    let recoveryRootURL: URL

    private let fileManager: FileManager
    private let boundaryHook: (SubstrateCacheRecoveryBoundary) throws -> Void
    private let restorationTemporaryFileSynchronizationHook:
        (URL) throws -> Void
    private let directorySynchronizationHook: (URL) throws -> Void
    private let backupExclusionHook: (URL) throws -> Void
    private let retainedArchiveCount: Int
    private let retainedArchiveByteCount: UInt64

    private var databaseDirectoryURL: URL {
        storeURL.deletingLastPathComponent()
    }

    private var storePathSHA256: String {
        Self.digest(data: Data(storeURL.path.utf8))
    }

    var hasPendingTransaction: Bool {
        switch pathKind(at: recoveryRootURL) {
        case .missing:
            return false
        case .directory:
            break
        case .regularFile, .symbolicLink, .other:
            return true
        }

        guard
            let candidateURLs = try?
            boundedRecoveryDirectoryURLs()
        else {
            return true
        }

        return candidateURLs.contains { candidateURL in
            guard pathKind(at: candidateURL) == .directory else {
                return true
            }

            if pathKind(
                at: markerURL(in: candidateURL)
            ) != .missing ||
                pathKind(
                    at: markerTemporaryURL(in: candidateURL)
                ) != .missing {
                return true
            }

            guard
                let contents = try? boundedImmediateChildURLs(
                    at: candidateURL,
                    maximumCount: Self.storeFamilySuffixes.count,
                    overflowError:
                    SubstrateCacheRecoveryTransactionError
                        .unsafeDirectory(candidateURL)
                )
            else {
                return true
            }
            return contents.isEmpty
        }
    }

    init(
        storeURL: URL,
        fileManager: FileManager,
        boundaryHook: @escaping (
            SubstrateCacheRecoveryBoundary
        ) throws -> Void = { _ in },
        restorationTemporaryFileSynchronizationHook:
        @escaping (URL) throws -> Void = { _ in },
        directorySynchronizationHook:
        @escaping (URL) throws -> Void = { _ in },
        backupExclusionHook: ((URL) throws -> Void)? = nil,
        retainedArchiveCount: Int =
            CrashConsistentSubstrateCacheRecovery
                .defaultRetainedArchiveCount,
        retainedArchiveByteCount: UInt64 =
            CrashConsistentSubstrateCacheRecovery
                .defaultRetainedArchiveByteCount
    ) {
        precondition(retainedArchiveCount >= 0)

        self.storeURL = storeURL.standardizedFileURL
        self.fileManager = fileManager
        self.boundaryHook = boundaryHook
        self.restorationTemporaryFileSynchronizationHook =
            restorationTemporaryFileSynchronizationHook
        self.directorySynchronizationHook =
            directorySynchronizationHook
        self.backupExclusionHook = backupExclusionHook ?? {
            url in
            var resourceURL = url
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try resourceURL.setResourceValues(values)
        }
        self.retainedArchiveCount = retainedArchiveCount
        self.retainedArchiveByteCount = retainedArchiveByteCount
        recoveryRootURL = self.storeURL
            .deletingLastPathComponent()
            .appendingPathComponent(
                Self.recoveryRootName,
                isDirectory: true
            )
    }

    func quarantine() throws -> URL? {
        try requireSafeDatabaseDirectory()
        guard try pendingTransactionDirectories().isEmpty else {
            throw SubstrateCacheRecoveryTransactionError
                .multiplePendingTransactions
        }
        try maintainCompletedArchives()

        let sourceFamily = try manifest(
            for: storeURL,
            requiringMainStore: false
        )
        guard !sourceFamily.isEmpty else {
            return nil
        }
        guard sourceFamily.first?.suffix.isEmpty == true else {
            throw SubstrateCacheRecoveryTransactionError.sourceStoreMissing
        }

        try createRecoveryRootIfNeeded()

        let transactionDirectoryURL = recoveryRootURL
            .appendingPathComponent(
                UUID().uuidString,
                isDirectory: true
            )
        var markerBecameDurable = false

        do {
            try fileManager.createDirectory(
                at: transactionDirectoryURL,
                withIntermediateDirectories: false
            )
            try synchronizeDirectory(recoveryRootURL)
            try excludeFromBackup(transactionDirectoryURL)

            let marker = Marker(
                operation: .quarantine,
                storePathSHA256: storePathSHA256,
                family: sourceFamily,
                restoreSuffixes: []
            )
            try persist(
                marker,
                in: transactionDirectoryURL
            )
            markerBecameDurable = true
            try boundaryHook(.markerPersisted)

            try completeTransaction(
                at: transactionDirectoryURL,
                marker: marker
            )
            try maintainCompletedArchives()
            return pathKind(at: transactionDirectoryURL) == .directory
                ? transactionDirectoryURL
                : nil
        } catch is SubstrateCacheRecoveryInterruption {
            throw SubstrateCacheRecoveryInterruption
                .simulatedProcessDeath
        } catch {
            if !markerBecameDurable {
                try? removeUncommittedPreparation(
                    at: transactionDirectoryURL
                )
            }
            throw error
        }
    }

    @discardableResult
    // Branches mirror durable recovery states.
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func reconcile() throws -> URL? {
        try requireSafeDatabaseDirectory()

        switch pathKind(at: recoveryRootURL) {
        case .missing:
            return nil
        case .directory:
            break
        case .regularFile, .symbolicLink, .other:
            throw SubstrateCacheRecoveryTransactionError
                .unsafeDirectory(recoveryRootURL)
        }
        try excludeFromBackup(recoveryRootURL)

        let directoryNames = try boundedRecoveryDirectoryURLs()
            .map(\.lastPathComponent)
        var pendingTransactions: [(URL, Marker)] = []
        var markerlessArchiveURLs: [URL] = []

        for directoryName in directoryNames {
            guard UUID(uuidString: directoryName) != nil else {
                throw SubstrateCacheRecoveryTransactionError
                    .unsafeDirectory(
                        recoveryRootURL.appendingPathComponent(
                            directoryName
                        )
                    )
            }

            let transactionDirectoryURL = recoveryRootURL
                .appendingPathComponent(
                    directoryName,
                    isDirectory: true
                )
            guard pathKind(at: transactionDirectoryURL) == .directory else {
                throw SubstrateCacheRecoveryTransactionError
                    .unsafeDirectory(transactionDirectoryURL)
            }

            let markerURL = markerURL(
                in: transactionDirectoryURL
            )
            let temporaryMarkerURL = markerTemporaryURL(
                in: transactionDirectoryURL
            )

            switch pathKind(at: markerURL) {
            case .regularFile:
                guard pathKind(at: temporaryMarkerURL) == .missing else {
                    throw SubstrateCacheRecoveryTransactionError
                        .unsafeFile(temporaryMarkerURL)
                }
                pendingTransactions.append(
                    (
                        transactionDirectoryURL,
                        try readMarker(at: markerURL)
                    )
                )
            case .missing:
                switch pathKind(at: temporaryMarkerURL) {
                case .missing:
                    let contents = try boundedImmediateChildURLs(
                        at: transactionDirectoryURL,
                        maximumCount: Self.storeFamilySuffixes.count,
                        overflowError:
                        SubstrateCacheRecoveryTransactionError
                            .unsafeDirectory(
                                transactionDirectoryURL
                            )
                    ).map(\.lastPathComponent)
                    if contents.isEmpty {
                        try fileManager.removeItem(
                            at: transactionDirectoryURL
                        )
                        try synchronizeDirectory(recoveryRootURL)
                    } else {
                        markerlessArchiveURLs.append(
                            transactionDirectoryURL
                        )
                    }
                case .regularFile:
                    let contents = Set(
                        try boundedImmediateChildURLs(
                            at: transactionDirectoryURL,
                            maximumCount:
                            Self.storeFamilySuffixes.count + 1,
                            overflowError:
                            SubstrateCacheRecoveryTransactionError
                                .unsafeDirectory(
                                    transactionDirectoryURL
                                )
                        ).map(\.lastPathComponent)
                    )
                    if contents == [Self.markerTemporaryFileName] {
                        try removeUncommittedPreparation(
                            at: transactionDirectoryURL
                        )
                    } else {
                        let allowedLegacyNames = Set(
                            Self.storeFamilySuffixes.map {
                                self.storeURL.lastPathComponent + $0
                            } + [Self.markerTemporaryFileName]
                        )
                        try requireExactTree(
                            at: transactionDirectoryURL,
                            allowedFileNames: allowedLegacyNames
                        )
                        guard contents.contains(
                            storeURL.lastPathComponent
                        ) else {
                            throw SubstrateCacheRecoveryTransactionError
                                .familyMismatch
                        }

                        try fileManager.removeItem(
                            at: temporaryMarkerURL
                        )
                        try synchronizeDirectory(
                            transactionDirectoryURL
                        )
                        markerlessArchiveURLs.append(
                            transactionDirectoryURL
                        )
                    }
                case .directory, .symbolicLink, .other:
                    throw SubstrateCacheRecoveryTransactionError
                        .unsafeFile(temporaryMarkerURL)
                }
            case .directory, .symbolicLink, .other:
                throw SubstrateCacheRecoveryTransactionError
                    .unsafeFile(markerURL)
            }
        }

        guard pendingTransactions.count <= 1 else {
            throw SubstrateCacheRecoveryTransactionError
                .multiplePendingTransactions
        }

        guard let pendingTransaction = pendingTransactions.first else {
            let recoveredLegacyURL =
                try reconcileLegacyInterruptedTransaction(
                    archiveURLs: markerlessArchiveURLs
                )

            try maintainCompletedArchives()
            return recoveredLegacyURL.flatMap {
                pathKind(at: $0) == .directory ? $0 : nil
            }
        }

        try excludeFromBackup(pendingTransaction.0)
        let reconciledArchiveURL: URL?
        switch pendingTransaction.1.operation {
        case .quarantine:
            try completeTransaction(
                at: pendingTransaction.0,
                marker: pendingTransaction.1
            )
            reconciledArchiveURL = pendingTransaction.0
        case .restoreLegacy:
            try restoreLegacyTransaction(
                at: pendingTransaction.0,
                marker: pendingTransaction.1
            )
            reconciledArchiveURL = pendingTransaction.0
        case .deleteArchive:
            try completeArchiveDeletion(
                at: pendingTransaction.0,
                marker: pendingTransaction.1
            )
            reconciledArchiveURL = nil
        }

        try maintainCompletedArchives()
        return reconciledArchiveURL.flatMap {
            pathKind(at: $0) == .directory ? $0 : nil
        }
    }

    private func reconcileLegacyInterruptedTransaction(
        archiveURLs: [URL]
    ) throws -> URL? {
        // A live main store means the app either still has its original
        // family or already rebuilt the cache. Avoid hashing a potentially
        // large healthy cache merely because historical archives remain.
        switch pathKind(at: storeURL) {
        case .regularFile:
            return nil
        case .missing:
            break
        case .directory, .symbolicLink, .other:
            throw SubstrateCacheRecoveryTransactionError
                .unsafeFile(storeURL)
        }

        let liveFamily = try manifest(
            for: storeURL,
            requiringMainStore: false
        )

        // No live family is the fully completed legacy outcome.
        guard !liveFamily.isEmpty else {
            return nil
        }

        var candidates: [(URL, Marker)] = []
        for archiveURL in archiveURLs {
            if let marker = try legacyMarker(
                archiveURL: archiveURL,
                liveFamily: liveFamily
            ) {
                candidates.append((archiveURL, marker))
            }
        }

        guard candidates.count <= 1 else {
            throw SubstrateCacheRecoveryTransactionError
                .multiplePendingTransactions
        }
        guard let candidate = candidates.first else {
            throw SubstrateCacheRecoveryTransactionError.familyMismatch
        }

        try persist(candidate.1, in: candidate.0)
        try boundaryHook(.markerPersisted)
        try restoreLegacyTransaction(
            at: candidate.0,
            marker: candidate.1
        )
        return candidate.0
    }

    private func legacyMarker(
        archiveURL: URL,
        liveFamily: [FamilyMember]
    ) throws -> Marker? {
        let archiveStoreURL = quarantineStoreURL(in: archiveURL)
        let allowedNames = Set(
            Self.storeFamilySuffixes.map {
                storeURL.lastPathComponent + $0
            }
        )
        let archiveNames = Set(
            try boundedImmediateChildURLs(
                at: archiveURL,
                maximumCount: allowedNames.count,
                overflowError:
                SubstrateCacheRecoveryTransactionError
                    .unsafeDirectory(archiveURL)
            ).map(\.lastPathComponent)
        )
        guard archiveNames.isSubset(of: allowedNames) else {
            return nil
        }

        let archivedFamily = try manifest(
            for: archiveStoreURL,
            requiringMainStore: false
        )
        guard archivedFamily.first?.suffix.isEmpty == true else {
            return nil
        }

        let archivedSuffixes = Set(archivedFamily.map(\.suffix))
        let liveSuffixes = Set(liveFamily.map(\.suffix))
        guard archivedSuffixes.isDisjoint(with: liveSuffixes) else {
            return nil
        }

        let unionFamily = Self.storeFamilySuffixes.compactMap {
            suffix in
            archivedFamily.first { $0.suffix == suffix } ??
                liveFamily.first { $0.suffix == suffix }
        }
        guard
            Array(unionFamily.prefix(archivedFamily.count)) ==
            archivedFamily,
            Array(unionFamily.dropFirst(archivedFamily.count)) ==
            liveFamily
        else {
            return nil
        }

        var identities = Set<FileIdentity>()
        for member in archivedFamily {
            let values = try lstatValues(
                at: familyURL(
                    storeURL: archiveStoreURL,
                    suffix: member.suffix
                )
            )
            guard identities.insert(
                FileIdentity(
                    deviceID: values.deviceID,
                    inode: values.inode
                )
            ).inserted else {
                throw SubstrateCacheRecoveryTransactionError
                    .unsafeFile(archiveStoreURL)
            }
        }
        for member in liveFamily {
            let liveURL = familyURL(
                storeURL: storeURL,
                suffix: member.suffix
            )
            let values = try lstatValues(at: liveURL)
            guard identities.insert(
                FileIdentity(
                    deviceID: values.deviceID,
                    inode: values.inode
                )
            ).inserted else {
                throw SubstrateCacheRecoveryTransactionError
                    .unsafeFile(liveURL)
            }
        }

        return Marker(
            operation: .restoreLegacy,
            storePathSHA256: storePathSHA256,
            family: unionFamily,
            restoreSuffixes: archivedFamily.map(\.suffix)
        )
    }

    // Ordered recovery validation remains explicit.
    // swiftlint:disable:next function_body_length
    private func restoreLegacyTransaction(
        at transactionDirectoryURL: URL,
        marker: Marker
    ) throws {
        guard
            marker.operation == .restoreLegacy,
            marker.storePathSHA256 == storePathSHA256,
            !marker.restoreSuffixes.isEmpty,
            marker.restoreSuffixes ==
            Array(
                marker.family
                    .prefix(marker.restoreSuffixes.count)
                    .map(\.suffix)
            )
        else {
            throw SubstrateCacheRecoveryTransactionError.invalidMarker
        }

        try requireExactLegacyRestoreTree(
            at: transactionDirectoryURL,
            marker: marker
        )
        let restoreSuffixes = Set(marker.restoreSuffixes)
        let archivedStoreURL = quarantineStoreURL(
            in: transactionDirectoryURL
        )
        let expectedArchivedFamily = marker.family.filter {
            restoreSuffixes.contains($0.suffix)
        }
        guard
            try manifest(
                for: archivedStoreURL,
                requiringMainStore: true
            ) == expectedArchivedFamily
        else {
            throw SubstrateCacheRecoveryTransactionError.familyMismatch
        }

        for member in marker.family {
            let liveURL = familyURL(
                storeURL: storeURL,
                suffix: member.suffix
            )

            if restoreSuffixes.contains(member.suffix) {
                let archivedURL = familyURL(
                    storeURL: archivedStoreURL,
                    suffix: member.suffix
                )
                guard
                    try familyMember(
                        at: archivedURL,
                        suffix: member.suffix
                    ) == member
                else {
                    throw SubstrateCacheRecoveryTransactionError
                        .familyMismatch
                }

                switch pathKind(at: liveURL) {
                case .missing:
                    try installRestoredMember(
                        member,
                        from: archivedURL,
                        to: liveURL,
                        transactionDirectoryURL:
                        transactionDirectoryURL
                    )
                    try boundaryHook(
                        .legacyFamilyMemberRestored(member.suffix)
                    )
                case .regularFile:
                    guard
                        try familyMember(
                            at: liveURL,
                            suffix: member.suffix
                        ) == member
                    else {
                        throw SubstrateCacheRecoveryTransactionError
                            .familyMismatch
                    }
                case .directory, .symbolicLink, .other:
                    throw SubstrateCacheRecoveryTransactionError
                        .unsafeFile(liveURL)
                }
            } else {
                switch pathKind(at: liveURL) {
                case .regularFile:
                    guard
                        try familyMember(
                            at: liveURL,
                            suffix: member.suffix
                        ) == member
                    else {
                        throw SubstrateCacheRecoveryTransactionError
                            .familyMismatch
                    }
                case .missing:
                    throw SubstrateCacheRecoveryTransactionError
                        .familyMismatch
                case .directory, .symbolicLink, .other:
                    throw SubstrateCacheRecoveryTransactionError
                        .unsafeFile(liveURL)
                }
            }
        }

        guard
            try manifest(
                for: storeURL,
                requiringMainStore: true
            ) == marker.family
        else {
            throw SubstrateCacheRecoveryTransactionError.familyMismatch
        }

        // A previous attempt may have completed its final rename and then
        // failed while syncing either directory. Re-establish both directory
        // durability obligations even when this retry had no rename to do.
        try synchronizeDirectory(databaseDirectoryURL)
        try synchronizeDirectory(transactionDirectoryURL)

        let markerURL = markerURL(in: transactionDirectoryURL)
        guard pathKind(at: markerURL) == .regularFile else {
            throw SubstrateCacheRecoveryTransactionError
                .unsafeFile(markerURL)
        }
        try fileManager.removeItem(at: markerURL)
        try synchronizeDirectory(transactionDirectoryURL)
        try boundaryHook(.markerRemoved)
    }

    private func installRestoredMember(
        _ member: FamilyMember,
        from archivedURL: URL,
        to liveURL: URL,
        transactionDirectoryURL: URL
    ) throws {
        let temporaryURL = try restorationTemporaryURL(
            for: member.suffix,
            in: transactionDirectoryURL
        )

        switch pathKind(at: temporaryURL) {
        case .missing:
            try fileManager.copyItem(
                at: archivedURL,
                to: temporaryURL
            )
            guard
                try familyMember(
                    at: temporaryURL,
                    suffix: member.suffix
                ) == member
            else {
                throw SubstrateCacheRecoveryTransactionError
                    .familyMismatch
            }
        case .regularFile:
            if try familyMember(
                at: temporaryURL,
                suffix: member.suffix
            ) != member {
                // The durable archive remains authoritative. A regular
                // partial copy can be discarded and recreated after power
                // loss; unsafe path types are never removed.
                try fileManager.removeItem(at: temporaryURL)
                try synchronizeDirectory(transactionDirectoryURL)
                try fileManager.copyItem(
                    at: archivedURL,
                    to: temporaryURL
                )
                guard
                    try familyMember(
                        at: temporaryURL,
                        suffix: member.suffix
                    ) == member
                else {
                    throw SubstrateCacheRecoveryTransactionError
                        .familyMismatch
                }
            }
        case .directory, .symbolicLink, .other:
            throw SubstrateCacheRecoveryTransactionError
                .unsafeFile(temporaryURL)
        }

        try restorationTemporaryFileSynchronizationHook(
            temporaryURL
        )
        try synchronizeFile(temporaryURL)
        try synchronizeDirectory(transactionDirectoryURL)

        guard pathKind(at: liveURL) == .missing else {
            throw SubstrateCacheRecoveryTransactionError
                .familyMismatch
        }
        try fileManager.moveItem(at: temporaryURL, to: liveURL)
        guard
            pathKind(at: temporaryURL) == .missing,
            try familyMember(
                at: liveURL,
                suffix: member.suffix
            ) == member
        else {
            throw SubstrateCacheRecoveryTransactionError.familyMismatch
        }
        try synchronizeDirectory(databaseDirectoryURL)
        try synchronizeDirectory(transactionDirectoryURL)
    }

    private func completeTransaction(
        at transactionDirectoryURL: URL,
        marker: Marker
    ) throws {
        guard
            marker.operation == .quarantine,
            marker.restoreSuffixes.isEmpty,
            marker.storePathSHA256 == storePathSHA256
        else {
            throw SubstrateCacheRecoveryTransactionError.invalidMarker
        }

        try requireExactActiveTree(
            at: transactionDirectoryURL,
            marker: marker
        )

        for member in marker.family {
            let sourceURL = familyURL(
                storeURL: storeURL,
                suffix: member.suffix
            )
            let destinationURL = transactionDirectoryURL
                .appendingPathComponent(
                    sourceURL.lastPathComponent
                )

            let sourceKind = pathKind(at: sourceURL)
            let destinationKind = pathKind(at: destinationURL)

            switch (sourceKind, destinationKind) {
            case (.regularFile, .missing):
                guard try familyMember(
                    at: sourceURL,
                    suffix: member.suffix
                ) == member else {
                    throw SubstrateCacheRecoveryTransactionError
                        .familyMismatch
                }

                try fileManager.moveItem(
                    at: sourceURL,
                    to: destinationURL
                )
                guard
                    pathKind(at: sourceURL) == .missing,
                    try familyMember(
                        at: destinationURL,
                        suffix: member.suffix
                    ) == member
                else {
                    throw SubstrateCacheRecoveryTransactionError
                        .familyMismatch
                }

                try synchronizeDirectory(transactionDirectoryURL)
                try synchronizeDirectory(databaseDirectoryURL)
                try boundaryHook(
                    .familyMemberMoved(member.suffix)
                )
            case (.missing, .regularFile):
                guard try familyMember(
                    at: destinationURL,
                    suffix: member.suffix
                ) == member else {
                    throw SubstrateCacheRecoveryTransactionError
                        .familyMismatch
                }
            case (.missing, .missing), (.regularFile, .regularFile):
                throw SubstrateCacheRecoveryTransactionError
                    .familyMismatch
            case (.directory, _), (.symbolicLink, _), (.other, _):
                throw SubstrateCacheRecoveryTransactionError
                    .unsafeFile(sourceURL)
            case (_, .directory), (_, .symbolicLink), (_, .other):
                throw SubstrateCacheRecoveryTransactionError
                    .unsafeFile(destinationURL)
            }
        }

        guard
            try manifest(
                for: quarantineStoreURL(
                    in: transactionDirectoryURL
                ),
                requiringMainStore: true
            ) == marker.family
        else {
            throw SubstrateCacheRecoveryTransactionError.familyMismatch
        }

        for suffix in Self.storeFamilySuffixes {
            let sourceURL = familyURL(
                storeURL: storeURL,
                suffix: suffix
            )
            guard pathKind(at: sourceURL) == .missing else {
                throw SubstrateCacheRecoveryTransactionError
                    .familyMismatch
            }
        }

        // A previous attempt may have completed its final rename and then
        // failed while syncing either directory. Re-establish both directory
        // durability obligations even when this retry had no rename to do.
        try synchronizeDirectory(transactionDirectoryURL)
        try synchronizeDirectory(databaseDirectoryURL)

        let markerURL = markerURL(in: transactionDirectoryURL)
        guard pathKind(at: markerURL) == .regularFile else {
            throw SubstrateCacheRecoveryTransactionError
                .unsafeFile(markerURL)
        }
        try fileManager.removeItem(at: markerURL)
        try synchronizeDirectory(transactionDirectoryURL)
        try boundaryHook(.markerRemoved)
    }

    private func completeArchiveDeletion(
        at transactionDirectoryURL: URL,
        marker: Marker
    ) throws {
        guard
            marker.operation == .deleteArchive,
            marker.restoreSuffixes.isEmpty,
            marker.storePathSHA256 == storePathSHA256
        else {
            throw SubstrateCacheRecoveryTransactionError.invalidMarker
        }

        try requireExactActiveTree(
            at: transactionDirectoryURL,
            marker: marker
        )

        let archiveName = transactionDirectoryURL.lastPathComponent
        let archivedStoreURL = quarantineStoreURL(
            in: transactionDirectoryURL
        )

        for member in marker.family {
            let archivedURL = familyURL(
                storeURL: archivedStoreURL,
                suffix: member.suffix
            )

            switch pathKind(at: archivedURL) {
            case .missing:
                continue
            case .regularFile:
                guard
                    try familyMember(
                        at: archivedURL,
                        suffix: member.suffix
                    ) == member,
                    try lstatValues(at: archivedURL).linkCount == 1
                else {
                    throw SubstrateCacheRecoveryTransactionError
                        .familyMismatch
                }

                try fileManager.removeItem(at: archivedURL)
                try synchronizeDirectory(transactionDirectoryURL)
                try boundaryHook(
                    .retentionFamilyMemberRemoved(
                        archiveName,
                        member.suffix
                    )
                )
            case .directory, .symbolicLink, .other:
                throw SubstrateCacheRecoveryTransactionError
                    .unsafeFile(archivedURL)
            }
        }

        let markerURL = markerURL(in: transactionDirectoryURL)
        guard
            pathKind(at: markerURL) == .regularFile,
            try fileManager.contentsOfDirectory(
                atPath: transactionDirectoryURL.path
            ) == [Self.markerFileName]
        else {
            throw SubstrateCacheRecoveryTransactionError
                .familyMismatch
        }

        try fileManager.removeItem(at: markerURL)
        try synchronizeDirectory(transactionDirectoryURL)
        try boundaryHook(.retentionMarkerRemoved(archiveName))

        guard try fileManager.contentsOfDirectory(
            atPath: transactionDirectoryURL.path
        ).isEmpty else {
            throw SubstrateCacheRecoveryTransactionError
                .unsafeDirectory(transactionDirectoryURL)
        }
        try fileManager.removeItem(at: transactionDirectoryURL)
        try synchronizeDirectory(recoveryRootURL)
        try boundaryHook(.retentionArchiveRemoved(archiveName))
    }

    // Retention checks remain one ordered transaction.
    // swiftlint:disable:next function_body_length
    private func maintainCompletedArchives() throws {
        switch pathKind(at: recoveryRootURL) {
        case .missing:
            return
        case .directory:
            break
        case .regularFile, .symbolicLink, .other:
            throw SubstrateCacheRecoveryTransactionError
                .unsafeDirectory(recoveryRootURL)
        }

        guard try pendingTransactionDirectories().isEmpty else {
            throw SubstrateCacheRecoveryTransactionError
                .multiplePendingTransactions
        }

        let directoryNames = try boundedRecoveryDirectoryURLs()
            .map(\.lastPathComponent)
        var preflights: [CompletedArchivePreflight] = []
        var preflightByteCount: UInt64 = 0

        for directoryName in directoryNames {
            guard UUID(uuidString: directoryName) != nil else {
                throw SubstrateCacheRecoveryTransactionError
                    .unsafeDirectory(
                        recoveryRootURL.appendingPathComponent(
                            directoryName
                        )
                    )
            }

            let archiveURL = recoveryRootURL.appendingPathComponent(
                directoryName,
                isDirectory: true
            )
            guard pathKind(at: archiveURL) == .directory else {
                throw SubstrateCacheRecoveryTransactionError
                    .unsafeDirectory(archiveURL)
            }

            let children = try boundedImmediateChildURLs(
                at: archiveURL,
                maximumCount: Self.storeFamilySuffixes.count,
                overflowError:
                SubstrateCacheRecoveryTransactionError
                    .unsafeDirectory(archiveURL)
            )
            if children.isEmpty {
                try fileManager.removeItem(at: archiveURL)
                try synchronizeDirectory(recoveryRootURL)
                continue
            }

            let preflight = try completedArchivePreflight(
                at: archiveURL
            )
            let addition = preflightByteCount
                .addingReportingOverflow(preflight.byteCount)
            guard
                !addition.overflow,
                addition.partialValue <=
                Self.maximumArchiveByteScanCount
            else {
                throw SubstrateCacheRecoveryTransactionError
                    .archiveByteScanLimitExceeded(
                        Self.maximumArchiveByteScanCount
                    )
            }
            preflightByteCount = addition.partialValue
            preflights.append(preflight)
        }

        try excludeFromBackup(recoveryRootURL)
        for preflight in preflights {
            try excludeFromBackup(preflight.url)
        }

        // Every candidate tree and its aggregate byte footprint is bounded
        // before the first SHA-256 read or deletion authorization is written.
        let archives = try preflights.map {
            try completedArchive(after: $0)
        }

        var retainedArchives = archives.sorted {
            if $0.completionTime.seconds !=
                $1.completionTime.seconds {
                return $0.completionTime.seconds <
                    $1.completionTime.seconds
            }
            if $0.completionTime.nanoseconds !=
                $1.completionTime.nanoseconds {
                return $0.completionTime.nanoseconds <
                    $1.completionTime.nanoseconds
            }
            return $0.url.lastPathComponent <
                $1.url.lastPathComponent
        }

        var retainedByteCount: UInt64 = 0
        for archive in retainedArchives {
            let addition = retainedByteCount.addingReportingOverflow(
                archive.byteCount
            )
            guard !addition.overflow else {
                throw SubstrateCacheRecoveryTransactionError.familyMismatch
            }
            retainedByteCount = addition.partialValue
        }

        while
            retainedArchives.count > retainedArchiveCount ||
            retainedByteCount > retainedArchiveByteCount
        {
            let archive = retainedArchives.removeFirst()
            retainedByteCount -= archive.byteCount
            try deleteCompletedArchive(archive)
        }

        try removeRecoveryRootIfEmpty()
    }

    private func completedArchivePreflight(
        at archiveURL: URL
    ) throws -> CompletedArchivePreflight {
        let allowedNames = Set(
            Self.storeFamilySuffixes.map {
                storeURL.lastPathComponent + $0
            }
        )
        try requireExactTree(
            at: archiveURL,
            allowedFileNames: allowedNames
        )

        let childURLs = try boundedImmediateChildURLs(
            at: archiveURL,
            maximumCount: allowedNames.count,
            overflowError: SubstrateCacheRecoveryTransactionError
                .unsafeDirectory(archiveURL)
        )
        let names = Set(childURLs.map(\.lastPathComponent))
        guard names.contains(storeURL.lastPathComponent) else {
            throw SubstrateCacheRecoveryTransactionError
                .sourceStoreMissing
        }

        var identities = Set<FileIdentity>()
        var byteCount: UInt64 = 0
        for childURL in childURLs {
            let values = try lstatValues(at: childURL)
            guard
                values.linkCount == 1,
                identities.insert(
                    FileIdentity(
                        deviceID: values.deviceID,
                        inode: values.inode
                    )
                ).inserted
            else {
                throw SubstrateCacheRecoveryTransactionError
                    .unsafeFile(childURL)
            }
            let addition = byteCount.addingReportingOverflow(
                values.byteCount
            )
            guard
                !addition.overflow,
                addition.partialValue <=
                Self.maximumArchiveByteScanCount
            else {
                throw SubstrateCacheRecoveryTransactionError
                    .archiveByteScanLimitExceeded(
                        Self.maximumArchiveByteScanCount
                    )
            }
            byteCount = addition.partialValue
        }

        return CompletedArchivePreflight(
            url: archiveURL,
            byteCount: byteCount,
            completionTime: try directoryCompletionTime(
                at: archiveURL
            )
        )
    }

    private func completedArchive(
        after preflight: CompletedArchivePreflight
    ) throws -> CompletedArchive {
        let archiveURL = preflight.url
        let family = try manifest(
            for: quarantineStoreURL(in: archiveURL),
            requiringMainStore: true
        )
        let expectedNames = Set(
            family.map {
                storeURL.lastPathComponent + $0.suffix
            }
        )
        guard
            Set(
                try boundedImmediateChildURLs(
                    at: archiveURL,
                    maximumCount: Self.storeFamilySuffixes.count,
                    overflowError:
                    SubstrateCacheRecoveryTransactionError
                        .unsafeDirectory(archiveURL)
                ).map(\.lastPathComponent)
            ) == expectedNames
        else {
            throw SubstrateCacheRecoveryTransactionError.familyMismatch
        }

        var byteCount: UInt64 = 0
        for member in family {
            let memberURL = familyURL(
                storeURL: quarantineStoreURL(in: archiveURL),
                suffix: member.suffix
            )
            guard try lstatValues(at: memberURL).linkCount == 1 else {
                throw SubstrateCacheRecoveryTransactionError
                    .unsafeFile(memberURL)
            }
            let addition = byteCount.addingReportingOverflow(
                member.byteCount
            )
            guard !addition.overflow else {
                throw SubstrateCacheRecoveryTransactionError.familyMismatch
            }
            byteCount = addition.partialValue
        }
        guard byteCount == preflight.byteCount else {
            throw SubstrateCacheRecoveryTransactionError.familyMismatch
        }

        return CompletedArchive(
            url: archiveURL,
            family: family,
            byteCount: byteCount,
            completionTime: preflight.completionTime
        )
    }

    private func deleteCompletedArchive(
        _ archive: CompletedArchive
    ) throws {
        let marker = Marker(
            operation: .deleteArchive,
            storePathSHA256: storePathSHA256,
            family: archive.family,
            restoreSuffixes: []
        )
        try persist(marker, in: archive.url)
        try boundaryHook(
            .retentionMarkerPersisted(
                archive.url.lastPathComponent
            )
        )
        try completeArchiveDeletion(
            at: archive.url,
            marker: marker
        )
    }

    private func persist(
        _ marker: Marker,
        in transactionDirectoryURL: URL
    ) throws {
        let markerURL = markerURL(in: transactionDirectoryURL)
        let temporaryMarkerURL = markerTemporaryURL(
            in: transactionDirectoryURL
        )
        guard
            pathKind(at: markerURL) == .missing,
            pathKind(at: temporaryMarkerURL) == .missing
        else {
            throw SubstrateCacheRecoveryTransactionError
                .unsafeFile(markerURL)
        }

        let data = try encode(marker)
        guard data.count <= Self.maximumMarkerByteCount else {
            throw SubstrateCacheRecoveryTransactionError.markerTooLarge
        }

        try data.write(
            to: temporaryMarkerURL,
            options: .withoutOverwriting
        )
        try synchronizeFile(temporaryMarkerURL)
        try fileManager.moveItem(
            at: temporaryMarkerURL,
            to: markerURL
        )
        try synchronizeDirectory(transactionDirectoryURL)
    }

    private func readMarker(at markerURL: URL) throws -> Marker {
        let values = try lstatValues(at: markerURL)
        guard values.byteCount <= Self.maximumMarkerByteCount else {
            throw SubstrateCacheRecoveryTransactionError.markerTooLarge
        }

        let data = try Data(contentsOf: markerURL)
        guard UInt64(data.count) == values.byteCount else {
            throw SubstrateCacheRecoveryTransactionError.invalidMarker
        }

        return try decodeMarker(data)
    }

    private func encode(_ marker: Marker) throws -> Data {
        let restoreSuffixes = marker.restoreSuffixes.isEmpty
            ? "-"
            : try marker.restoreSuffixes.map {
                try token(for: $0)
            }.joined(
                separator: ","
            )
        var lines = [
            Self.markerHeader,
            "operation\t\(marker.operation.rawValue)",
            "store-path-sha256\t\(marker.storePathSHA256)",
            "restore-suffixes\t\(restoreSuffixes)"
        ]

        for member in marker.family {
            lines.append(
                [
                    try token(for: member.suffix),
                    String(member.byteCount),
                    member.sha256
                ].joined(separator: "\t")
            )
        }

        return Data((lines.joined(separator: "\n") + "\n").utf8)
    }

    // Marker validation remains fail-closed and linear.
    // swiftlint:disable:next function_body_length
    private func decodeMarker(_ data: Data) throws -> Marker {
        guard
            let text = String(data: data, encoding: .utf8),
            Data(text.utf8) == data
        else {
            throw SubstrateCacheRecoveryTransactionError.invalidMarker
        }

        let lines = text.split(
            separator: "\n",
            omittingEmptySubsequences: false
        )
        guard
            lines.count >= 6,
            lines.count <= 9,
            lines.last?.isEmpty == true,
            lines[0] == Self.markerHeader
        else {
            throw SubstrateCacheRecoveryTransactionError.invalidMarker
        }

        let operationFields = lines[1].split(
            separator: "\t",
            omittingEmptySubsequences: false
        )
        guard
            operationFields.count == 2,
            operationFields[0] == "operation",
            let operation = Operation(
                rawValue: String(operationFields[1])
            )
        else {
            throw SubstrateCacheRecoveryTransactionError.invalidMarker
        }

        let pathFields = lines[2].split(
            separator: "\t",
            omittingEmptySubsequences: false
        )
        guard
            pathFields.count == 2,
            pathFields[0] == "store-path-sha256",
            isLowercaseSHA256(String(pathFields[1]))
        else {
            throw SubstrateCacheRecoveryTransactionError.invalidMarker
        }

        let restoreFields = lines[3].split(
            separator: "\t",
            omittingEmptySubsequences: false
        )
        guard
            restoreFields.count == 2,
            restoreFields[0] == "restore-suffixes"
        else {
            throw SubstrateCacheRecoveryTransactionError.invalidMarker
        }
        let restoreSuffixes: [String]
        if restoreFields[1] == "-" {
            restoreSuffixes = []
        } else {
            restoreSuffixes = try restoreFields[1]
                .split(
                    separator: ",",
                    omittingEmptySubsequences: false
                ).map {
                    guard let suffix = suffix(for: String($0)) else {
                        throw SubstrateCacheRecoveryTransactionError
                            .invalidMarker
                    }
                    return suffix
                }
        }

        var family: [FamilyMember] = []
        for line in lines.dropFirst(4).dropLast() {
            let fields = line.split(
                separator: "\t",
                omittingEmptySubsequences: false
            )
            guard
                fields.count == 3,
                let suffix = suffix(for: String(fields[0])),
                let byteCount = UInt64(fields[1]),
                String(byteCount) == fields[1],
                isLowercaseSHA256(String(fields[2]))
            else {
                throw SubstrateCacheRecoveryTransactionError
                    .invalidMarker
            }

            family.append(
                FamilyMember(
                    suffix: suffix,
                    byteCount: byteCount,
                    sha256: String(fields[2])
                )
            )
        }

        let canonicalSuffixes = Self.storeFamilySuffixes.filter {
            suffix in
            family.contains { $0.suffix == suffix }
        }
        guard
            !family.isEmpty,
            family.first?.suffix.isEmpty == true,
            family.map(\.suffix) == canonicalSuffixes,
            Set(family.map(\.suffix)).count == family.count,
            (
                operation == .quarantine &&
                    restoreSuffixes.isEmpty
            ) || (
                operation == .deleteArchive &&
                    restoreSuffixes.isEmpty
            ) || (
                operation == .restoreLegacy &&
                    !restoreSuffixes.isEmpty &&
                    restoreSuffixes ==
                    Array(
                        family
                            .prefix(restoreSuffixes.count)
                            .map(\.suffix)
                    )
            )
        else {
            throw SubstrateCacheRecoveryTransactionError.invalidMarker
        }

        let marker = Marker(
            operation: operation,
            storePathSHA256: String(pathFields[1]),
            family: family,
            restoreSuffixes: restoreSuffixes
        )
        guard try encode(marker) == data else {
            throw SubstrateCacheRecoveryTransactionError.invalidMarker
        }

        return marker
    }

    private func requireExactActiveTree(
        at transactionDirectoryURL: URL,
        marker: Marker
    ) throws {
        let allowedNames = Set(
            marker.family.map {
                storeURL.lastPathComponent + $0.suffix
            } + [Self.markerFileName]
        )
        try requireExactTree(
            at: transactionDirectoryURL,
            allowedFileNames: allowedNames
        )
    }

    private func requireExactLegacyRestoreTree(
        at transactionDirectoryURL: URL,
        marker: Marker
    ) throws {
        let archivedNames = marker.restoreSuffixes.map {
            storeURL.lastPathComponent + $0
        }
        let temporaryNames = try marker.restoreSuffixes.map {
            try restorationTemporaryURL(
                for: $0,
                in: transactionDirectoryURL
            ).lastPathComponent
        }
        let allowedNames = Set(
            archivedNames +
                temporaryNames +
                [Self.markerFileName]
        )
        try requireExactTree(
            at: transactionDirectoryURL,
            allowedFileNames: allowedNames
        )
    }

    private func requireExactTree(
        at directoryURL: URL,
        allowedFileNames: Set<String>
    ) throws {
        guard pathKind(at: directoryURL) == .directory else {
            throw SubstrateCacheRecoveryTransactionError
                .unsafeDirectory(directoryURL)
        }

        let childURLs = try boundedImmediateChildURLs(
            at: directoryURL,
            maximumCount: allowedFileNames.count,
            overflowError: SubstrateCacheRecoveryTransactionError
                .unsafeDirectory(directoryURL)
        )
        let names = Set(childURLs.map(\.lastPathComponent))
        guard names.isSubset(of: allowedFileNames) else {
            throw SubstrateCacheRecoveryTransactionError
                .unsafeDirectory(directoryURL)
        }

        for url in childURLs {
            guard pathKind(at: url) == .regularFile else {
                throw SubstrateCacheRecoveryTransactionError
                    .unsafeFile(url)
            }
        }
    }

    private func manifest(
        for familyStoreURL: URL,
        requiringMainStore: Bool
    ) throws -> [FamilyMember] {
        var members: [FamilyMember] = []
        var identities = Set<FileIdentity>()

        for suffix in Self.storeFamilySuffixes {
            let url = familyURL(
                storeURL: familyStoreURL,
                suffix: suffix
            )

            switch pathKind(at: url) {
            case .missing:
                if suffix.isEmpty, requiringMainStore {
                    throw SubstrateCacheRecoveryTransactionError
                        .sourceStoreMissing
                }
            case .regularFile:
                let values = try lstatValues(at: url)
                guard identities.insert(
                    FileIdentity(
                        deviceID: values.deviceID,
                        inode: values.inode
                    )
                ).inserted else {
                    throw SubstrateCacheRecoveryTransactionError
                        .unsafeFile(url)
                }
                members.append(
                    try familyMember(
                        at: url,
                        suffix: suffix
                    )
                )
            case .directory, .symbolicLink, .other:
                throw SubstrateCacheRecoveryTransactionError
                    .unsafeFile(url)
            }
        }

        if requiringMainStore {
            guard members.first?.suffix.isEmpty == true else {
                throw SubstrateCacheRecoveryTransactionError
                    .sourceStoreMissing
            }
        }

        return members
    }

    private func familyMember(
        at url: URL,
        suffix: String
    ) throws -> FamilyMember {
        guard pathKind(at: url) == .regularFile else {
            throw SubstrateCacheRecoveryTransactionError.unsafeFile(url)
        }
        let valuesBefore = try lstatValues(at: url)
        let sha256 = try digest(at: url)
        let valuesAfter = try lstatValues(at: url)
        guard
            valuesBefore.byteCount == valuesAfter.byteCount,
            valuesBefore.deviceID == valuesAfter.deviceID,
            valuesBefore.inode == valuesAfter.inode
        else {
            throw SubstrateCacheRecoveryTransactionError.familyMismatch
        }

        return FamilyMember(
            suffix: suffix,
            byteCount: valuesAfter.byteCount,
            sha256: sha256
        )
    }

    private func digest(at url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer {
            try? handle.close()
        }

        var hasher = SHA256()
        while true {
            let data = try handle.read(
                upToCount: Self.digestChunkByteCount
            ) ?? Data()
            guard !data.isEmpty else {
                break
            }
            hasher.update(data: data)
        }

        return hasher.finalize().map {
            String(format: "%02x", $0)
        }.joined()
    }

    private static func digest(data: Data) -> String {
        SHA256.hash(data: data).map {
            String(format: "%02x", $0)
        }.joined()
    }

    private func token(for suffix: String) throws -> String {
        switch suffix {
        case "":
            return "main"
        case "-wal":
            return "wal"
        case "-shm":
            return "shm"
        case "-journal":
            return "journal"
        default:
            throw SubstrateCacheRecoveryTransactionError.invalidMarker
        }
    }

    private func suffix(for token: String) -> String? {
        switch token {
        case "main":
            return ""
        case "wal":
            return "-wal"
        case "shm":
            return "-shm"
        case "journal":
            return "-journal"
        default:
            return nil
        }
    }

    private func isLowercaseSHA256(_ value: String) -> Bool {
        value.count == 64 && value.utf8.allSatisfy {
            (0x30 ... 0x39).contains($0) ||
                (0x61 ... 0x66).contains($0)
        }
    }

    private func createRecoveryRootIfNeeded() throws {
        switch pathKind(at: recoveryRootURL) {
        case .missing:
            try fileManager.createDirectory(
                at: recoveryRootURL,
                withIntermediateDirectories: false
            )
            try synchronizeDirectory(databaseDirectoryURL)
        case .directory:
            break
        case .regularFile, .symbolicLink, .other:
            throw SubstrateCacheRecoveryTransactionError
                .unsafeDirectory(recoveryRootURL)
        }

        try excludeFromBackup(recoveryRootURL)
    }

    private func removeUncommittedPreparation(
        at transactionDirectoryURL: URL
    ) throws {
        guard pathKind(at: transactionDirectoryURL) == .directory else {
            throw SubstrateCacheRecoveryTransactionError
                .unsafeDirectory(transactionDirectoryURL)
        }

        let names = try fileManager.contentsOfDirectory(
            atPath: transactionDirectoryURL.path
        )
        guard Set(names).isSubset(
            of: [
                Self.markerFileName,
                Self.markerTemporaryFileName
            ]
        ) else {
            throw SubstrateCacheRecoveryTransactionError
                .unsafeDirectory(transactionDirectoryURL)
        }

        for name in names {
            let url = transactionDirectoryURL.appendingPathComponent(name)
            guard pathKind(at: url) == .regularFile else {
                throw SubstrateCacheRecoveryTransactionError
                    .unsafeFile(url)
            }
            try fileManager.removeItem(at: url)
            try synchronizeDirectory(transactionDirectoryURL)
        }

        try fileManager.removeItem(at: transactionDirectoryURL)
        try synchronizeDirectory(recoveryRootURL)
        try removeRecoveryRootIfEmpty()
    }

    private func removeRecoveryRootIfEmpty() throws {
        guard pathKind(at: recoveryRootURL) == .directory else {
            return
        }
        guard try fileManager.contentsOfDirectory(
            atPath: recoveryRootURL.path
        ).isEmpty else {
            return
        }

        try fileManager.removeItem(at: recoveryRootURL)
        try synchronizeDirectory(databaseDirectoryURL)
    }

    private func synchronizeFile(_ url: URL) throws {
        do {
            guard pathKind(at: url) == .regularFile else {
                throw SubstrateCacheRecoveryTransactionError
                    .unsafeFile(url)
            }
            let handle = try FileHandle(forUpdating: url)
            defer {
                try? handle.close()
            }
            try handle.synchronize()
        } catch {
            throw SubstrateCacheRecoveryTransactionError
                .fileSynchronizationFailed(url, error)
        }
    }

    private func synchronizeDirectory(_ url: URL) throws {
        do {
            guard pathKind(at: url) == .directory else {
                throw SubstrateCacheRecoveryTransactionError
                    .unsafeDirectory(url)
            }

            try directorySynchronizationHook(url)

            let descriptor = Darwin.open(url.path, O_RDONLY)
            guard descriptor >= 0 else {
                throw POSIXError(
                    POSIXErrorCode(rawValue: errno) ?? .EIO
                )
            }
            defer {
                _ = Darwin.close(descriptor)
            }

            guard Darwin.fsync(descriptor) == 0 else {
                throw POSIXError(
                    POSIXErrorCode(rawValue: errno) ?? .EIO
                )
            }
        } catch {
            throw SubstrateCacheRecoveryTransactionError
                .directorySynchronizationFailed(url, error)
        }
    }

    private func excludeFromBackup(_ url: URL) throws {
        do {
            guard pathKind(at: url) == .directory else {
                throw SubstrateCacheRecoveryTransactionError
                    .unsafeDirectory(url)
            }
            try backupExclusionHook(url)
        } catch let transactionError
            as SubstrateCacheRecoveryTransactionError {
            throw transactionError
        } catch {
            throw SubstrateCacheRecoveryTransactionError
                .backupExclusionFailed(url, error)
        }
    }

    private func directoryCompletionTime(
        at url: URL
    ) throws -> ArchiveCompletionTime {
        var directoryStatus = stat()
        guard
            Darwin.lstat(url.path, &directoryStatus) == 0,
            directoryStatus.st_mode & S_IFMT == S_IFDIR
        else {
            throw SubstrateCacheRecoveryTransactionError
                .unsafeDirectory(url)
        }

        return ArchiveCompletionTime(
            seconds: Int64(directoryStatus.st_mtimespec.tv_sec),
            nanoseconds: Int64(directoryStatus.st_mtimespec.tv_nsec)
        )
    }

    private func requireSafeDatabaseDirectory() throws {
        guard pathKind(at: databaseDirectoryURL) == .directory else {
            throw SubstrateCacheRecoveryTransactionError
                .unsafeDirectory(databaseDirectoryURL)
        }

        switch pathKind(at: recoveryRootURL) {
        case .missing, .directory:
            return
        case .regularFile, .symbolicLink, .other:
            throw SubstrateCacheRecoveryTransactionError
                .unsafeDirectory(recoveryRootURL)
        }
    }

    private func familyURL(
        storeURL: URL,
        suffix: String
    ) -> URL {
        URL(fileURLWithPath: storeURL.path + suffix)
    }

    private func quarantineStoreURL(
        in transactionDirectoryURL: URL
    ) -> URL {
        transactionDirectoryURL.appendingPathComponent(
            storeURL.lastPathComponent
        )
    }

    private func markerURL(
        in transactionDirectoryURL: URL
    ) -> URL {
        transactionDirectoryURL.appendingPathComponent(
            Self.markerFileName
        )
    }

    private func markerTemporaryURL(
        in transactionDirectoryURL: URL
    ) -> URL {
        transactionDirectoryURL.appendingPathComponent(
            Self.markerTemporaryFileName
        )
    }

    private func restorationTemporaryURL(
        for suffix: String,
        in transactionDirectoryURL: URL
    ) throws -> URL {
        transactionDirectoryURL.appendingPathComponent(
            "\(try token(for: suffix))\(Self.restorationTemporarySuffix)"
        )
    }

    private func boundedRecoveryDirectoryURLs() throws -> [URL] {
        try boundedImmediateChildURLs(
            at: recoveryRootURL,
            maximumCount: Self.maximumArchiveDirectoryScanCount,
            overflowError: SubstrateCacheRecoveryTransactionError
                .archiveScanLimitExceeded(
                    Self.maximumArchiveDirectoryScanCount
                )
        )
    }

    private func boundedImmediateChildURLs(
        at directoryURL: URL,
        maximumCount: Int,
        overflowError: Error
    ) throws -> [URL] {
        guard pathKind(at: directoryURL) == .directory else {
            throw SubstrateCacheRecoveryTransactionError
                .unsafeDirectory(directoryURL)
        }

        var enumerationFailed = false
        guard
            let enumerator = fileManager.enumerator(
                at: directoryURL,
                includingPropertiesForKeys: nil,
                options: [.skipsSubdirectoryDescendants],
                errorHandler: { _, _ in
                    enumerationFailed = true
                    return false
                }
            )
        else {
            throw SubstrateCacheRecoveryTransactionError
                .unsafeDirectory(directoryURL)
        }

        var childURLs: [URL] = []
        while let childURL = enumerator.nextObject() as? URL {
            childURLs.append(childURL)
            guard childURLs.count <= maximumCount else {
                throw overflowError
            }
        }
        guard !enumerationFailed else {
            throw SubstrateCacheRecoveryTransactionError
                .unsafeDirectory(directoryURL)
        }

        return childURLs.sorted {
            $0.lastPathComponent < $1.lastPathComponent
        }
    }

    private func pendingTransactionDirectories() throws -> [URL] {
        guard pathKind(at: recoveryRootURL) == .directory else {
            return []
        }

        return try boundedRecoveryDirectoryURLs().filter {
            candidateURL in
            pathKind(at: markerURL(in: candidateURL)) != .missing ||
                pathKind(
                    at: markerTemporaryURL(in: candidateURL)
                ) != .missing
        }
    }

    private func pathKind(at url: URL) -> PathKind {
        var fileStatus = stat()
        guard Darwin.lstat(url.path, &fileStatus) == 0 else {
            return errno == ENOENT ? .missing : .other
        }

        switch fileStatus.st_mode & S_IFMT {
        case S_IFREG:
            return .regularFile
        case S_IFDIR:
            return .directory
        case S_IFLNK:
            return .symbolicLink
        default:
            return .other
        }
    }

    // Raw lstat fields form one atomic file identity.
    private func lstatValues(
        at url: URL
    ) throws -> ( // swiftlint:disable:this large_tuple
        byteCount: UInt64,
        deviceID: UInt64,
        inode: UInt64,
        linkCount: UInt64
    ) {
        var fileStatus = stat()
        guard Darwin.lstat(url.path, &fileStatus) == 0 else {
            throw POSIXError(
                POSIXErrorCode(rawValue: errno) ?? .EIO
            )
        }
        guard
            fileStatus.st_mode & S_IFMT == S_IFREG,
            fileStatus.st_size >= 0
        else {
            throw SubstrateCacheRecoveryTransactionError
                .unsafeFile(url)
        }

        return (
            byteCount: UInt64(fileStatus.st_size),
            deviceID: UInt64(
                truncatingIfNeeded: fileStatus.st_dev
            ),
            inode: UInt64(
                truncatingIfNeeded: fileStatus.st_ino
            ),
            linkCount: UInt64(
                truncatingIfNeeded: fileStatus.st_nlink
            )
        )
    }
}

struct SubstrateProtectedDataInspectionLimits {
    static let production = SubstrateProtectedDataInspectionLimits(
        fetchPageSize: 256,
        maximumRowsPerEntity: 250_000,
        maximumTotalRows: 1_000_000,
        maximumStartupRootRowsPerEntity: 4096,
        maximumStartupRootPayloadByteCount: 256 * 1024 * 1024,
        maximumStartupChildValueByteCount: 256 * 1024,
        maximumStartupChildPayloadByteCount: 256 * 1024 * 1024,
        maximumRelationshipMembers: 10000,
        maximumTotalRelationshipMembers: 1_000_000,
        maximumTransformableElements: 4096,
        maximumTransformableArchiveByteCount: 256 * 1024,
        maximumValueByteCount: 256 * 1024,
        maximumRecordByteCount: 1024 * 1024
    )

    let fetchPageSize: Int
    let maximumRowsPerEntity: Int
    let maximumTotalRows: Int
    let maximumStartupRootRowsPerEntity: Int
    let maximumStartupRootPayloadByteCount: UInt64
    let maximumStartupChildValueByteCount: UInt64
    let maximumStartupChildPayloadByteCount: UInt64
    let maximumRelationshipMembers: Int
    let maximumTotalRelationshipMembers: Int
    let maximumTransformableElements: Int
    let maximumTransformableArchiveByteCount: Int
    let maximumValueByteCount: Int
    let maximumRecordByteCount: Int

    init(
        fetchPageSize: Int,
        maximumRowsPerEntity: Int,
        maximumTotalRows: Int,
        maximumStartupRootRowsPerEntity: Int,
        maximumStartupRootPayloadByteCount: UInt64,
        maximumStartupChildValueByteCount: UInt64,
        maximumStartupChildPayloadByteCount: UInt64,
        maximumRelationshipMembers: Int,
        maximumTotalRelationshipMembers: Int,
        maximumTransformableElements: Int,
        maximumTransformableArchiveByteCount: Int,
        maximumValueByteCount: Int,
        maximumRecordByteCount: Int
    ) {
        precondition(fetchPageSize > 0)
        precondition(maximumRowsPerEntity >= 0)
        precondition(maximumTotalRows >= 0)
        precondition(maximumStartupRootRowsPerEntity >= 0)
        precondition(maximumRelationshipMembers >= 0)
        precondition(maximumTotalRelationshipMembers >= 0)
        precondition(maximumTransformableElements >= 0)
        precondition(maximumTransformableArchiveByteCount >= 0)
        precondition(maximumValueByteCount >= 0)
        precondition(maximumRecordByteCount >= 0)

        self.fetchPageSize = fetchPageSize
        self.maximumRowsPerEntity = maximumRowsPerEntity
        self.maximumTotalRows = maximumTotalRows
        self.maximumStartupRootRowsPerEntity =
            maximumStartupRootRowsPerEntity
        self.maximumStartupRootPayloadByteCount =
            maximumStartupRootPayloadByteCount
        self.maximumStartupChildValueByteCount =
            maximumStartupChildValueByteCount
        self.maximumStartupChildPayloadByteCount =
            maximumStartupChildPayloadByteCount
        self.maximumRelationshipMembers =
            maximumRelationshipMembers
        self.maximumTotalRelationshipMembers =
            maximumTotalRelationshipMembers
        self.maximumTransformableElements =
            maximumTransformableElements
        self.maximumTransformableArchiveByteCount =
            maximumTransformableArchiveByteCount
        self.maximumValueByteCount = maximumValueByteCount
        self.maximumRecordByteCount = maximumRecordByteCount
    }
}

enum SubstrateProtectedDataInspectionError: LocalizedError {
    case entityUnavailable(String)
    case relationshipUnavailable(String, String)
    case countUnavailable(String)
    case entityRowLimitExceeded(String, Int, Int)
    case totalRowLimitExceeded(Int, Int)
    case relationshipLimitExceeded(String, String, Int, Int)
    case relationshipCountUnavailable(String, String)
    case totalRelationshipLimitExceeded(Int, Int)
    case valueByteLimitExceeded(String, String, Int, Int)
    case recordByteLimitExceeded(String, Int, Int)
    case relationshipValueInvalid(String, String)
    case unsupportedAttributeValue(String, String, String)
    case startupRootPayloadByteLimitExceeded(UInt64, UInt64)
    case startupChildValueByteLimitExceeded(
        String,
        String,
        UInt64,
        UInt64
    )
    case startupChildPayloadByteLimitExceeded(UInt64, UInt64)

    var errorDescription: String? {
        switch self {
        case let .entityUnavailable(entityName):
            return "Protected-data inspection requires the \(entityName) entity"
        case let .relationshipUnavailable(entityName, relationshipName):
            return """
            Protected-data inspection requires the \(entityName).\(relationshipName) relationship
            """
        case let .countUnavailable(entityName):
            return "Protected-data inspection could not count \(entityName)"
        case let .entityRowLimitExceeded(
            entityName,
            actual,
            maximum
        ):
            return """
            Protected-data inspection found \(actual) \(entityName) rows; \
            the deterministic safety limit is \(maximum)
            """
        case let .totalRowLimitExceeded(actual, maximum):
            return """
            Protected-data inspection found \(actual) total protected rows; \
            the deterministic safety limit is \(maximum)
            """
        case let .relationshipLimitExceeded(
            entityName,
            relationshipName,
            actual,
            maximum
        ):
            return """
            Protected-data inspection found \(actual) members in \
            \(entityName).\(relationshipName); the deterministic safety limit \
            is \(maximum)
            """
        case let .relationshipCountUnavailable(
            entityName,
            relationshipName
        ):
            return """
            Protected-data inspection could not count \
            \(entityName).\(relationshipName) without materializing it
            """
        case let .totalRelationshipLimitExceeded(actual, maximum):
            return """
            Protected-data inspection found \(actual) protected relationship \
            members; the deterministic safety limit is \(maximum)
            """
        case let .valueByteLimitExceeded(
            entityName,
            attributeName,
            actual,
            maximum
        ):
            return """
            Protected-data inspection found a \(actual)-byte value at \
            \(entityName).\(attributeName); the deterministic safety limit is \
            \(maximum) bytes
            """
        case let .recordByteLimitExceeded(
            category,
            actual,
            maximum
        ):
            return """
            Protected-data inspection produced a \(actual)-byte \(category) \
            record; the deterministic safety limit is \(maximum) bytes
            """
        case let .relationshipValueInvalid(
            entityName,
            relationshipName
        ):
            return """
            Protected-data inspection found an invalid relationship value at \
            \(entityName).\(relationshipName)
            """
        case let .unsupportedAttributeValue(
            entityName,
            attributeName,
            className
        ):
            return """
            Protected-data inspection cannot safely compare \(className) at \
            \(entityName).\(attributeName)
            """
        case let .startupRootPayloadByteLimitExceeded(
            actual,
            maximum
        ):
            return """
            Startup root payloads use \(actual) bytes; the deterministic \
            safety limit is \(maximum)
            """
        case let .startupChildValueByteLimitExceeded(
            entityName,
            attributeName,
            actual,
            maximum
        ):
            return """
            Startup child payload \(entityName).\(attributeName) uses \
            \(actual) bytes; the deterministic safety limit is \(maximum)
            """
        case let .startupChildPayloadByteLimitExceeded(
            actual,
            maximum
        ):
            return """
            Startup child payloads use \(actual) bytes; the deterministic \
            safety limit is \(maximum)
            """
        }
    }
}

private enum SubstrateLegacyXcmMappingError: LocalizedError {
    case entityMappingUnavailable(String)
    case sourceAssociationUnavailable(String)
    case destinationRelationshipUnavailable(String, String)
    case destinationEntityUnavailable(String)

    var errorDescription: String? {
        switch self {
        case let .entityMappingUnavailable(entityName):
            return "Legacy XCM migration requires the \(entityName) entity mapping"
        case let .sourceAssociationUnavailable(entityName):
            return "Legacy XCM migration cannot find the source \(entityName) object"
        case let .destinationRelationshipUnavailable(entityName, relationshipName):
            return "Legacy XCM migration requires \(entityName).\(relationshipName)"
        case let .destinationEntityUnavailable(entityName):
            return "Legacy XCM migration requires the \(entityName) destination entity"
        }
    }
}

private enum SubstrateTransformableRepairError: LocalizedError {
    case countUnavailable(String)
    case entityRowLimitExceeded(String, Int, Int)
    case totalRowLimitExceeded(Int, Int)
    case objectIDEnumerationMismatch(String)
    case unexpectedBatchUpdateResult(String, String)
    case repairedValueCountOverflow

    var errorDescription: String? {
        switch self {
        case let .countUnavailable(entityName):
            return "Unable to count \(entityName) rows for private cache repair"
        case let .entityRowLimitExceeded(
            entityName,
            actual,
            maximum
        ):
            return """
            Private cache repair found \(actual) \(entityName) rows; \
            the deterministic safety limit is \(maximum)
            """
        case let .totalRowLimitExceeded(actual, maximum):
            return """
            Private cache repair found \(actual) total rows; \
            the deterministic safety limit is \(maximum)
            """
        case let .objectIDEnumerationMismatch(entityName):
            return "Unable to enumerate every \(entityName) row for private cache repair"
        case let .unexpectedBatchUpdateResult(entityName, attributeName):
            return """
            Private cache repair did not update exactly one \
            \(entityName).\(attributeName) row
            """
        case .repairedValueCountOverflow:
            return "Private cache repair count exceeded its bounded counter"
        }
    }
}

// Migration invariants remain in one auditable state machine.
// swiftlint:disable:next type_body_length
final class SubstrateStorageMigrator {
    private struct StartupToManyRelationshipFamily {
        let entityName: String
        let relationshipNames: [String]
    }

    private static let intentionallyTransformedEntityNames: Set<String> = [
        "CDChainAsset"
    ]

    private static let storeFamilySuffixes = ["", "-wal", "-shm", "-journal"]

    // These collections are mapped eagerly during normal v8 startup. Audit
    // their SQL counts on the disposable store before application mapping can
    // materialize any unbounded relationship value.
    private static let version8StartupRootEntityNames = [
        "CDChain",
        "CDRuntimeMetadataItem"
    ]
    // ChainModelMapper traverses every one of these entities from CDChain
    // during the first repository fetch. Keep the raw SQLite audit explicit:
    // to-one children such as priceProvider and selected/custom nodes are not
    // covered by the to-many relationship-count audit below.
    private static let version8StartupChildEntityNames = [
        "CDAsset",
        "CDChainNode",
        "CDChainXcmConfig",
        "CDExternalApi",
        "CDPriceData",
        "CDPriceProvider",
        "CDXcmAvailableAsset",
        "CDXcmAvailableDestination"
    ]
    private static let version8StartupToManyRelationshipFamilies = [
        StartupToManyRelationshipFamily(
            entityName: "CDAsset",
            relationshipNames: ["priceData"]
        ),
        StartupToManyRelationshipFamily(
            entityName: "CDChain",
            relationshipNames: [
                "assets",
                "customNodes",
                "explorers",
                "nodes"
            ]
        ),
        StartupToManyRelationshipFamily(
            entityName: "CDChainXcmConfig",
            relationshipNames: [
                "availableAssets",
                "availableDestinations"
            ]
        ),
        StartupToManyRelationshipFamily(
            entityName: "CDXcmAvailableDestination",
            relationshipNames: ["assets"]
        )
    ]

    private static let resilientStringArrayTransformables: Set<String> = [
        "CDAsset.purchaseProviders",
        "CDChain.options",
        "CDChainAsset.purchaseProviders",
        "CDChainXcmConfig.availableAssets",
        "CDExternalApi.types",
        "CDPolkaswapRemoteSettings.availableSources",
        "CDPolkaswapRemoteSettings.forceSmartIds",
        "CDXcmAvailableDestination.assets"
    ]

    private enum ProtectedDataCategory {
        static let contacts = "CDContact"
        static let contactItems = "CDContactItem"
        static let transactionHistory = "CDTransactionHistoryItem"
        static let customNodeRelationships = "CDChain.customNodes"
        static let selectedNodeRelationships = "CDChain.selectedNode"
        static let orphanNodes = "CDChainNode.orphan"
    }

    private struct ProtectedDataFootprint {
        let counts: [String: Int]

        var isEmpty: Bool {
            counts.values.allSatisfy { $0 == 0 }
        }
    }

    private struct ProtectedDataDigest: Equatable {
        let recordCount: UInt64
        let additiveWords: [UInt64]
    }

    private struct ProtectedDataDigestAccumulator {
        private(set) var recordCount: UInt64 = 0
        private var additiveWords = Array(
            repeating: UInt64(0),
            count: 8
        )

        mutating func append(
            _ record: String,
            category: String,
            maximumByteCount: Int
        ) throws {
            let recordData = Data(record.utf8)
            guard recordData.count <= maximumByteCount else {
                throw SubstrateProtectedDataInspectionError
                    .recordByteLimitExceeded(
                        category,
                        recordData.count,
                        maximumByteCount
                    )
            }
            let domainData = Data(category.utf8)
            for discriminator in UInt8(0) ... UInt8(1) {
                var framedData = Data([discriminator])
                var domainLength = UInt64(domainData.count).bigEndian
                withUnsafeBytes(of: &domainLength) {
                    framedData.append(contentsOf: $0)
                }
                framedData.append(domainData)
                var recordLength = UInt64(recordData.count).bigEndian
                withUnsafeBytes(of: &recordLength) {
                    framedData.append(contentsOf: $0)
                }
                framedData.append(recordData)

                let digest = Array(SHA256.hash(data: framedData))
                let wordOffset = Int(discriminator) * 4
                for wordIndex in 0 ..< 4 {
                    let byteOffset = wordIndex * 8
                    var word: UInt64 = 0
                    for byte in digest[
                        byteOffset ..< byteOffset + 8
                    ] {
                        word = (word << 8) | UInt64(byte)
                    }
                    additiveWords[wordOffset + wordIndex] &+= word
                }
            }

            recordCount += 1
        }

        func finalize() -> ProtectedDataDigest {
            ProtectedDataDigest(
                recordCount: recordCount,
                additiveWords: additiveWords
            )
        }
    }

    private struct ProtectedDataSnapshot: Equatable {
        let contacts: ProtectedDataDigest
        let contactItems: ProtectedDataDigest
        let transactionHistory: ProtectedDataDigest
        let chainNodeTopologies: ProtectedDataDigest
        let orphanNodes: ProtectedDataDigest
    }

    private struct CompatibleStore {
        let version: SubstrateStorageVersion
        let model: NSManagedObjectModel
    }

    private struct SourceSnapshot {
        let rootURL: URL
        let workingStoreURL: URL
    }

    private struct PreparedSource {
        let snapshot: SourceSnapshot
        let compatibleStore: CompatibleStore
        let repairedTransformableValueCount: Int
    }

    private struct MigrationStep {
        let sourceVersion: SubstrateStorageVersion
        let destinationVersion: SubstrateStorageVersion
        let sourceModel: NSManagedObjectModel
        let destinationModel: NSManagedObjectModel
        let mapping: NSMappingModel
    }

    private struct RequiredCustomMapping {
        let resourceName: String
        let policyClassName: String
    }

    let storeURL: URL
    let modelDirectory: String
    let fileManager: FileManager
    let targetVersion: SubstrateStorageVersion
    let modelBundle: Bundle
    private let crashConsistentStoreReplacer: CrashConsistentStoreReplacer
    private let crashConsistentCacheRecovery:
        CrashConsistentSubstrateCacheRecovery
    private let stagedStoreMutationHook: (URL, NSManagedObjectModel) throws -> Void
    private let checkpointStoreHook: ((URL, NSManagedObjectModel) throws -> Void)?
    private let privateSourceCopyLimits:
        SQLiteStoreFamilyCopyLimits
    private let privateSourceAvailableCapacityProvider:
        ((URL) throws -> UInt64)?
    private let protectedDataInspectionLimits:
        SubstrateProtectedDataInspectionLimits
    private let transformableObjectIDPageDidFetch: (
        String,
        Int,
        Int
    ) -> Void
    private let protectedRelationshipCountDidFetch: (
        NSManagedObject,
        String,
        Int
    ) -> Void
    private let protectedRelationshipWillMaterialize: (
        String,
        String,
        Int
    ) -> Void

    init(
        targetVersion: SubstrateStorageVersion,
        storeURL: URL,
        modelDirectory: String,
        fileManager: FileManager,
        modelBundle: Bundle = .main,
        storeReplacer: @escaping (URL, URL) throws -> Void = { targetURL, sourceURL in
            try NSPersistentStoreCoordinator.replaceStore(
                at: targetURL,
                withStoreAt: sourceURL
            )
        },
        stagedStoreMutationHook: @escaping (
            URL,
            NSManagedObjectModel
        ) throws -> Void = { _, _ in },
        checkpointStoreHook: ((URL, NSManagedObjectModel) throws -> Void)? = nil,
        privateSourceCopyLimits:
        SQLiteStoreFamilyCopyLimits =
            .substrateStorageProduction,
        privateSourceAvailableCapacityProvider:
        ((URL) throws -> UInt64)? = nil,
        storeReplacementBoundaryHook: @escaping (
            CrashConsistentStoreReplacementBoundary
        ) throws -> Void = { _ in },
        cacheRecoveryBoundaryHook: @escaping (
            SubstrateCacheRecoveryBoundary
        ) throws -> Void = { _ in },
        protectedDataInspectionLimits:
        SubstrateProtectedDataInspectionLimits = .production,
        transformableObjectIDPageDidFetch: @escaping (
            String,
            Int,
            Int
        ) -> Void = { _, _, _ in },
        protectedRelationshipCountDidFetch: @escaping (
            NSManagedObject,
            String,
            Int
        ) -> Void = { _, _, _ in },
        protectedRelationshipWillMaterialize: @escaping (
            String,
            String,
            Int
        ) -> Void = { _, _, _ in }
    ) {
        self.targetVersion = targetVersion
        self.storeURL = storeURL
        self.modelDirectory = modelDirectory
        self.fileManager = fileManager
        self.modelBundle = modelBundle
        crashConsistentStoreReplacer = CrashConsistentStoreReplacer(
            storeURL: storeURL,
            fileManager: fileManager,
            storeReplacer: storeReplacer,
            boundaryHook: storeReplacementBoundaryHook,
            maximumStoreFamilyByteCount:
            privateSourceCopyLimits.maximumFamilyByteCount,
            minimumFreeStorageReserveByteCount:
            privateSourceCopyLimits
                .minimumFreeStorageReserveByteCount,
            availableCapacityProvider:
            privateSourceAvailableCapacityProvider
        )
        crashConsistentCacheRecovery =
            CrashConsistentSubstrateCacheRecovery(
                storeURL: storeURL,
                fileManager: fileManager,
                boundaryHook: cacheRecoveryBoundaryHook
            )
        self.stagedStoreMutationHook = stagedStoreMutationHook
        self.checkpointStoreHook = checkpointStoreHook
        self.privateSourceCopyLimits = privateSourceCopyLimits
        self.privateSourceAvailableCapacityProvider =
            privateSourceAvailableCapacityProvider
        self.protectedDataInspectionLimits =
            protectedDataInspectionLimits
        self.transformableObjectIDPageDidFetch =
            transformableObjectIDPageDidFetch
        self.protectedRelationshipCountDidFetch =
            protectedRelationshipCountDidFetch
        self.protectedRelationshipWillMaterialize =
            protectedRelationshipWillMaterialize
    }

    func performMigrationWithRecovery() throws -> URL? {
        try reconcilePendingCacheRecovery()
        try reconcilePendingStoreReplacement()

        guard try crashConsistentStoreReplacer.liveStoreExistsSafely() else {
            return nil
        }

        var initialFootprint: ProtectedDataFootprint?

        do {
            try withPreparedSource(
                afterModelDetection: { source in
                    guard source.compatibleStore.version != self.targetVersion else {
                        return
                    }

                    initialFootprint = try self
                        .inspectProtectedDataUsingSanitizedPrivateCopy(
                            of: source
                        )
                }
            ) { source in
                guard source.compatibleStore.version != targetVersion else {
                    try repairCurrentStoreIfNeeded(from: source)
                    return
                }

                try performMigration(from: source)
            }

            return nil
        } catch let migrationError as SubstrateStorageMigrationError {
            guard migrationError.allowsCacheRebuild else {
                throw migrationError
            }

            guard let initialFootprint else {
                throw migrationError
            }

            guard initialFootprint.isEmpty else {
                throw SubstrateStorageMigrationError.cacheRecoveryBlockedByProtectedData(
                    storeURL,
                    migrationError,
                    initialFootprint.counts
                )
            }

            let finalFootprint = try inspectProtectedDataInExistingStore()
            guard finalFootprint.isEmpty else {
                throw SubstrateStorageMigrationError.cacheRecoveryBlockedByProtectedData(
                    storeURL,
                    migrationError,
                    finalFootprint.counts
                )
            }

            return try recoverRebuildableCache(after: migrationError)
        }
    }

    func performMigration() throws {
        try reconcilePendingCacheRecovery()
        try reconcilePendingStoreReplacement()

        guard try crashConsistentStoreReplacer.liveStoreExistsSafely() else {
            return
        }

        try withPreparedSource { source in
            guard source.compatibleStore.version != targetVersion else {
                try repairCurrentStoreIfNeeded(from: source)
                return
            }

            try performMigration(from: source)
        }
    }

    private func repairCurrentStoreIfNeeded(
        from source: PreparedSource
    ) throws {
        let model = source.compatibleStore.model
        let entityNames = Set(
            model.entities.compactMap(\.name)
        )
        let expectedRowCounts: [String: Int]
        let expectedProtectedData: ProtectedDataSnapshot

        do {
            if source.compatibleStore.version == .version8 {
                try inspectVersion8StartupGraphBounds(
                    at: source.snapshot.workingStoreURL,
                    model: model
                )
            }
            expectedRowCounts = try inspectStoreRowCounts(
                at: source.snapshot.workingStoreURL,
                model: model,
                entityNames: entityNames,
                operation: .sourceRowInspection
            )
            expectedProtectedData = try inspectProtectedDataSnapshot(
                at: source.snapshot.workingStoreURL,
                model: model
            )
        } catch let migrationError as SubstrateStorageMigrationError {
            throw migrationError
        } catch {
            throw SubstrateStorageMigrationError
                .sourceStoreInspectionFailed(storeURL, error)
        }

        // A clean current store is still fully inspected above, but remains a
        // byte-identical no-op: neither the staged hook nor replacer runs.
        guard source.repairedTransformableValueCount > 0 else {
            return
        }

        do {
            try stagedStoreMutationHook(
                source.snapshot.workingStoreURL,
                model
            )
        } catch {
            throw SubstrateStorageMigrationError
                .stagedStoreInspectionFailed(
                    source.snapshot.workingStoreURL,
                    error
                )
        }

        try validateStagedStore(
            at: source.snapshot.workingStoreURL,
            targetModel: model,
            expectedRowCounts: expectedRowCounts,
            expectedProtectedData: expectedProtectedData
        )

        do {
            try crashConsistentStoreReplacer.replaceStore(
                with: source.snapshot.workingStoreURL
            ) { liveStoreURL in
                try self.validateStagedStore(
                    at: liveStoreURL,
                    targetModel: model,
                    expectedRowCounts: expectedRowCounts,
                    expectedProtectedData: expectedProtectedData
                )
            }
        } catch let migrationError as SubstrateStorageMigrationError {
            throw migrationError
        } catch {
            throw SubstrateStorageMigrationError
                .storeReplacementFailed(storeURL, error)
        }
    }

    private func performMigration(from source: PreparedSource) throws {
        let compatibleStore = source.compatibleStore
        let migrationPlan = try createMigrationPlan(
            from: compatibleStore,
            to: targetVersion
        )

        guard let targetModel = migrationPlan.last?.destinationModel else {
            throw SubstrateStorageMigrationError.migrationPathUnavailable(
                compatibleStore.version,
                targetVersion
            )
        }

        let preservedEntityNames = Set(compatibleStore.model.entitiesByName.keys)
            .intersection(targetModel.entitiesByName.keys)
            .subtracting(Self.intentionallyTransformedEntityNames)
        let sourceRowCounts: [String: Int]
        let sourceProtectedData: ProtectedDataSnapshot

        do {
            sourceRowCounts = try inspectStoreRowCounts(
                at: source.snapshot.workingStoreURL,
                model: compatibleStore.model,
                entityNames: preservedEntityNames,
                operation: .sourceRowInspection
            )
            sourceProtectedData = try inspectProtectedDataSnapshot(
                at: source.snapshot.workingStoreURL,
                model: compatibleStore.model,
                normalizingMissingSelectedNode:
                compatibleStore.version == .version1
            )
        } catch let migrationError as SubstrateStorageMigrationError {
            throw migrationError
        } catch {
            throw SubstrateStorageMigrationError.sourceStoreInspectionFailed(
                storeURL,
                error
            )
        }

        let tmpMigrationDirURL = source.snapshot.rootURL
            .appendingPathComponent("Migration", isDirectory: true)

        do {
            try fileManager.createDirectory(
                at: tmpMigrationDirURL,
                withIntermediateDirectories: true
            )
        } catch {
            throw SubstrateStorageMigrationError.temporaryDirectoryCreationFailed(
                tmpMigrationDirURL,
                error
            )
        }

        let stagedStore = try createStagedStore(
            using: migrationPlan,
            sourceStoreURL: source.snapshot.workingStoreURL,
            migrationDirectoryURL: tmpMigrationDirURL
        )

        do {
            try stagedStoreMutationHook(stagedStore, targetModel)
        } catch {
            throw SubstrateStorageMigrationError.stagedStoreInspectionFailed(
                stagedStore,
                error
            )
        }

        try validateStagedStore(
            at: stagedStore,
            targetModel: targetModel,
            expectedRowCounts: sourceRowCounts,
            expectedProtectedData: sourceProtectedData
        )

        do {
            try crashConsistentStoreReplacer.replaceStore(
                with: stagedStore
            ) { liveStoreURL in
                try self.validateStagedStore(
                    at: liveStoreURL,
                    targetModel: targetModel,
                    expectedRowCounts: sourceRowCounts,
                    expectedProtectedData: sourceProtectedData
                )
            }
        } catch let migrationError as SubstrateStorageMigrationError {
            throw migrationError
        } catch {
            throw SubstrateStorageMigrationError.storeReplacementFailed(storeURL, error)
        }
    }

    private func reconcilePendingStoreReplacement() throws {
        do {
            try crashConsistentStoreReplacer.reconcile {
                liveStoreURL in

                let compatibleStore = try self.loadCompatibleStore(
                    at: liveStoreURL
                )
                guard compatibleStore.version == self.targetVersion else {
                    throw SubstrateStorageMigrationError.stagedStoreInvalid(
                        liveStoreURL,
                        self.targetVersion
                    )
                }
            }
        } catch let migrationError as SubstrateStorageMigrationError {
            throw migrationError
        } catch {
            throw SubstrateStorageMigrationError
                .storeReplacementFailed(storeURL, error)
        }
    }

    private func reconcilePendingCacheRecovery() throws {
        do {
            try crashConsistentCacheRecovery.reconcile()
        } catch is SubstrateCacheRecoveryInterruption {
            throw SubstrateCacheRecoveryInterruption
                .simulatedProcessDeath
        } catch {
            throw SubstrateStorageMigrationError
                .pendingCacheRecoveryFailed(storeURL, error)
        }
    }

    private func withPreparedSource(
        afterModelDetection: ((PreparedSource) throws -> Void)? = nil,
        _ operation: (PreparedSource) throws -> Void
    ) throws {
        let snapshot = try createPrivateSourceSnapshot()

        defer {
            do {
                if fileManager.fileExists(atPath: snapshot.rootURL.path) {
                    try fileManager.removeItem(at: snapshot.rootURL)
                }
            } catch {
                Logger.shared.error(
                    "Unable to clean up a private Substrate store snapshot"
                )
            }
        }

        let compatibleStore = try loadCompatibleStore(
            at: snapshot.workingStoreURL
        )
        let detectedSource = PreparedSource(
            snapshot: snapshot,
            compatibleStore: compatibleStore,
            repairedTransformableValueCount: 0
        )

        // Recovery decisions use a second isolated copy repaired only in
        // explicitly rebuildable cache fields. The migration working copy
        // remains untouched until this inspection succeeds.
        try afterModelDetection?(detectedSource)

        if compatibleStore.version != targetVersion {
            try forceWALCheckpointingForStore(
                at: snapshot.workingStoreURL,
                sourceModel: compatibleStore.model
            )
        }

        let repairedTransformableValueCount =
            try sanitizeTransformableValues(
                at: snapshot.workingStoreURL,
                compatibleStore: compatibleStore
            )
        let preparedSource = PreparedSource(
            snapshot: snapshot,
            compatibleStore: compatibleStore,
            repairedTransformableValueCount:
            repairedTransformableValueCount
        )

        try operation(preparedSource)
    }

    private func inspectProtectedDataUsingSanitizedPrivateCopy(
        of source: PreparedSource
    ) throws -> ProtectedDataFootprint {
        let inspectionRootURL = fileManager.temporaryDirectory
            .appendingPathComponent(
                "SubstrateProtectedInspection-\(UUID().uuidString)",
                isDirectory: true
            )
        let inspectionStoreURL = inspectionRootURL
            .appendingPathComponent(storeURL.lastPathComponent)
        defer {
            try? fileManager.removeItem(at: inspectionRootURL)
        }

        do {
            try fileManager.createDirectory(
                at: inspectionRootURL,
                withIntermediateDirectories: false
            )
            try copyStoreFamily(
                from: source.snapshot.workingStoreURL,
                to: inspectionStoreURL,
                includingSharedMemory: false
            )
        } catch {
            throw SubstrateStorageMigrationError
                .sourceStoreInspectionFailed(storeURL, error)
        }

        _ = try sanitizeTransformableValues(
            at: inspectionStoreURL,
            compatibleStore: source.compatibleStore
        )

        return try inspectProtectedData(
            at: inspectionStoreURL,
            model: source.compatibleStore.model
        )
    }

    private func createPrivateSourceSnapshot() throws -> SourceSnapshot {
        let rootURL = fileManager.temporaryDirectory.appendingPathComponent(
            "SubstrateStorageSource-\(UUID().uuidString)",
            isDirectory: true
        )
        let workingStoreURL = rootURL.appendingPathComponent(
            storeURL.lastPathComponent
        )

        do {
            try fileManager.createDirectory(
                at: rootURL,
                withIntermediateDirectories: true
            )

            // Never open or checkpoint the installed store. The sole private
            // copy is disposable and intentionally omits process-local SHM.
            try copyStoreFamily(
                from: storeURL,
                to: workingStoreURL,
                includingSharedMemory: false
            )
        } catch {
            try? fileManager.removeItem(at: rootURL)
            throw SubstrateStorageMigrationError.sourceSnapshotFailed(
                storeURL,
                error
            )
        }

        return SourceSnapshot(
            rootURL: rootURL,
            workingStoreURL: workingStoreURL
        )
    }

    private func copyStoreFamily(
        from sourceURL: URL,
        to destinationURL: URL,
        includingSharedMemory: Bool
    ) throws {
        try SQLiteStoreFamilyCopier.copy(
            from: sourceURL,
            to: destinationURL,
            includingSharedMemory: includingSharedMemory,
            fileManager: fileManager,
            limits: privateSourceCopyLimits,
            availableCapacityProvider:
            privateSourceAvailableCapacityProvider
        )
    }

    private func sanitizeTransformableValues(
        at url: URL,
        compatibleStore: CompatibleStore
    ) throws -> Int {
        let model = compatibleStore.model
        let transformables = try transformableAttributes(
            in: model,
            version: compatibleStore.version
        )

        guard !transformables.isEmpty else {
            return 0
        }

        var repairedValueCount = 0
        do {
            try performWithObjectiveCExceptionBoundary(
                operation: .transformableSanitization
            ) {
                let archiveColumns = transformables.flatMap {
                    transformable in

                    transformable.1.map { attribute in
                        SQLiteTransformableArchiveColumn(
                            entityName: transformable.0,
                            attributeName: attribute.name,
                            isOptional: attribute.isOptional,
                            valueTransformerName:
                            attribute.valueTransformerName
                        )
                    }
                }

                // This runs against the disposable, checkpointed source copy
                // before a Core Data coordinator can load or decode any of
                // these allowlisted archives.
                repairedValueCount =
                    try SQLiteTransformableArchivePreflight
                        .repairOversizedArchives(
                            at: url,
                            columns: archiveColumns,
                            maximumArchiveByteCount:
                            self.protectedDataInspectionLimits
                                .maximumTransformableArchiveByteCount
                        )

                let coordinator = NSPersistentStoreCoordinator(
                    managedObjectModel: model
                )
                let store = try coordinator.addPersistentStore(
                    ofType: NSSQLiteStoreType,
                    configurationName: nil,
                    at: url,
                    options: [
                        NSSQLitePragmasOption: ["journal_mode": "DELETE"],
                        NSMigratePersistentStoresAutomaticallyOption: false,
                        NSInferMappingModelAutomaticallyOption: false
                    ]
                )
                defer {
                    try? coordinator.remove(store)
                }

                let context = NSManagedObjectContext(
                    concurrencyType: .privateQueueConcurrencyType
                )
                context.persistentStoreCoordinator = coordinator

                var contextError: Error?
                context.performAndWait {
                    do {
                        let rowCounts =
                            try self.transformableSanitizationRowCounts(
                                transformables: transformables,
                                context: context
                            )
                        for (entityName, attributes) in transformables {
                            let repairedEntityValueCount =
                                try self.sanitizeTransformableEntity(
                                    entityName: entityName,
                                    attributes: attributes,
                                    rowCount: rowCounts[entityName] ?? 0,
                                    context: context,
                                    persistentStore: store
                                )
                            try self.addRepairedValueCount(
                                repairedEntityValueCount,
                                to: &repairedValueCount
                            )
                        }
                    } catch {
                        contextError = error
                    }
                }

                if let contextError {
                    throw contextError
                }
            }
        } catch let migrationError as SubstrateStorageMigrationError {
            throw migrationError
        } catch {
            throw SubstrateStorageMigrationError.transformableSanitizationFailed(
                compatibleStore.version,
                error
            )
        }

        return repairedValueCount
    }

    private func addRepairedValueCount(
        _ count: Int,
        to totalCount: inout Int
    ) throws {
        let addition = totalCount.addingReportingOverflow(count)
        guard !addition.overflow else {
            throw SubstrateTransformableRepairError
                .repairedValueCountOverflow
        }
        totalCount = addition.partialValue
    }

    private func transformableSanitizationRowCounts(
        transformables: [(String, [NSAttributeDescription])],
        context: NSManagedObjectContext
    ) throws -> [String: Int] {
        var rowCounts = [String: Int]()
        var totalRowCount = 0

        // Count and enforce every cap before the first repair write. This
        // prevents an adversarial store from forcing an unbounded ID array or
        // receiving a partially sanitized private copy before rejection.
        for (entityName, _) in transformables {
            let request = NSFetchRequest<NSFetchRequestResult>(
                entityName: entityName
            )
            request.includesPendingChanges = false
            request.includesSubentities = false
            let rowCount = try context.count(for: request)
            guard rowCount != NSNotFound else {
                throw SubstrateTransformableRepairError
                    .countUnavailable(entityName)
            }
            guard
                rowCount <=
                protectedDataInspectionLimits.maximumRowsPerEntity
            else {
                throw SubstrateTransformableRepairError
                    .entityRowLimitExceeded(
                        entityName,
                        rowCount,
                        protectedDataInspectionLimits
                            .maximumRowsPerEntity
                    )
            }

            let addition =
                totalRowCount.addingReportingOverflow(rowCount)
            guard
                !addition.overflow,
                addition.partialValue <=
                protectedDataInspectionLimits.maximumTotalRows
            else {
                throw SubstrateTransformableRepairError
                    .totalRowLimitExceeded(
                        addition.overflow
                            ? Int.max
                            : addition.partialValue,
                        protectedDataInspectionLimits.maximumTotalRows
                    )
            }
            totalRowCount = addition.partialValue
            rowCounts[entityName] = rowCount
        }

        return rowCounts
    }

    // Sanitization remains one fail-closed transaction.
    // swiftlint:disable:next function_body_length
    private func sanitizeTransformableEntity(
        entityName: String,
        attributes: [NSAttributeDescription],
        rowCount: Int,
        context: NSManagedObjectContext,
        persistentStore: NSPersistentStore
    ) throws -> Int {
        guard rowCount > 0 else {
            return 0
        }

        let request = NSFetchRequest<NSFetchRequestResult>(
            entityName: entityName
        )
        request.resultType = .managedObjectIDResultType
        request.includesPendingChanges = false
        request.includesSubentities = false
        request.affectedStores = [persistentStore]

        guard rowCount < Int.max else {
            throw SubstrateTransformableRepairError
                .objectIDEnumerationMismatch(entityName)
        }

        // Fetch one bounded, exact cohort before the first repair write.
        // Slicing this immutable ID list avoids offset pagination over rows
        // whose transformable columns are being changed between pages.
        request.fetchLimit = rowCount + 1
        request.fetchBatchSize = min(
            protectedDataInspectionLimits.fetchPageSize,
            rowCount + 1
        )
        let cohortResults = try context.fetch(request)
        let cohortObjectIDs = cohortResults.compactMap {
            $0 as? NSManagedObjectID
        }
        guard
            cohortObjectIDs.count == cohortResults.count,
            cohortObjectIDs.count == rowCount,
            Set(cohortObjectIDs).count == rowCount
        else {
            throw SubstrateTransformableRepairError
                .objectIDEnumerationMismatch(entityName)
        }

        var pageStart = 0
        var repairedValueCount = 0
        while pageStart < cohortObjectIDs.count {
            let pageLength = min(
                protectedDataInspectionLimits.fetchPageSize,
                cohortObjectIDs.count - pageStart
            )
            let pageEnd = pageStart + pageLength
            let pageObjectIDs = Array(
                cohortObjectIDs[pageStart ..< pageEnd]
            )
            let pageRequest = NSFetchRequest<NSFetchRequestResult>(
                entityName: entityName
            )
            pageRequest.resultType = .managedObjectIDResultType
            pageRequest.includesPendingChanges = false
            pageRequest.includesSubentities = false
            pageRequest.predicate = NSPredicate(
                format: "SELF IN %@",
                pageObjectIDs
            )
            pageRequest.affectedStores = [persistentStore]
            pageRequest.fetchLimit = pageObjectIDs.count
            pageRequest.fetchBatchSize = pageObjectIDs.count

            let fetchedPageResults = try context.fetch(pageRequest)
            let fetchedPageObjectIDs = fetchedPageResults.compactMap {
                $0 as? NSManagedObjectID
            }
            transformableObjectIDPageDidFetch(
                entityName,
                fetchedPageObjectIDs.count,
                pageObjectIDs.count
            )
            guard
                fetchedPageObjectIDs.count ==
                fetchedPageResults.count,
                fetchedPageObjectIDs.count ==
                pageObjectIDs.count,
                Set(fetchedPageObjectIDs) == Set(pageObjectIDs)
            else {
                throw SubstrateTransformableRepairError
                    .objectIDEnumerationMismatch(entityName)
            }

            for objectID in pageObjectIDs {
                for attribute in attributes {
                    if try sanitizeStringArray(
                        objectID: objectID,
                        entityName: entityName,
                        attribute: attribute,
                        context: context,
                        persistentStore: persistentStore
                    ) {
                        try addRepairedValueCount(
                            1,
                            to: &repairedValueCount
                        )
                    }
                }
            }
            pageStart = pageEnd
        }

        request.fetchLimit = 0
        request.fetchBatchSize = 0
        guard
            pageStart == rowCount,
            try context.count(for: request) == rowCount
        else {
            throw SubstrateTransformableRepairError
                .objectIDEnumerationMismatch(entityName)
        }

        return repairedValueCount
    }

    private func transformableAttributes(
        in model: NSManagedObjectModel,
        version: SubstrateStorageVersion
    ) throws -> [(String, [NSAttributeDescription])] {
        try model.entities.compactMap { entity in
            guard let entityName = entity.name else {
                return nil
            }

            let attributes = try entity.attributesByName.values
                .filter { $0.attributeType == .transformableAttributeType }
                .sorted { $0.name < $1.name }
                .map { attribute -> NSAttributeDescription in
                    let identifier = "\(entityName).\(attribute.name)"

                    guard Self.resilientStringArrayTransformables.contains(identifier) else {
                        throw SubstrateStorageMigrationError
                            .unsupportedTransformableAttribute(
                                version,
                                entityName,
                                attribute.name
                            )
                    }

                    return attribute
                }

            return attributes.isEmpty ? nil : (entityName, attributes)
        }
        .sorted { $0.0 < $1.0 }
    }

    private func sanitizeStringArray(
        objectID: NSManagedObjectID,
        entityName: String,
        attribute: NSAttributeDescription,
        context: NSManagedObjectContext,
        persistentStore: NSPersistentStore
    ) throws -> Bool {
        let needsRepair: Bool
        let request = NSFetchRequest<NSDictionary>(
            entityName: entityName
        )
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = [attribute.name]
        request.predicate = NSPredicate(
            format: "SELF == %@",
            objectID
        )
        request.affectedStores = [persistentStore]
        request.fetchLimit = 2

        do {
            var rows: [NSDictionary]?
            try SafeObjectiveCExceptionBoundary.perform {
                rows = try context.fetch(request)
            }
            guard
                let rows,
                rows.count == 1
            else {
                throw SubstrateTransformableRepairError
                    .unexpectedBatchUpdateResult(
                        entityName,
                        attribute.name
                    )
            }

            let value = rows[0][attribute.name]
            if let value {
                if value is NSNull {
                    needsRepair = !attribute.isOptional
                } else {
                    needsRepair = !isAcceptableStringArray(
                        value
                    )
                }
            } else {
                needsRepair = !attribute.isOptional
            }
        } catch is SafeTransformableValueReaderError {
            needsRepair = true
        } catch let error as NSError
            where error.domain == NSCocoaErrorDomain &&
            error.code == NSCoderReadCorruptError {
            needsRepair = true
        }

        // A failed transformable decode can leave fetched state unusable.
        // Discard it before issuing a direct store-level repair.
        context.reset()

        guard needsRepair else {
            return false
        }

        guard !context.hasChanges else {
            throw SubstrateTransformableRepairError
                .unexpectedBatchUpdateResult(
                    entityName,
                    attribute.name
                )
        }

        let update = NSBatchUpdateRequest(entityName: entityName)
        update.affectedStores = [persistentStore]
        update.predicate = NSPredicate(
            format: "SELF == %@",
            objectID
        )
        update.propertiesToUpdate = [attribute.name: NSArray()]
        update.resultType = .updatedObjectIDsResultType

        let result = try context.execute(update)
        guard
            let batchResult = result as? NSBatchUpdateResult,
            let updatedObjectIDs = batchResult.result as? [NSManagedObjectID],
            updatedObjectIDs == [objectID]
        else {
            throw SubstrateTransformableRepairError
                .unexpectedBatchUpdateResult(
                    entityName,
                    attribute.name
                )
        }

        context.reset()
        return true
    }

    private func isAcceptableStringArray(_ value: Any) -> Bool {
        guard
            let array = value as? NSArray,
            array.count <=
            protectedDataInspectionLimits
            .maximumTransformableElements
        else {
            return false
        }

        var cumulativeByteCount = 0
        for element in array {
            guard let string = element as? String else {
                return false
            }

            let byteCount = string.utf8.count
            guard
                byteCount <=
                protectedDataInspectionLimits.maximumValueByteCount,
                cumulativeByteCount <=
                protectedDataInspectionLimits.maximumValueByteCount -
                byteCount
            else {
                return false
            }
            cumulativeByteCount += byteCount
        }

        return true
    }

    private func performWithObjectiveCExceptionBoundary(
        operation: SubstrateStorageMigrationOperation,
        _ block: @escaping () throws -> Void
    ) throws {
        do {
            try SafeObjectiveCExceptionBoundary.perform(block)
        } catch SafeTransformableValueReaderError.objectiveCException {
            Logger.shared.error(
                "Substrate storage safely stopped during \(operation.rawValue)"
            )
            throw SubstrateStorageMigrationError.objectiveCException(operation)
        } catch {
            throw error
        }
    }

    private func createMigrationPlan(
        from source: CompatibleStore,
        to destinationVersion: SubstrateStorageVersion
    ) throws -> [MigrationStep] {
        let versions = SubstrateStorageVersion.allCases

        guard
            let sourceIndex = versions.firstIndex(of: source.version),
            let destinationIndex = versions.firstIndex(of: destinationVersion),
            sourceIndex < destinationIndex
        else {
            throw SubstrateStorageMigrationError.migrationPathUnavailable(
                source.version,
                destinationVersion
            )
        }

        var currentVersion = source.version
        var currentModel = source.model
        var visitedVersions = Set<SubstrateStorageVersion>()
        var migrationPlan: [MigrationStep] = []

        while currentVersion != destinationVersion {
            guard
                visitedVersions.insert(currentVersion).inserted,
                let nextVersion = currentVersion.nextVersion()
            else {
                throw SubstrateStorageMigrationError.migrationPathUnavailable(
                    source.version,
                    destinationVersion
                )
            }

            let nextModel = try createManagedObjectModel(for: nextVersion)
            let mapping: NSMappingModel

            do {
                mapping = try createMapping(
                    from: currentModel,
                    sourceVersion: currentVersion,
                    nextModel: nextModel,
                    destinationVersion: nextVersion
                )
            } catch {
                throw SubstrateStorageMigrationError.mappingUnavailable(
                    currentVersion,
                    nextVersion,
                    error
                )
            }

            migrationPlan.append(
                MigrationStep(
                    sourceVersion: currentVersion,
                    destinationVersion: nextVersion,
                    sourceModel: currentModel,
                    destinationModel: nextModel,
                    mapping: mapping
                )
            )

            currentVersion = nextVersion
            currentModel = nextModel
        }

        guard !migrationPlan.isEmpty else {
            throw SubstrateStorageMigrationError.migrationPathUnavailable(
                source.version,
                destinationVersion
            )
        }

        return migrationPlan
    }

    private func createStagedStore(
        using migrationPlan: [MigrationStep],
        sourceStoreURL: URL,
        migrationDirectoryURL: URL
    ) throws -> URL {
        var currentURL = sourceStoreURL

        for step in migrationPlan {
            let nextStepURL = migrationDirectoryURL.appendingPathComponent(
                "\(step.destinationVersion.rawValue)-\(UUID().uuidString).sqlite"
            )
            let manager = NSMigrationManager(
                sourceModel: step.sourceModel,
                destinationModel: step.destinationModel
            )

            do {
                try performWithObjectiveCExceptionBoundary(
                    operation: .stagedMigration
                ) {
                    try manager.migrateStore(
                        from: currentURL,
                        sourceType: NSSQLiteStoreType,
                        options: nil,
                        with: step.mapping,
                        toDestinationURL: nextStepURL,
                        destinationType: NSSQLiteStoreType,
                        destinationOptions: nil
                    )
                }
            } catch let migrationError as SubstrateStorageMigrationError {
                throw migrationError
            } catch {
                throw SubstrateStorageMigrationError.migrationStepFailed(
                    step.sourceVersion,
                    step.destinationVersion,
                    error
                )
            }

            do {
                // At most the current input and its successfully produced
                // output coexist. Do not retain a chain of full SQLite stores.
                try removeStoreFamily(at: currentURL)
            } catch {
                // Best effort prevents the new output from adding to the
                // footprint while the enclosing source-root cleanup runs.
                try? removeStoreFamily(at: nextStepURL)
                throw SubstrateStorageMigrationError.temporaryStoreCleanupFailed(
                    currentURL,
                    error
                )
            }

            currentURL = nextStepURL
        }

        return currentURL
    }

    private func removeStoreFamily(at url: URL) throws {
        for suffix in Self.storeFamilySuffixes {
            let familyURL = URL(fileURLWithPath: url.path + suffix)

            guard fileManager.fileExists(atPath: familyURL.path) else {
                continue
            }

            try fileManager.removeItem(at: familyURL)
        }
    }

    private func validateStagedStore(
        at stagedStoreURL: URL,
        targetModel: NSManagedObjectModel,
        expectedRowCounts: [String: Int],
        expectedProtectedData: ProtectedDataSnapshot
    ) throws {
        let metadata: [String: Any]
        do {
            var inspectedMetadata: [String: Any]?
            try performWithObjectiveCExceptionBoundary(
                operation: .stagedValidation
            ) {
                inspectedMetadata = try NSPersistentStoreCoordinator
                    .metadataForPersistentStore(
                        ofType: NSSQLiteStoreType,
                        at: stagedStoreURL,
                        options: nil
                    )
            }
            metadata = inspectedMetadata ?? [:]
        } catch let migrationError as SubstrateStorageMigrationError {
            throw migrationError
        } catch {
            throw SubstrateStorageMigrationError.stagedStoreMetadataUnreadable(
                stagedStoreURL,
                error
            )
        }

        guard targetModel.isConfiguration(
            withName: targetVersion.rawValue,
            compatibleWithStoreMetadata: metadata
        ) else {
            throw SubstrateStorageMigrationError.stagedStoreInvalid(
                stagedStoreURL,
                targetVersion
            )
        }

        if targetVersion == .version8 {
            do {
                try inspectVersion8StartupGraphBounds(
                    at: stagedStoreURL,
                    model: targetModel
                )
            } catch let migrationError as SubstrateStorageMigrationError {
                throw migrationError
            } catch {
                throw SubstrateStorageMigrationError
                    .stagedStoreInspectionFailed(
                        stagedStoreURL,
                        error
                    )
            }
        }

        let stagedRowCounts: [String: Int]
        do {
            stagedRowCounts = try inspectStoreRowCounts(
                at: stagedStoreURL,
                model: targetModel,
                entityNames: Set(expectedRowCounts.keys),
                operation: .stagedValidation
            )
        } catch let migrationError as SubstrateStorageMigrationError {
            throw migrationError
        } catch {
            throw SubstrateStorageMigrationError.stagedStoreInspectionFailed(
                stagedStoreURL,
                error
            )
        }

        for (entityName, expectedCount) in expectedRowCounts {
            let actualCount = stagedRowCounts[entityName] ?? 0

            guard actualCount == expectedCount else {
                throw SubstrateStorageMigrationError.stagedStoreRowCountMismatch(
                    entityName,
                    expectedCount,
                    actualCount
                )
            }
        }

        let stagedProtectedData: ProtectedDataSnapshot
        do {
            stagedProtectedData = try inspectProtectedDataSnapshot(
                at: stagedStoreURL,
                model: targetModel
            )
        } catch let migrationError as SubstrateStorageMigrationError {
            throw migrationError
        } catch let inspectionError
            as SubstrateProtectedDataInspectionError {
            throw SubstrateStorageMigrationError
                .protectedDataInspectionRejected(
                    stagedStoreURL,
                    inspectionError
                )
        } catch {
            throw SubstrateStorageMigrationError.stagedStoreInspectionFailed(
                stagedStoreURL,
                error
            )
        }

        guard stagedProtectedData == expectedProtectedData else {
            throw SubstrateStorageMigrationError
                .stagedStoreProtectedDataMismatch
        }
    }

    private func inspectProtectedDataInExistingStore() throws -> ProtectedDataFootprint {
        guard fileManager.fileExists(atPath: storeURL.path) else {
            throw SubstrateStorageMigrationError.sourceStoreInspectionFailed(
                storeURL,
                CocoaError(
                    .fileNoSuchFile,
                    userInfo: [NSFilePathErrorKey: storeURL.path]
                )
            )
        }

        let snapshot = try createPrivateSourceSnapshot()
        defer {
            do {
                if fileManager.fileExists(atPath: snapshot.rootURL.path) {
                    try fileManager.removeItem(at: snapshot.rootURL)
                }
            } catch {
                Logger.shared.error(
                    "Unable to clean up a private Substrate recovery-inspection copy"
                )
            }
        }

        // This is the final race-resistant recovery check. Only the private
        // copy's explicitly rebuildable transformables may be repaired before
        // protected-data inspection; the installed family remains untouched.
        let compatibleStore = try loadCompatibleStore(
            at: snapshot.workingStoreURL
        )
        _ = try sanitizeTransformableValues(
            at: snapshot.workingStoreURL,
            compatibleStore: compatibleStore
        )

        return try inspectProtectedData(
            at: snapshot.workingStoreURL,
            model: compatibleStore.model
        )
    }

    private func inspectProtectedData(
        at url: URL,
        model: NSManagedObjectModel
    ) throws -> ProtectedDataFootprint {
        do {
            return try inspectProtectedDataUnchecked(
                at: url,
                model: model
            )
        } catch let migrationError as SubstrateStorageMigrationError {
            throw migrationError
        } catch {
            throw SubstrateStorageMigrationError.sourceStoreInspectionFailed(
                storeURL,
                error
            )
        }
    }

    private func inspectProtectedDataUnchecked(
        at url: URL,
        model: NSManagedObjectModel
    ) throws -> ProtectedDataFootprint {
        var footprint: ProtectedDataFootprint?
        try performWithObjectiveCExceptionBoundary(
            operation: .protectedDataInspection
        ) {
            footprint = try self.inspectProtectedDataWithoutExceptionBoundary(
                at: url,
                model: model
            )
        }

        guard let footprint else {
            throw SubstrateProtectedDataInspectionError
                .countUnavailable("protected-data footprint")
        }
        return footprint
    }

    // Protected-data validation remains atomic.
    // swiftlint:disable:next function_body_length
    private func inspectProtectedDataWithoutExceptionBoundary(
        at url: URL,
        model: NSManagedObjectModel
    ) throws -> ProtectedDataFootprint {
        guard let chainEntity = model.entitiesByName["CDChain"] else {
            throw SubstrateProtectedDataInspectionError.entityUnavailable("CDChain")
        }
        guard model.entitiesByName["CDChainNode"] != nil else {
            throw SubstrateProtectedDataInspectionError.entityUnavailable("CDChainNode")
        }

        for relationshipName in ["nodes", "customNodes", "selectedNode"] {
            guard chainEntity.relationshipsByName[relationshipName] != nil else {
                throw SubstrateProtectedDataInspectionError.relationshipUnavailable(
                    "CDChain",
                    relationshipName
                )
            }
        }

        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let store = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: url,
            options: [
                NSReadOnlyPersistentStoreOption: true,
                NSMigratePersistentStoresAutomaticallyOption: false,
                NSInferMappingModelAutomaticallyOption: false
            ]
        )
        defer {
            try? coordinator.remove(store)
        }

        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator

        var result: Result<ProtectedDataFootprint, Error>?
        context.performAndWait {
            result = Result {
                let rowCounts = try self.protectedEntityRowCounts(
                    model: model,
                    context: context
                )
                var counts: [String: Int] = [
                    ProtectedDataCategory.contacts:
                        rowCounts[ProtectedDataCategory.contacts] ?? 0,
                    ProtectedDataCategory.contactItems:
                        rowCounts[ProtectedDataCategory.contactItems] ?? 0,
                    ProtectedDataCategory.transactionHistory:
                        rowCounts[
                            ProtectedDataCategory.transactionHistory
                        ] ?? 0
                ]

                var referencedNodeIDs = Set<NSManagedObjectID>()
                var customNodeRelationshipCount = 0
                var selectedNodeRelationshipCount = 0
                var totalRelationshipCount = 0

                try self.forEachManagedObjectPage(
                    entityName: "CDChain",
                    rowCount: rowCounts["CDChain"] ?? 0,
                    context: context
                ) { chains in
                    for chain in chains {
                        let defaultNodeCount = try self
                            .boundedRelationshipMemberCount(
                                inRelationship: "nodes",
                                of: chain
                            )
                        let customNodeCount = try self
                            .boundedRelationshipMemberCount(
                                inRelationship: "customNodes",
                                of: chain
                            )
                        try self.addRelationshipMembers(
                            defaultNodeCount,
                            to: &totalRelationshipCount
                        )
                        try self.addRelationshipMembers(
                            customNodeCount,
                            to: &totalRelationshipCount
                        )

                        let defaultNodes = try self
                            .boundedManagedObjects(
                                inRelationship: "nodes",
                                of: chain,
                                expectedMemberCount: defaultNodeCount
                            )
                        let customNodes = try self
                            .boundedManagedObjects(
                                inRelationship: "customNodes",
                                of: chain,
                                expectedMemberCount: customNodeCount
                            )
                        referencedNodeIDs.formUnion(
                            defaultNodes.map(\.objectID)
                        )
                        referencedNodeIDs.formUnion(
                            customNodes.map(\.objectID)
                        )
                        customNodeRelationshipCount +=
                            customNodes.count

                        if let selectedNode = chain.value(
                            forKey: "selectedNode"
                        ) as? NSManagedObject {
                            try self.addRelationshipMembers(
                                1,
                                to: &totalRelationshipCount
                            )
                            referencedNodeIDs.insert(
                                selectedNode.objectID
                            )
                            selectedNodeRelationshipCount += 1
                        }
                    }
                }

                var orphanNodeCount = 0
                try self.forEachManagedObjectPage(
                    entityName: "CDChainNode",
                    rowCount: rowCounts["CDChainNode"] ?? 0,
                    context: context
                ) { nodes in
                    for node in nodes where
                        !referencedNodeIDs.contains(node.objectID) {
                        orphanNodeCount += 1
                    }
                }

                counts[ProtectedDataCategory.customNodeRelationships] =
                    customNodeRelationshipCount
                counts[ProtectedDataCategory.selectedNodeRelationships] =
                    selectedNodeRelationshipCount
                counts[ProtectedDataCategory.orphanNodes] = orphanNodeCount

                return ProtectedDataFootprint(counts: counts)
            }
        }

        guard let result else {
            throw SubstrateProtectedDataInspectionError
                .countUnavailable("protected data footprint")
        }
        return try result.get()
    }

    private func protectedEntityRowCounts(
        model: NSManagedObjectModel,
        context: NSManagedObjectContext
    ) throws -> [String: Int] {
        let entityNames = [
            ProtectedDataCategory.contacts,
            ProtectedDataCategory.contactItems,
            ProtectedDataCategory.transactionHistory,
            "CDChain",
            "CDChainNode"
        ]
        var counts: [String: Int] = [:]
        var totalCount = 0

        for entityName in entityNames {
            let count = try countRowsIfPresent(
                entityName: entityName,
                model: model,
                context: context
            )
            guard
                count <= protectedDataInspectionLimits
                .maximumRowsPerEntity
            else {
                throw SubstrateProtectedDataInspectionError
                    .entityRowLimitExceeded(
                        entityName,
                        count,
                        protectedDataInspectionLimits
                            .maximumRowsPerEntity
                    )
            }

            let addition = totalCount.addingReportingOverflow(count)
            guard
                !addition.overflow,
                addition.partialValue <=
                protectedDataInspectionLimits.maximumTotalRows
            else {
                throw SubstrateProtectedDataInspectionError
                    .totalRowLimitExceeded(
                        addition.overflow
                            ? Int.max
                            : addition.partialValue,
                        protectedDataInspectionLimits.maximumTotalRows
                    )
            }
            totalCount = addition.partialValue
            counts[entityName] = count
        }

        return counts
    }

    private func countRowsIfPresent(
        entityName: String,
        model: NSManagedObjectModel,
        context: NSManagedObjectContext
    ) throws -> Int {
        guard model.entitiesByName[entityName] != nil else {
            return 0
        }

        let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        request.includesPendingChanges = false
        request.includesSubentities = false
        let count = try context.count(for: request)

        guard count != NSNotFound else {
            throw SubstrateProtectedDataInspectionError.countUnavailable(entityName)
        }

        return count
    }

    private func inspectVersion8StartupGraphBounds(
        at url: URL,
        model: NSManagedObjectModel
    ) throws {
        try performWithObjectiveCExceptionBoundary(
            operation: .protectedDataInspection
        ) {
            try self
                .inspectVersion8StartupGraphBoundsWithoutExceptionBoundary(
                    at: url,
                    model: model
                )
        }
    }

    // Graph bounds remain one fail-closed inspection.
    // swiftlint:disable:next function_body_length
    private func inspectVersion8StartupGraphBoundsWithoutExceptionBoundary(
        at url: URL,
        model: NSManagedObjectModel
    ) throws {
        for entityName in Self.version8StartupRootEntityNames {
            guard model.entitiesByName[entityName] != nil else {
                throw SubstrateProtectedDataInspectionError
                    .entityUnavailable(entityName)
            }
        }
        for entityName in Self.version8StartupChildEntityNames {
            guard model.entitiesByName[entityName] != nil else {
                throw SubstrateProtectedDataInspectionError
                    .entityUnavailable(entityName)
            }
        }
        for family in Self.version8StartupToManyRelationshipFamilies {
            guard let entity = model.entitiesByName[family.entityName] else {
                throw SubstrateProtectedDataInspectionError
                    .entityUnavailable(family.entityName)
            }
            for relationshipName in family.relationshipNames {
                guard
                    let relationship =
                    entity.relationshipsByName[relationshipName],
                    relationship.isToMany
                else {
                    throw SubstrateProtectedDataInspectionError
                        .relationshipUnavailable(
                            family.entityName,
                            relationshipName
                        )
                }
            }
        }

        try inspectVersion8StartupRootRawBounds(
            at: url,
            model: model
        )
        try inspectVersion8StartupChildRawBounds(
            at: url,
            model: model
        )

        let coordinator = NSPersistentStoreCoordinator(
            managedObjectModel: model
        )
        let store = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: url,
            options: [
                NSReadOnlyPersistentStoreOption: true,
                NSMigratePersistentStoresAutomaticallyOption: false,
                NSInferMappingModelAutomaticallyOption: false
            ]
        )
        defer {
            try? coordinator.remove(store)
        }

        let context = NSManagedObjectContext(
            concurrencyType: .privateQueueConcurrencyType
        )
        context.persistentStoreCoordinator = coordinator

        var result: Result<Void, Error>?
        context.performAndWait {
            result = Result {
                let rowCounts = try self.version8StartupEntityRowCounts(
                    context: context,
                    persistentStore: store
                )
                var totalRelationshipMemberCount = 0

                for family in
                    Self.version8StartupToManyRelationshipFamilies {
                    let objectIDs = try self
                        .version8StartupObjectIDs(
                            entityName: family.entityName,
                            rowCount:
                            rowCounts[family.entityName] ?? 0,
                            context: context,
                            persistentStore: store
                        )
                    var pageStart = 0
                    while pageStart < objectIDs.count {
                        let pageLength = min(
                            self.protectedDataInspectionLimits
                                .fetchPageSize,
                            objectIDs.count - pageStart
                        )
                        let pageEnd = pageStart + pageLength

                        do {
                            for objectID in
                                objectIDs[pageStart ..< pageEnd] {
                                let object = context.object(
                                    with: objectID
                                )
                                for relationshipName in
                                    family.relationshipNames {
                                    let memberCount = try self
                                        .boundedRelationshipMemberCount(
                                            inRelationship:
                                            relationshipName,
                                            of: object
                                        )
                                    try self.addRelationshipMembers(
                                        memberCount,
                                        to:
                                        &totalRelationshipMemberCount
                                    )
                                }
                            }
                        } catch {
                            context.reset()
                            throw error
                        }

                        pageStart = pageEnd
                        context.reset()
                    }
                }

                return ()
            }
        }

        guard let result else {
            throw SubstrateProtectedDataInspectionError
                .countUnavailable("v8 startup graph")
        }
        try result.get()
    }

    // Raw root bounds remain one fail-closed inspection.
    // swiftlint:disable:next function_body_length
    private func inspectVersion8StartupRootRawBounds(
        at url: URL,
        model: NSManagedObjectModel
    ) throws {
        var database: OpaquePointer?
        let openResult = sqlite3_open_v2(
            url.path,
            &database,
            SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX,
            nil
        )
        guard openResult == SQLITE_OK, let database else {
            if let database {
                sqlite3_close_v2(database)
            }
            throw SubstrateProtectedDataInspectionError
                .countUnavailable("v8 startup roots")
        }
        defer {
            sqlite3_close_v2(database)
        }

        var aggregatePayloadByteCount: UInt64 = 0
        for entityName in Self.version8StartupRootEntityNames.sorted() {
            guard let entity = model.entitiesByName[entityName] else {
                throw SubstrateProtectedDataInspectionError
                    .entityUnavailable(entityName)
            }
            let tableName = try version8PhysicalIdentifier(
                entityName
            )
            let columnNames = try entity.attributesByName.values
                .sorted { $0.name < $1.name }
                .map {
                    try version8PhysicalIdentifier($0.name)
                }
            guard !columnNames.isEmpty else {
                throw SubstrateProtectedDataInspectionError
                    .countUnavailable(entityName)
            }

            let payloadExpressions = columnNames.map {
                """
                COALESCE(length(CAST("\($0)" AS BLOB)), 0)
                """
            }.joined(separator: ", ")
            let sql = """
            SELECT \(payloadExpressions)
            FROM "\(tableName)"
            """
            var statement: OpaquePointer?
            guard
                sqlite3_prepare_v2(
                    database,
                    sql,
                    -1,
                    &statement,
                    nil
                ) == SQLITE_OK,
                let statement
            else {
                if let statement {
                    sqlite3_finalize(statement)
                }
                throw SubstrateProtectedDataInspectionError
                    .countUnavailable(entityName)
            }
            defer {
                sqlite3_finalize(statement)
            }

            var rowCount = 0
            while true {
                let stepResult = sqlite3_step(statement)
                if stepResult == SQLITE_DONE {
                    break
                }
                guard stepResult == SQLITE_ROW else {
                    throw SubstrateProtectedDataInspectionError
                        .countUnavailable(entityName)
                }

                let rowAddition = rowCount.addingReportingOverflow(1)
                guard
                    !rowAddition.overflow,
                    rowAddition.partialValue <=
                    protectedDataInspectionLimits
                    .maximumStartupRootRowsPerEntity
                else {
                    throw SubstrateProtectedDataInspectionError
                        .entityRowLimitExceeded(
                            entityName,
                            rowAddition.overflow
                                ? Int.max
                                : rowAddition.partialValue,
                            protectedDataInspectionLimits
                                .maximumStartupRootRowsPerEntity
                        )
                }
                rowCount = rowAddition.partialValue

                for columnIndex in 0 ..< columnNames.count {
                    guard
                        sqlite3_column_type(
                            statement,
                            Int32(columnIndex)
                        ) == SQLITE_INTEGER
                    else {
                        throw SubstrateProtectedDataInspectionError
                            .countUnavailable(entityName)
                    }
                    let signedByteCount = sqlite3_column_int64(
                        statement,
                        Int32(columnIndex)
                    )
                    guard signedByteCount >= 0 else {
                        throw SubstrateProtectedDataInspectionError
                            .countUnavailable(entityName)
                    }

                    let addition = aggregatePayloadByteCount
                        .addingReportingOverflow(
                            UInt64(signedByteCount)
                        )
                    guard
                        !addition.overflow,
                        addition.partialValue <=
                        protectedDataInspectionLimits
                        .maximumStartupRootPayloadByteCount
                    else {
                        throw SubstrateProtectedDataInspectionError
                            .startupRootPayloadByteLimitExceeded(
                                addition.overflow
                                    ? UInt64.max
                                    : addition.partialValue,
                                protectedDataInspectionLimits
                                    .maximumStartupRootPayloadByteCount
                            )
                    }
                    aggregatePayloadByteCount =
                        addition.partialValue
                }
            }
        }
    }

    // Raw child bounds remain one fail-closed inspection.
    // swiftlint:disable:next function_body_length
    private func inspectVersion8StartupChildRawBounds(
        at url: URL,
        model: NSManagedObjectModel
    ) throws {
        var database: OpaquePointer?
        let openResult = sqlite3_open_v2(
            url.path,
            &database,
            SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX,
            nil
        )
        guard openResult == SQLITE_OK, let database else {
            if let database {
                sqlite3_close_v2(database)
            }
            throw SubstrateProtectedDataInspectionError
                .countUnavailable("v8 startup children")
        }
        defer {
            sqlite3_close_v2(database)
        }

        var totalRowCount = 0
        var aggregatePayloadByteCount: UInt64 = 0

        for entityName in Self.version8StartupChildEntityNames.sorted() {
            guard let entity = model.entitiesByName[entityName] else {
                throw SubstrateProtectedDataInspectionError
                    .entityUnavailable(entityName)
            }
            let tableName = try version8PhysicalIdentifier(
                entityName
            )
            let attributes = try entity.attributesByName.values
                .sorted { $0.name < $1.name }
                .map {
                    (
                        name: $0.name,
                        columnName: try version8PhysicalIdentifier(
                            $0.name
                        )
                    )
                }
            guard !attributes.isEmpty else {
                throw SubstrateProtectedDataInspectionError
                    .countUnavailable(entityName)
            }

            let payloadExpressions = attributes.map {
                """
                COALESCE(length(CAST("\($0.columnName)" AS BLOB)), 0)
                """
            }.joined(separator: ", ")
            let sql = """
            SELECT \(payloadExpressions)
            FROM "\(tableName)"
            """
            var statement: OpaquePointer?
            guard
                sqlite3_prepare_v2(
                    database,
                    sql,
                    -1,
                    &statement,
                    nil
                ) == SQLITE_OK,
                let statement
            else {
                if let statement {
                    sqlite3_finalize(statement)
                }
                throw SubstrateProtectedDataInspectionError
                    .countUnavailable(entityName)
            }

            do {
                defer {
                    sqlite3_finalize(statement)
                }

                var entityRowCount = 0
                while true {
                    let stepResult = sqlite3_step(statement)
                    if stepResult == SQLITE_DONE {
                        break
                    }
                    guard stepResult == SQLITE_ROW else {
                        throw SubstrateProtectedDataInspectionError
                            .countUnavailable(entityName)
                    }

                    let entityRowAddition =
                        entityRowCount.addingReportingOverflow(1)
                    guard
                        !entityRowAddition.overflow,
                        entityRowAddition.partialValue <=
                        protectedDataInspectionLimits
                        .maximumRowsPerEntity
                    else {
                        throw SubstrateProtectedDataInspectionError
                            .entityRowLimitExceeded(
                                entityName,
                                entityRowAddition.overflow
                                    ? Int.max
                                    : entityRowAddition.partialValue,
                                protectedDataInspectionLimits
                                    .maximumRowsPerEntity
                            )
                    }
                    entityRowCount =
                        entityRowAddition.partialValue

                    let totalRowAddition =
                        totalRowCount.addingReportingOverflow(1)
                    guard
                        !totalRowAddition.overflow,
                        totalRowAddition.partialValue <=
                        protectedDataInspectionLimits
                        .maximumTotalRows
                    else {
                        throw SubstrateProtectedDataInspectionError
                            .totalRowLimitExceeded(
                                totalRowAddition.overflow
                                    ? Int.max
                                    : totalRowAddition.partialValue,
                                protectedDataInspectionLimits
                                    .maximumTotalRows
                            )
                    }
                    totalRowCount = totalRowAddition.partialValue

                    for (
                        columnIndex,
                        attribute
                    ) in attributes.enumerated() {
                            guard
                                sqlite3_column_type(
                                    statement,
                                    Int32(columnIndex)
                                ) == SQLITE_INTEGER
                            else {
                                throw SubstrateProtectedDataInspectionError
                                    .countUnavailable(entityName)
                            }
                            let signedByteCount = sqlite3_column_int64(
                                statement,
                                Int32(columnIndex)
                            )
                            guard signedByteCount >= 0 else {
                                throw SubstrateProtectedDataInspectionError
                                    .countUnavailable(entityName)
                            }
                            let valueByteCount = UInt64(
                                signedByteCount
                            )

                            guard
                                valueByteCount <=
                                protectedDataInspectionLimits
                                .maximumStartupChildValueByteCount
                            else {
                                throw SubstrateProtectedDataInspectionError
                                    .startupChildValueByteLimitExceeded(
                                        entityName,
                                        attribute.name,
                                        valueByteCount,
                                        protectedDataInspectionLimits
                                            .maximumStartupChildValueByteCount
                                    )
                            }

                            let aggregateAddition =
                                aggregatePayloadByteCount
                                    .addingReportingOverflow(
                                        valueByteCount
                                    )
                            guard
                                !aggregateAddition.overflow,
                                aggregateAddition.partialValue <=
                                protectedDataInspectionLimits
                                .maximumStartupChildPayloadByteCount
                            else {
                                throw SubstrateProtectedDataInspectionError
                                    .startupChildPayloadByteLimitExceeded(
                                        aggregateAddition.overflow
                                            ? UInt64.max
                                            : aggregateAddition.partialValue,
                                        protectedDataInspectionLimits
                                            .maximumStartupChildPayloadByteCount
                                    )
                            }
                            aggregatePayloadByteCount =
                                aggregateAddition.partialValue
                        }
                }
            }
        }
    }

    private func version8PhysicalIdentifier(
        _ logicalName: String
    ) throws -> String {
        guard
            !logicalName.isEmpty,
            logicalName.unicodeScalars.allSatisfy({
                (0x30 ... 0x39).contains($0.value) ||
                    (0x41 ... 0x5A).contains($0.value) ||
                    (0x61 ... 0x7A).contains($0.value) ||
                    $0.value == 0x5F
            })
        else {
            throw SubstrateProtectedDataInspectionError
                .countUnavailable("v8 startup schema")
        }

        return "Z\(logicalName.uppercased())"
    }

    private func version8StartupEntityRowCounts(
        context: NSManagedObjectContext,
        persistentStore: NSPersistentStore
    ) throws -> [String: Int] {
        let entityNames = Set(
            Self.version8StartupRootEntityNames +
                Self.version8StartupToManyRelationshipFamilies.map(
                    \.entityName
                )
        )
        var rowCounts = [String: Int]()
        var totalRowCount = 0

        for entityName in entityNames.sorted() {
            let request = NSFetchRequest<NSFetchRequestResult>(
                entityName: entityName
            )
            request.includesPendingChanges = false
            request.includesSubentities = false
            request.affectedStores = [persistentStore]
            let rowCount = try context.count(for: request)
            guard rowCount != NSNotFound else {
                throw SubstrateProtectedDataInspectionError
                    .countUnavailable(entityName)
            }
            guard
                rowCount <=
                protectedDataInspectionLimits.maximumRowsPerEntity
            else {
                throw SubstrateProtectedDataInspectionError
                    .entityRowLimitExceeded(
                        entityName,
                        rowCount,
                        protectedDataInspectionLimits
                            .maximumRowsPerEntity
                    )
            }

            let addition = totalRowCount.addingReportingOverflow(
                rowCount
            )
            guard
                !addition.overflow,
                addition.partialValue <=
                protectedDataInspectionLimits.maximumTotalRows
            else {
                throw SubstrateProtectedDataInspectionError
                    .totalRowLimitExceeded(
                        addition.overflow
                            ? Int.max
                            : addition.partialValue,
                        protectedDataInspectionLimits.maximumTotalRows
                    )
            }
            totalRowCount = addition.partialValue
            rowCounts[entityName] = rowCount
        }

        return rowCounts
    }

    private func version8StartupObjectIDs(
        entityName: String,
        rowCount: Int,
        context: NSManagedObjectContext,
        persistentStore: NSPersistentStore
    ) throws -> [NSManagedObjectID] {
        guard rowCount > 0 else {
            return []
        }
        guard rowCount < Int.max else {
            throw SubstrateProtectedDataInspectionError
                .countUnavailable(entityName)
        }

        let request = NSFetchRequest<NSFetchRequestResult>(
            entityName: entityName
        )
        request.resultType = .managedObjectIDResultType
        request.includesPendingChanges = false
        request.includesSubentities = false
        request.affectedStores = [persistentStore]
        request.fetchLimit = rowCount + 1
        request.fetchBatchSize = min(
            protectedDataInspectionLimits.fetchPageSize,
            rowCount + 1
        )

        let fetchedResults = try context.fetch(request)
        let objectIDs = fetchedResults.compactMap {
            $0 as? NSManagedObjectID
        }
        guard
            objectIDs.count == fetchedResults.count,
            objectIDs.count == rowCount,
            Set(objectIDs).count == rowCount,
            objectIDs.allSatisfy({
                $0.persistentStore === persistentStore
            })
        else {
            throw SubstrateProtectedDataInspectionError
                .countUnavailable(entityName)
        }

        return objectIDs
    }

    private func forEachManagedObjectPage(
        entityName: String,
        rowCount: Int,
        context: NSManagedObjectContext,
        _ operation: ([NSManagedObject]) throws -> Void
    ) throws {
        guard rowCount > 0 else {
            return
        }

        // Materialize the capped ID list once for exact-once enumeration;
        // managed objects and their values are hydrated only one page at a
        // time below.
        let identifierRequest =
            NSFetchRequest<NSFetchRequestResult>(
                entityName: entityName
            )
        identifierRequest.resultType = .managedObjectIDResultType
        identifierRequest.includesPendingChanges = false
        identifierRequest.includesSubentities = false
        let objectIDs = try context.fetch(identifierRequest)
            .compactMap { $0 as? NSManagedObjectID }
        guard
            objectIDs.count == rowCount,
            Set(objectIDs).count == rowCount
        else {
            throw SubstrateProtectedDataInspectionError
                .countUnavailable(entityName)
        }

        var pageStart = 0
        while pageStart < objectIDs.count {
            let pageEnd = min(
                pageStart +
                    protectedDataInspectionLimits.fetchPageSize,
                objectIDs.count
            )
            let pageObjectIDs = Array(
                objectIDs[pageStart ..< pageEnd]
            )
            do {
                try autoreleasepool {
                    let request = NSFetchRequest<NSManagedObject>(
                        entityName: entityName
                    )
                    request.includesPendingChanges = false
                    request.includesSubentities = false
                    request.predicate = NSPredicate(
                        format: "SELF IN %@",
                        pageObjectIDs
                    )
                    request.fetchLimit = pageObjectIDs.count
                    request.fetchBatchSize = pageObjectIDs.count

                    let page = try context.fetch(request)
                    guard
                        page.count == pageObjectIDs.count,
                        Set(page.map(\.objectID)) ==
                        Set(pageObjectIDs)
                    else {
                        throw SubstrateProtectedDataInspectionError
                            .countUnavailable(entityName)
                    }
                    try operation(page)
                }
            } catch {
                context.reset()
                throw error
            }
            pageStart = pageEnd
            context.reset()
        }
    }

    private func boundedRelationshipMemberCount(
        inRelationship relationshipName: String,
        of object: NSManagedObject
    ) throws -> Int {
        let entityName = object.entity.name ?? "unknown"
        guard
            let relationship =
            object.entity.relationshipsByName[relationshipName],
            relationship.isToMany,
            let context = object.managedObjectContext,
            !object.objectID.isTemporaryID,
            let persistentStore = object.objectID.persistentStore
        else {
            throw SubstrateProtectedDataInspectionError
                .relationshipCountUnavailable(
                    entityName,
                    relationshipName
                )
        }

        let countKey = "__fearlessRelationshipMemberCount"
        let countDescription = NSExpressionDescription()
        countDescription.name = countKey
        countDescription.expression = NSExpression(
            forFunction: "count:",
            arguments: [
                NSExpression(forKeyPath: relationshipName)
            ]
        )
        countDescription.expressionResultType =
            .integer64AttributeType

        let request = NSFetchRequest<NSDictionary>(
            entityName: entityName
        )
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = [countDescription]
        request.predicate = NSPredicate(
            format: "SELF == %@",
            object.objectID
        )
        request.includesPendingChanges = false
        request.includesSubentities = false
        request.affectedStores = [persistentStore]
        request.fetchLimit = 2

        let rows = try context.fetch(request)
        guard
            rows.count == 1,
            let number = rows[0][countKey] as? NSNumber
        else {
            throw SubstrateProtectedDataInspectionError
                .relationshipCountUnavailable(
                    entityName,
                    relationshipName
                )
        }

        let count = number.int64Value
        guard
            count >= 0,
            UInt64(count) <= UInt64(Int.max)
        else {
            throw SubstrateProtectedDataInspectionError
                .relationshipCountUnavailable(
                    entityName,
                    relationshipName
                )
        }
        let memberCount = Int(count)

        protectedRelationshipCountDidFetch(
            object,
            relationshipName,
            memberCount
        )

        guard
            memberCount <= protectedDataInspectionLimits
            .maximumRelationshipMembers
        else {
            throw SubstrateProtectedDataInspectionError
                .relationshipLimitExceeded(
                    entityName,
                    relationshipName,
                    memberCount,
                    protectedDataInspectionLimits
                        .maximumRelationshipMembers
                )
        }

        return memberCount
    }

    private func boundedManagedObjects(
        inRelationship relationshipName: String,
        of object: NSManagedObject,
        expectedMemberCount: Int
    ) throws -> [NSManagedObject] {
        let entityName = object.entity.name ?? "unknown"

        // The SQL-backed count and both the per-relationship and aggregate
        // caps have succeeded before this is called. KVC may fire the
        // relationship only after every allocation is therefore bounded.
        protectedRelationshipWillMaterialize(
            entityName,
            relationshipName,
            expectedMemberCount
        )

        guard let value = object.value(forKey: relationshipName) else {
            guard expectedMemberCount == 0 else {
                throw SubstrateProtectedDataInspectionError
                    .relationshipValueInvalid(
                        entityName,
                        relationshipName
                    )
            }
            return []
        }
        guard
            let objects = value as? NSSet,
            objects.count == expectedMemberCount
        else {
            throw SubstrateProtectedDataInspectionError
                .relationshipValueInvalid(
                    entityName,
                    relationshipName
                )
        }

        var managedObjects = [NSManagedObject]()
        managedObjects.reserveCapacity(expectedMemberCount)
        for member in objects {
            guard let managedObject = member as? NSManagedObject else {
                throw SubstrateProtectedDataInspectionError
                    .relationshipValueInvalid(
                        entityName,
                        relationshipName
                    )
            }
            managedObjects.append(managedObject)
        }
        guard managedObjects.count == expectedMemberCount else {
            throw SubstrateProtectedDataInspectionError
                .relationshipValueInvalid(
                    entityName,
                    relationshipName
                )
        }

        return managedObjects
    }

    private func addRelationshipMembers(
        _ count: Int,
        to totalCount: inout Int
    ) throws {
        let addition = totalCount.addingReportingOverflow(count)
        guard
            !addition.overflow,
            addition.partialValue <= protectedDataInspectionLimits
            .maximumTotalRelationshipMembers
        else {
            throw SubstrateProtectedDataInspectionError
                .totalRelationshipLimitExceeded(
                    addition.overflow ? Int.max : addition.partialValue,
                    protectedDataInspectionLimits
                        .maximumTotalRelationshipMembers
                )
        }
        totalCount = addition.partialValue
    }

    private func inspectProtectedDataSnapshot(
        at url: URL,
        model: NSManagedObjectModel,
        normalizingMissingSelectedNode: Bool = false
    ) throws -> ProtectedDataSnapshot {
        var snapshot: ProtectedDataSnapshot?
        try performWithObjectiveCExceptionBoundary(
            operation: .protectedDataInspection
        ) {
            snapshot = try self
                .inspectProtectedDataSnapshotWithoutExceptionBoundary(
                    at: url,
                    model: model,
                    normalizingMissingSelectedNode:
                    normalizingMissingSelectedNode
                )
        }

        guard let snapshot else {
            throw SubstrateProtectedDataInspectionError
                .countUnavailable("protected-data snapshot")
        }
        return snapshot
    }

    // Snapshot validation remains one atomic inspection.
    // swiftlint:disable:next function_body_length
    private func inspectProtectedDataSnapshotWithoutExceptionBoundary(
        at url: URL,
        model: NSManagedObjectModel,
        normalizingMissingSelectedNode: Bool
    ) throws -> ProtectedDataSnapshot {
        let coordinator = NSPersistentStoreCoordinator(
            managedObjectModel: model
        )
        let store = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: url,
            options: [
                NSReadOnlyPersistentStoreOption: true,
                NSMigratePersistentStoresAutomaticallyOption: false,
                NSInferMappingModelAutomaticallyOption: false
            ]
        )
        defer {
            try? coordinator.remove(store)
        }

        let context = NSManagedObjectContext(
            concurrencyType: .privateQueueConcurrencyType
        )
        context.persistentStoreCoordinator = coordinator

        var result: Result<ProtectedDataSnapshot, Error>?
        context.performAndWait {
            result = Result {
                let rowCounts = try self.protectedEntityRowCounts(
                    model: model,
                    context: context
                )
                let contacts = try self.semanticDigest(
                    entityName: "CDContact",
                    attributeNames: [
                        "address",
                        "chainId",
                        "name"
                    ],
                    model: model,
                    context: context,
                    rowCount: rowCounts["CDContact"] ?? 0
                )
                let contactItems = try self.semanticDigest(
                    entityName: "CDContactItem",
                    attributeNames: [
                        "identifier",
                        "peerAddress",
                        "peerName",
                        "targetAddress",
                        "updatedAt"
                    ],
                    model: model,
                    context: context,
                    rowCount: rowCounts["CDContactItem"] ?? 0
                )
                let transactionHistory = try self.semanticDigest(
                    entityName: "CDTransactionHistoryItem",
                    attributeNames: [
                        "blockNumber",
                        "call",
                        "callName",
                        "fee",
                        "identifier",
                        "moduleName",
                        "receiver",
                        "sender",
                        "status",
                        "timestamp",
                        "txIndex"
                    ],
                    model: model,
                    context: context,
                    rowCount:
                    rowCounts["CDTransactionHistoryItem"] ?? 0
                )

                guard let chainEntity =
                    model.entitiesByName["CDChain"] else {
                    throw SubstrateProtectedDataInspectionError
                        .entityUnavailable("CDChain")
                }
                guard model.entitiesByName["CDChainNode"] != nil else {
                    throw SubstrateProtectedDataInspectionError
                        .entityUnavailable("CDChainNode")
                }

                for relationshipName in [
                    "nodes",
                    "customNodes",
                    "selectedNode"
                ] {
                    guard
                        chainEntity.relationshipsByName[
                            relationshipName
                        ] != nil
                    else {
                        throw SubstrateProtectedDataInspectionError
                            .relationshipUnavailable(
                                "CDChain",
                                relationshipName
                            )
                    }
                }

                let nodeAttributeNames = [
                    "apiKeyName",
                    "apiQueryName",
                    "name",
                    "url"
                ]
                var referencedNodeIDs = Set<NSManagedObjectID>()
                var topologyAccumulator =
                    ProtectedDataDigestAccumulator()
                var totalRelationshipCount = 0

                try self.forEachManagedObjectPage(
                    entityName: "CDChain",
                    rowCount: rowCounts["CDChain"] ?? 0,
                    context: context
                ) { chains in
                    for chain in chains {
                        let defaultNodeCount = try self
                            .boundedRelationshipMemberCount(
                                inRelationship: "nodes",
                                of: chain
                            )
                        let customNodeCount = try self
                            .boundedRelationshipMemberCount(
                                inRelationship: "customNodes",
                                of: chain
                            )
                        try self.addRelationshipMembers(
                            defaultNodeCount,
                            to: &totalRelationshipCount
                        )
                        try self.addRelationshipMembers(
                            customNodeCount,
                            to: &totalRelationshipCount
                        )

                        let defaultNodes = try self
                            .boundedManagedObjects(
                                inRelationship: "nodes",
                                of: chain,
                                expectedMemberCount: defaultNodeCount
                            )
                        let customNodes = try self
                            .boundedManagedObjects(
                                inRelationship: "customNodes",
                                of: chain,
                                expectedMemberCount: customNodeCount
                            )

                        let defaultNodeDigest = try self
                            .semanticDigest(
                                objects: defaultNodes,
                                attributeNames: nodeAttributeNames,
                                category: "CDChain.nodes"
                            )
                        let customNodeDigest = try self
                            .semanticDigest(
                                objects: customNodes,
                                attributeNames: nodeAttributeNames,
                                category: "CDChain.customNodes"
                            )
                        let storedSelectedNode = chain.value(
                            forKey: "selectedNode"
                        ) as? NSManagedObject
                        let selectedNode: NSManagedObject?
                        if let storedSelectedNode {
                            selectedNode = storedSelectedNode
                        } else if normalizingMissingSelectedNode {
                            selectedNode = try self
                                .stableSemanticMinimum(
                                    defaultNodes,
                                    attributeNames:
                                    nodeAttributeNames
                                )
                        } else {
                            selectedNode = nil
                        }
                        if selectedNode != nil {
                            try self.addRelationshipMembers(
                                1,
                                to: &totalRelationshipCount
                            )
                        }
                        let selectedNodeDigest = try self
                            .semanticDigest(
                                objects: selectedNode.map { [$0] } ?? [],
                                attributeNames: nodeAttributeNames,
                                category: "CDChain.selectedNode"
                            )

                        referencedNodeIDs.formUnion(
                            defaultNodes.map(\.objectID)
                        )
                        referencedNodeIDs.formUnion(
                            customNodes.map(\.objectID)
                        )
                        if let selectedNode {
                            referencedNodeIDs.insert(
                                selectedNode.objectID
                            )
                        }

                        let chainIdentifier = try self
                            .canonicalAttributeValue(
                                in: chain,
                                key: "chainId"
                            )
                        let topology = [
                            "chain=\(chainIdentifier)",
                            """
                            nodes=\(self.canonicalDigest(defaultNodeDigest))
                            """,
                            """
                            custom=\(self.canonicalDigest(customNodeDigest))
                            """,
                            """
                            selected=\(self.canonicalDigest(selectedNodeDigest))
                            """
                        ].joined(separator: ";")
                        try topologyAccumulator.append(
                            topology,
                            category: "CDChain.topology",
                            maximumByteCount:
                            self.protectedDataInspectionLimits
                                .maximumRecordByteCount
                        )
                    }
                }

                var orphanNodeAccumulator =
                    ProtectedDataDigestAccumulator()
                try self.forEachManagedObjectPage(
                    entityName: "CDChainNode",
                    rowCount: rowCounts["CDChainNode"] ?? 0,
                    context: context
                ) { nodes in
                    for node in nodes where
                        !referencedNodeIDs.contains(node.objectID) {
                        let record = try self.canonicalRecord(
                            for: node,
                            attributeNames: nodeAttributeNames
                        )
                        try orphanNodeAccumulator.append(
                            record,
                            category: "CDChainNode.orphan",
                            maximumByteCount:
                            self.protectedDataInspectionLimits
                                .maximumRecordByteCount
                        )
                    }
                }

                return ProtectedDataSnapshot(
                    contacts: contacts,
                    contactItems: contactItems,
                    transactionHistory: transactionHistory,
                    chainNodeTopologies:
                    topologyAccumulator.finalize(),
                    orphanNodes: orphanNodeAccumulator.finalize()
                )
            }
        }

        guard let result else {
            throw SubstrateProtectedDataInspectionError
                .countUnavailable("protected data snapshot")
        }
        return try result.get()
    }

    private func stableSemanticMinimum(
        _ objects: [NSManagedObject],
        attributeNames: [String]
    ) throws -> NSManagedObject? {
        var selected: (
            record: String,
            objectID: String,
            object: NSManagedObject
        )?

        for object in objects {
            let candidate = (
                record: try canonicalRecord(
                    for: object,
                    attributeNames: attributeNames
                ),
                objectID: object.objectID
                    .uriRepresentation().absoluteString,
                object: object
            )
            guard let currentSelection = selected else {
                selected = candidate
                continue
            }
            if
                candidate.record < currentSelection.record ||
                (
                    candidate.record ==
                        currentSelection.record &&
                        candidate.objectID <
                        currentSelection.objectID
                ) {
                selected = candidate
            }
        }

        return selected?.object
    }

    private func semanticDigest(
        entityName: String,
        attributeNames: [String],
        model: NSManagedObjectModel,
        context: NSManagedObjectContext,
        rowCount: Int
    ) throws -> ProtectedDataDigest {
        guard model.entitiesByName[entityName] != nil else {
            return ProtectedDataDigestAccumulator().finalize()
        }

        var accumulator = ProtectedDataDigestAccumulator()
        try forEachManagedObjectPage(
            entityName: entityName,
            rowCount: rowCount,
            context: context
        ) { objects in
            for object in objects {
                let record = try self.canonicalRecord(
                    for: object,
                    attributeNames: attributeNames
                )
                try accumulator.append(
                    record,
                    category: entityName,
                    maximumByteCount:
                    self.protectedDataInspectionLimits
                        .maximumRecordByteCount
                )
            }
        }

        return accumulator.finalize()
    }

    private func semanticDigest(
        objects: [NSManagedObject],
        attributeNames: [String],
        category: String
    ) throws -> ProtectedDataDigest {
        var accumulator = ProtectedDataDigestAccumulator()
        for object in objects {
            let record = try canonicalRecord(
                for: object,
                attributeNames: attributeNames
            )
            try accumulator.append(
                record,
                category: category,
                maximumByteCount: protectedDataInspectionLimits
                    .maximumRecordByteCount
            )
        }

        return accumulator.finalize()
    }

    private func canonicalRecord(
        for object: NSManagedObject,
        attributeNames: [String]
    ) throws -> String {
        try attributeNames.compactMap { key in
            guard object.entity.attributesByName[key] != nil else {
                return nil
            }

            return """
            \(key)=\(try canonicalAttributeValue(in: object, key: key))
            """
        }
        .joined(separator: "|")
    }

    private func canonicalAttributeValue(
        in object: NSManagedObject,
        key: String
    ) throws -> String {
        guard object.entity.attributesByName[key] != nil else {
            return "absent"
        }

        guard let value = object.value(forKey: key) else {
            return "nil"
        }

        switch value {
        case let string as String:
            try requireValueByteLimit(
                Data(string.utf8).count,
                object: object,
                key: key
            )
            return "string:\(canonicalString(string))"
        case let url as URL:
            let absoluteString = url.absoluteString
            try requireValueByteLimit(
                Data(absoluteString.utf8).count,
                object: object,
                key: key
            )
            return "url:\(canonicalString(absoluteString))"
        case let data as Data:
            try requireValueByteLimit(
                data.count,
                object: object,
                key: key
            )
            return "data:\(data.base64EncodedString())"
        case let date as Date:
            return "date:\(date.timeIntervalSinceReferenceDate.bitPattern)"
        case let decimal as NSDecimalNumber:
            let stringValue = decimal.stringValue
            try requireValueByteLimit(
                Data(stringValue.utf8).count,
                object: object,
                key: key
            )
            return "decimal:\(canonicalString(stringValue))"
        case let number as NSNumber:
            let stringValue = number.stringValue
            try requireValueByteLimit(
                Data(stringValue.utf8).count,
                object: object,
                key: key
            )
            return """
            number:\(String(cString: number.objCType)):\(canonicalString(stringValue))
            """
        default:
            let className = NSStringFromClass(
                type(of: value as AnyObject)
            )
            throw SubstrateProtectedDataInspectionError
                .unsupportedAttributeValue(
                    object.entity.name ?? "unknown",
                    key,
                    className
                )
        }
    }

    private func requireValueByteLimit(
        _ byteCount: Int,
        object: NSManagedObject,
        key: String
    ) throws {
        guard
            byteCount <=
            protectedDataInspectionLimits.maximumValueByteCount
        else {
            throw SubstrateProtectedDataInspectionError
                .valueByteLimitExceeded(
                    object.entity.name ?? "unknown",
                    key,
                    byteCount,
                    protectedDataInspectionLimits
                        .maximumValueByteCount
                )
        }
    }

    private func canonicalDigest(
        _ digest: ProtectedDataDigest
    ) -> String {
        let words = digest.additiveWords.map {
            String(format: "%016llx", $0)
        }.joined(separator: ",")
        return "\(digest.recordCount):\(words)"
    }

    private func canonicalString(_ value: String) -> String {
        Data(value.utf8).base64EncodedString()
    }

    private func inspectStoreRowCounts(
        at url: URL,
        model: NSManagedObjectModel,
        entityNames: Set<String>,
        operation: SubstrateStorageMigrationOperation
    ) throws -> [String: Int] {
        var counts: [String: Int]?
        try performWithObjectiveCExceptionBoundary(operation: operation) {
            counts = try self.inspectStoreRowCountsWithoutExceptionBoundary(
                at: url,
                model: model,
                entityNames: entityNames
            )
        }

        guard let counts else {
            throw SubstrateProtectedDataInspectionError
                .countUnavailable("store row counts")
        }
        return counts
    }

    private func inspectStoreRowCountsWithoutExceptionBoundary(
        at url: URL,
        model: NSManagedObjectModel,
        entityNames: Set<String>
    ) throws -> [String: Int] {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let store = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: url,
            options: [
                NSReadOnlyPersistentStoreOption: true,
                NSMigratePersistentStoresAutomaticallyOption: false,
                NSInferMappingModelAutomaticallyOption: false
            ]
        )
        defer {
            try? coordinator.remove(store)
        }

        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator

        var result: Result<[String: Int], Error>?
        context.performAndWait {
            result = Result {
                var counts: [String: Int] = [:]

                for entityName in entityNames.sorted() {
                    let request = NSFetchRequest<NSFetchRequestResult>(
                        entityName: entityName
                    )
                    counts[entityName] = try context.count(for: request)
                }

                return counts
            }
        }

        guard let result else {
            throw SubstrateProtectedDataInspectionError
                .countUnavailable("store row counts")
        }
        return try result.get()
    }

    private func checkIfMigrationNeeded(to version: SubstrateStorageVersion) -> Bool {
        if crashConsistentCacheRecovery.hasPendingTransaction {
            return true
        }

        if crashConsistentStoreReplacer.hasPendingTransaction {
            return true
        }

        do {
            guard try crashConsistentStoreReplacer.liveStoreExistsSafely() else {
                return false
            }
        } catch {
            return true
        }

        do {
            let snapshot = try createPrivateSourceSnapshot()
            defer {
                try? fileManager.removeItem(at: snapshot.rootURL)
            }
            let compatibleStore = try loadCompatibleStore(
                at: snapshot.workingStoreURL
            )

            guard compatibleStore.version == version else {
                return true
            }

            let repairedTransformableValueCount =
                try sanitizeTransformableValues(
                    at: snapshot.workingStoreURL,
                    compatibleStore: compatibleStore
                )

            if compatibleStore.version == .version8 {
                try inspectVersion8StartupGraphBounds(
                    at: snapshot.workingStoreURL,
                    model: compatibleStore.model
                )
                _ = try inspectProtectedDataSnapshot(
                    at: snapshot.workingStoreURL,
                    model: compatibleStore.model
                )
            }

            return repairedTransformableValueCount > 0
        } catch {
            return true
        }
    }

    private func loadCompatibleStore(at url: URL) throws -> CompatibleStore {
        let metadata: [String: Any]
        do {
            var inspectedMetadata: [String: Any]?
            try performWithObjectiveCExceptionBoundary(
                operation: .sourceMetadata
            ) {
                inspectedMetadata = try NSPersistentStoreCoordinator
                    .metadataForPersistentStore(
                        ofType: NSSQLiteStoreType,
                        at: url,
                        options: nil
                    )
            }
            metadata = inspectedMetadata ?? [:]
        } catch let migrationError as SubstrateStorageMigrationError {
            throw migrationError
        } catch {
            throw SubstrateStorageMigrationError.metadataUnreadable(storeURL, error)
        }

        guard let compatibleStore = try compatibleStore(for: metadata) else {
            throw SubstrateStorageMigrationError.unknownStoreVersion(storeURL)
        }

        return compatibleStore
    }

    private func compatibleStore(
        for metadata: [String: Any]
    ) throws -> CompatibleStore? {
        for version in SubstrateStorageVersion.allCases {
            let model = try createManagedObjectModel(for: version)

            if model.isConfiguration(
                withName: version.rawValue,
                compatibleWithStoreMetadata: metadata
            ) {
                return CompatibleStore(version: version, model: model)
            }
        }

        return nil
    }

    private func createManagedObjectModel(
        for version: SubstrateStorageVersion
    ) throws -> NSManagedObjectModel {
        let omoURL = modelBundle.url(
            forResource: version.rawValue,
            withExtension: "omo",
            subdirectory: modelDirectory
        )

        let momURL = modelBundle.url(
            forResource: version.rawValue,
            withExtension: "mom",
            subdirectory: modelDirectory
        )

        guard
            let modelURL = omoURL ?? momURL,
            let model = NSManagedObjectModel(contentsOf: modelURL)
        else {
            throw SubstrateStorageMigrationError.modelUnavailable(version)
        }

        return model
    }

    private func createMapping(
        from sourceModel: NSManagedObjectModel,
        sourceVersion: SubstrateStorageVersion,
        nextModel: NSManagedObjectModel,
        destinationVersion: SubstrateStorageVersion
    ) throws -> NSMappingModel {
        if let requiredMapping = requiredCustomMapping(
            from: sourceVersion,
            to: destinationVersion
        ) {
            return try loadRequiredCustomMapping(
                requiredMapping,
                sourceModel: sourceModel,
                destinationModel: nextModel
            )
        }

        let mapping = try NSMappingModel.inferredMappingModel(
            forSourceModel: sourceModel,
            destinationModel: nextModel
        )

        if sourceVersion == .version4, destinationVersion == .version5 {
            try configureLegacyXcmTransforms(in: mapping)
        }

        return mapping
    }

    private func configureLegacyXcmTransforms(
        in mapping: NSMappingModel
    ) throws {
        let entityNames = [
            "CDChainXcmConfig",
            "CDXcmAvailableDestination"
        ]
        let policyClassName = NSStringFromClass(
            SubstrateLegacyXcmMigrationPolicy.self
        )
        var transformedEntityNames = Set<String>()

        mapping.entityMappings = mapping.entityMappings.map {
            inferredMapping in
            guard
                let entityName = inferredMapping.sourceEntityName,
                entityNames.contains(entityName),
                inferredMapping.destinationEntityName == entityName
            else {
                return inferredMapping
            }

            transformedEntityNames.insert(entityName)

            // Merely assigning a policy to an inferred "transform" mapping
            // does not make Core Data invoke that policy. Rebuild these two
            // mappings as complete custom mappings, retaining every inferred
            // property expression and both version hashes.
            let customMapping = NSEntityMapping()
            customMapping.name = "LegacyXcm_\(entityName)"
            customMapping.mappingType = .customEntityMappingType
            customMapping.sourceEntityName = inferredMapping.sourceEntityName
            customMapping.destinationEntityName =
                inferredMapping.destinationEntityName
            customMapping.sourceEntityVersionHash =
                inferredMapping.sourceEntityVersionHash
            customMapping.destinationEntityVersionHash =
                inferredMapping.destinationEntityVersionHash
            customMapping.sourceExpression = NSExpression(
                format: "FETCH(FUNCTION($manager, " +
                    "'fetchRequestForSourceEntityNamed:predicateString:', " +
                    "'\(entityName)', 'TRUEPREDICATE'), " +
                    "$manager.sourceContext, NO)"
            )
            customMapping.attributeMappings =
                inferredMapping.attributeMappings
            customMapping.relationshipMappings =
                inferredMapping.relationshipMappings
            customMapping.entityMigrationPolicyClassName = policyClassName

            return customMapping
        }

        for entityName in entityNames
            where !transformedEntityNames.contains(entityName) {
            throw SubstrateLegacyXcmMappingError
                .entityMappingUnavailable(entityName)
        }
    }

    private func requiredCustomMapping(
        from sourceVersion: SubstrateStorageVersion,
        to destinationVersion: SubstrateStorageVersion
    ) -> RequiredCustomMapping? {
        switch (sourceVersion, destinationVersion) {
        case (.version1, .version2):
            return RequiredCustomMapping(
                resourceName: "SubstrateV2Mapping",
                policyClassName: NSStringFromClass(
                    ChainSubstrateV2MigrationPolicy.self
                )
            )
        case (.version3, .version4):
            return RequiredCustomMapping(
                resourceName: "SubstrateV3toV4",
                policyClassName: NSStringFromClass(
                    ChainModelV4MigrationPolicy.self
                )
            )
        default:
            return nil
        }
    }

    private func loadRequiredCustomMapping(
        _ requiredMapping: RequiredCustomMapping,
        sourceModel: NSManagedObjectModel,
        destinationModel: NSManagedObjectModel
    ) throws -> NSMappingModel {
        guard let mappingURL = modelBundle.url(
            forResource: requiredMapping.resourceName,
            withExtension: "cdm"
        ) else {
            throw SubstrateCustomMappingError.resourceUnavailable(
                requiredMapping.resourceName
            )
        }

        guard let mapping = NSMappingModel(contentsOf: mappingURL) else {
            throw SubstrateCustomMappingError.resourceUnreadable(
                requiredMapping.resourceName
            )
        }

        let bundleMapping = NSMappingModel(
            from: [modelBundle],
            forSourceModel: sourceModel,
            destinationModel: destinationModel
        )
        let entityHashesMatch = mapping.entityMappings.allSatisfy { entityMapping in
            let sourceMatches = entityMapping.sourceEntityName.map {
                sourceModel.entitiesByName[$0]?.versionHash ==
                    entityMapping.sourceEntityVersionHash
            } ?? true
            let destinationMatches = entityMapping.destinationEntityName.map {
                destinationModel.entitiesByName[$0]?.versionHash ==
                    entityMapping.destinationEntityVersionHash
            } ?? true

            return sourceMatches && destinationMatches
        }

        guard bundleMapping != nil, entityHashesMatch else {
            throw SubstrateCustomMappingError.incompatible(
                requiredMapping.resourceName
            )
        }

        let chainMapping = mapping.entityMappings.first {
            $0.sourceEntityName == "CDChain" &&
                $0.destinationEntityName == "CDChain"
        }

        guard
            chainMapping?.entityMigrationPolicyClassName ==
            requiredMapping.policyClassName
        else {
            throw SubstrateCustomMappingError.policyUnavailable(
                requiredMapping.resourceName,
                requiredMapping.policyClassName
            )
        }

        return mapping
    }

    private func forceWALCheckpointingForStore(
        at storeURL: URL,
        sourceModel: NSManagedObjectModel
    ) throws {
        do {
            try performWithObjectiveCExceptionBoundary(
                operation: .sourceCheckpoint
            ) {
                if let checkpointStoreHook = self.checkpointStoreHook {
                    try checkpointStoreHook(storeURL, sourceModel)
                    return
                }

                let persistentStoreCoordinator = NSPersistentStoreCoordinator(
                    managedObjectModel: sourceModel
                )
                let options = [NSSQLitePragmasOption: ["journal_mode": "DELETE"]]
                let store = try persistentStoreCoordinator.addPersistentStore(
                    at: storeURL,
                    options: options
                )
                try persistentStoreCoordinator.remove(store)
            }
        } catch let migrationError as SubstrateStorageMigrationError {
            throw migrationError
        } catch {
            throw SubstrateStorageMigrationError.walCheckpointFailed(storeURL, error)
        }
    }

    private func recoverRebuildableCache(
        after migrationError: SubstrateStorageMigrationError
    ) throws -> URL? {
        guard migrationError.allowsCacheRebuild else {
            throw migrationError
        }

        do {
            return try crashConsistentCacheRecovery.quarantine()
        } catch is SubstrateCacheRecoveryInterruption {
            throw SubstrateCacheRecoveryInterruption
                .simulatedProcessDeath
        } catch {
            throw SubstrateStorageMigrationError.cacheRecoveryFailed(
                storeURL,
                migrationError,
                error
            )
        }
    }
}

@objc(SubstrateLegacyXcmMigrationPolicy)
private final class SubstrateLegacyXcmMigrationPolicy: NSEntityMigrationPolicy {
    private static let availableAssetEntityName = "CDXcmAvailableAsset"

    override func createRelationships(
        forDestination destination: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        try super.createRelationships(
            forDestination: destination,
            in: mapping,
            manager: manager
        )

        let relationshipName: String
        switch mapping.sourceEntityName {
        case "CDChainXcmConfig":
            relationshipName = "availableAssets"
        case "CDXcmAvailableDestination":
            relationshipName = "assets"
        default:
            return
        }

        let entityName = mapping.sourceEntityName ?? "legacy XCM"
        guard destination.entity.relationshipsByName[relationshipName] != nil else {
            throw SubstrateLegacyXcmMappingError
                .destinationRelationshipUnavailable(
                    entityName,
                    relationshipName
                )
        }

        guard let source = manager.sourceInstances(
            forEntityMappingName: mapping.name,
            destinationInstances: [destination]
        ).first else {
            throw SubstrateLegacyXcmMappingError
                .sourceAssociationUnavailable(entityName)
        }

        let symbols: [String]?
        do {
            symbols = try SafeTransformableValueReader.read(
                from: source,
                key: relationshipName
            )
        } catch {
            // The disposable source is sanitized before migration. A residual
            // decode failure must fail closed inside the outer ObjC boundary.
            throw error
        }

        guard let symbols else {
            return
        }

        guard
            manager.destinationModel.entitiesByName[
                Self.availableAssetEntityName
            ] != nil
        else {
            throw SubstrateLegacyXcmMappingError
                .destinationEntityUnavailable(
                    Self.availableAssetEntityName
                )
        }

        let destinationAssets = destination.mutableSetValue(
            forKey: relationshipName
        )

        for symbol in symbols {
            let availableAsset = NSEntityDescription.insertNewObject(
                forEntityName: Self.availableAssetEntityName,
                into: manager.destinationContext
            )
            availableAsset.setValue(symbol, forKey: "symbol")
            destinationAssets.add(availableAsset)
        }
    }
}

extension SubstrateStorageMigrator: StorageMigrating {
    func requiresMigration() -> Bool {
        checkIfMigrationNeeded(to: targetVersion)
    }

    func migrate(_ completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else {
                return
            }

            var completedSafely = false

            do {
                try self.migrate()
                completedSafely = true
            } catch {
                Logger.shared.error(error.localizedDescription)
            }

            guard completedSafely else {
                return
            }

            DispatchQueue.main.async {
                completion()
            }
        }
    }
}

// Substrate migration invariants remain co-located.
// swiftlint:disable:this file_length
