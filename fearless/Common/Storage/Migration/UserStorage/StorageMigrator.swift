import CoreData
import CryptoKit
import Foundation
import IrohaCrypto
import SoraKeystore

protocol StorageMigrating {
    func requiresMigration() -> Bool
    func migrate(_ completion: @escaping () -> Void)
}

enum UserStorageMigratorKeys {
    static let keystoreMigrator = "keystoreMigrator"
    static let settingsMigrator = "settingsMigrator"
}

enum UserStorageMigrationError: LocalizedError {
    case metadataUnreadable(URL, Error)
    case unknownStoreVersion(URL)
    case modelUnavailable(UserStorageVersion)
    case migrationPathUnavailable(UserStorageVersion, UserStorageVersion)
    case objectiveCException
    case privateSourceRepairFailed
    case stagedStoreValidationFailed

    var errorDescription: String? {
        switch self {
        case .metadataUnreadable:
            return "Unable to read user store metadata safely"
        case .unknownStoreVersion:
            return "Unsupported user store version"
        case let .modelUnavailable(version):
            return "User store model is unavailable for \(version.rawValue)"
        case let .migrationPathUnavailable(source, destination):
            return "No user store migration path from \(source.rawValue) to \(destination.rawValue)"
        case .objectiveCException:
            return "A stored value could not be processed safely"
        case .privateSourceRepairFailed:
            return "The private user-storage copy could not be repaired safely"
        case .stagedStoreValidationFailed:
            return "The migrated user store did not pass integrity validation"
        }
    }
}

struct UserStorageIntegrityValidationLimits: Equatable {
    static let production = UserStorageIntegrityValidationLimits(
        maximumRowsPerEntity: 250_000,
        maximumRowsAcrossStore: 1_000_000,
        fetchBatchSize: 256,
        maximumCanonicalRowBytes: 1 * 1024 * 1024,
        maximumAttributeBytes: 256 * 1024,
        maximumRelationshipDestinations: 10000,
        maximumTransformableElements: 4096,
        maximumTransformableArchiveBytes: 1 * 1024 * 1024,
        maximumRelationshipDestinationsAcrossStore: 4_000_000
    )

    let maximumRowsPerEntity: Int
    let maximumRowsAcrossStore: Int
    let fetchBatchSize: Int
    let maximumCanonicalRowBytes: Int
    let maximumAttributeBytes: Int
    let maximumRelationshipDestinations: Int
    let maximumTransformableElements: Int
    let maximumTransformableArchiveBytes: Int
    let maximumRelationshipDestinationsAcrossStore: Int

    init(
        maximumRowsPerEntity: Int,
        maximumRowsAcrossStore: Int,
        fetchBatchSize: Int,
        maximumCanonicalRowBytes: Int,
        maximumAttributeBytes: Int,
        maximumRelationshipDestinations: Int,
        maximumTransformableElements: Int,
        maximumTransformableArchiveBytes: Int =
            1 * 1024 * 1024,
        maximumRelationshipDestinationsAcrossStore: Int =
            4_000_000
    ) {
        self.maximumRowsPerEntity = max(1, maximumRowsPerEntity)
        self.maximumRowsAcrossStore = max(1, maximumRowsAcrossStore)
        self.fetchBatchSize = max(1, fetchBatchSize)
        self.maximumCanonicalRowBytes = max(1, maximumCanonicalRowBytes)
        self.maximumAttributeBytes = max(1, maximumAttributeBytes)
        self.maximumRelationshipDestinations = max(
            1,
            maximumRelationshipDestinations
        )
        self.maximumTransformableElements = max(
            1,
            maximumTransformableElements
        )
        self.maximumTransformableArchiveBytes = max(
            1,
            maximumTransformableArchiveBytes
        )
        self.maximumRelationshipDestinationsAcrossStore = max(
            1,
            maximumRelationshipDestinationsAcrossStore
        )
    }
}

final class UserStorageMigrator {
    private struct IntegrityField: Equatable {
        let name: String
        let value: String

        var sortKey: String {
            "\(Data(name.utf8).base64EncodedString()):\(value)"
        }
    }

    private struct IntegrityIdentity: Equatable {
        let entityName: String
        let fields: [IntegrityField]

        var sortKey: String {
            [
                Data(entityName.utf8).base64EncodedString(),
                fields.map(\.sortKey).joined(separator: "|")
            ].joined(separator: ":")
        }
    }

    private struct IntegrityRelationship: Equatable {
        let name: String
        let destinations: [IntegrityIdentity]

        var sortKey: String {
            [
                Data(name.utf8).base64EncodedString(),
                destinations.map(\.sortKey).joined(separator: ",")
            ].joined(separator: ":")
        }
    }

    private struct IntegrityRow: Equatable {
        let identity: IntegrityIdentity
        let relationships: [IntegrityRelationship]

        var sortKey: String {
            [
                identity.sortKey,
                relationships.map(\.sortKey).joined(separator: "|")
            ].joined(separator: "#")
        }
    }

    private struct IntegrityDigest: Equatable {
        let rowCount: Int
        let xor: Data
        let sum: Data
    }

    private struct IntegrityDigestAccumulator {
        private(set) var rowCount = 0
        private var xor = [UInt8](
            repeating: 0,
            count: SHA256.byteCount
        )
        private var sum = [UInt8](
            repeating: 0,
            count: SHA256.byteCount
        )

        mutating func append(canonicalRow: String) {
            let digest = Array(
                SHA256.hash(data: Data(canonicalRow.utf8))
            )
            var carry = 0

            for index in digest.indices.reversed() {
                xor[index] ^= digest[index]

                let total =
                    Int(sum[index]) +
                    Int(digest[index]) +
                    carry
                sum[index] = UInt8(truncatingIfNeeded: total)
                carry = total >> 8
            }

            rowCount += 1
        }

        var digest: IntegrityDigest {
            IntegrityDigest(
                rowCount: rowCount,
                xor: Data(xor),
                sum: Data(sum)
            )
        }
    }

    private struct StagedStoreIntegritySnapshot: Equatable {
        let rowsByEntity: [String: IntegrityDigest]
    }

    private struct StagedStoreIntegrityAllowlist {
        static let none = StagedStoreIntegrityAllowlist(
            entityNames: [],
            attributeNamesByEntity: [:],
            relationshipNamesByEntity: [:]
        )

        let entityNames: Set<String>
        let attributeNamesByEntity: [String: Set<String>]
        let relationshipNamesByEntity: [String: Set<String>]
    }

    private enum StagedStoreSemanticSnapshot: Equatable {
        case legacyAccountIds([String])
        case assetVisibility(
            walletRows: IntegrityDigest,
            visibilityRowCount: Int
        )
        case networkManagementFilters(IntegrityDigest)
    }

    private static let resilientMetaAccountTransformableKeys = [
        "assetFilterOptions",
        "assetIdsEnabled",
        "assetKeysOrder",
        "favouriteChainIds",
        "unusedChainIds"
    ]

    let storeURL: URL
    let modelDirectory: String
    let keystore: KeystoreProtocol
    let settings: SettingsManagerProtocol
    let fileManager: FileManager
    let targetVersion: UserStorageVersion
    let modelBundle: Bundle
    private let metadataReader: (URL) throws -> [String: Any]
    private let crashConsistentStoreReplacer: CrashConsistentStoreReplacer
    private let keystoreMigratorFactory: (
        UserStorageVersion,
        UserStorageVersion,
        KeystoreProtocol
    ) -> KeystoreMigrating
    private let settingsMigratorFactory: (
        UserStorageVersion,
        UserStorageVersion,
        SettingsManagerProtocol
    ) -> SettingsMigrating
    private let stagedStoreWillValidate: (
        URL,
        UserStorageVersion
    ) throws -> Void
    private let privateSourceObjectIDPageDidFetch: (
        Int,
        Int
    ) -> Void
    private let integrityObjectPageDidFetch: (
        Int,
        Int
    ) -> Void
    private let privateSourceCopyLimits:
        SQLiteStoreFamilyCopyLimits
    private let privateSourceAvailableCapacityProvider:
        ((URL) throws -> UInt64)?
    private let integrityValidationLimits:
        UserStorageIntegrityValidationLimits

    init(
        targetVersion: UserStorageVersion,
        storeURL: URL,
        modelDirectory: String,
        keystore: KeystoreProtocol,
        settings: SettingsManagerProtocol,
        fileManager: FileManager,
        modelBundle: Bundle = .main,
        integrityValidationLimits:
        UserStorageIntegrityValidationLimits = .production,
        privateSourceCopyLimits:
        SQLiteStoreFamilyCopyLimits =
            .userStorageProduction,
        privateSourceAvailableCapacityProvider:
        ((URL) throws -> UInt64)? = nil,
        metadataReader: @escaping (URL) throws -> [String: Any] = { url in
            try NSPersistentStoreCoordinator.metadataForPersistentStore(
                ofType: NSSQLiteStoreType,
                at: url,
                options: nil
            )
        },
        storeReplacer: @escaping (URL, URL) throws -> Void = { targetURL, sourceURL in
            try NSPersistentStoreCoordinator.replaceStore(
                at: targetURL,
                withStoreAt: sourceURL
            )
        },
        keystoreMigratorFactory: @escaping (
            UserStorageVersion,
            UserStorageVersion,
            KeystoreProtocol
        ) -> KeystoreMigrating = { source, destination, keystore in
            KeystoreMigrator(
                sourceVersion: source,
                destinationVersion: destination,
                keystore: keystore
            )
        },
        settingsMigratorFactory: @escaping (
            UserStorageVersion,
            UserStorageVersion,
            SettingsManagerProtocol
        ) -> SettingsMigrating = { source, destination, settings in
            SettingsMigrator(
                sourceVersion: source,
                destinationVersion: destination,
                settings: settings
            )
        },
        stagedStoreWillValidate: @escaping (
            URL,
            UserStorageVersion
        ) throws -> Void = { _, _ in },
        storeReplacementBoundaryHook: @escaping (
            CrashConsistentStoreReplacementBoundary
        ) throws -> Void = { _ in },
        privateSourceObjectIDPageDidFetch: @escaping (
            Int,
            Int
        ) -> Void = { _, _ in },
        integrityObjectPageDidFetch: @escaping (
            Int,
            Int
        ) -> Void = { _, _ in }
    ) {
        self.targetVersion = targetVersion
        self.storeURL = storeURL
        self.modelDirectory = modelDirectory
        self.keystore = keystore
        self.settings = settings
        self.fileManager = fileManager
        self.modelBundle = modelBundle
        self.integrityValidationLimits = integrityValidationLimits
        self.privateSourceCopyLimits =
            privateSourceCopyLimits
        self.privateSourceAvailableCapacityProvider =
            privateSourceAvailableCapacityProvider
        self.metadataReader = metadataReader
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
        self.keystoreMigratorFactory = keystoreMigratorFactory
        self.settingsMigratorFactory = settingsMigratorFactory
        self.stagedStoreWillValidate = stagedStoreWillValidate
        self.privateSourceObjectIDPageDidFetch =
            privateSourceObjectIDPageDidFetch
        self.integrityObjectPageDidFetch =
            integrityObjectPageDidFetch
    }

    @discardableResult
    func performMigration() throws -> Bool {
        try reconcilePendingStoreReplacement()

        guard try crashConsistentStoreReplacer.liveStoreExistsSafely() else {
            return false
        }

        return try withPrivateSourceCopy { privateSourceURL, tmpMigrationDirURL in
            let sourceVersion = try readSourceVersion(
                at: privateSourceURL
            )

            try KeystoreMigrator.recoverPendingCleanup(
                keystore: keystore,
                currentVersion: sourceVersion
            )
            try SettingsMigrator.recoverPendingCleanup(
                settings: settings,
                currentVersion: sourceVersion
            )

            let privateSourceWasRepaired =
                try sanitizePrivateSourceCopy(
                    at: privateSourceURL,
                    version: sourceVersion
                )

            guard sourceVersion != targetVersion else {
                guard privateSourceWasRepaired else {
                    return false
                }

                try replaceCurrentVersionStore(
                    with: privateSourceURL,
                    version: sourceVersion
                )
                return true
            }

            try performMigration(
                from: sourceVersion,
                to: targetVersion,
                sourceStoreURL: privateSourceURL,
                destinationStoreURL: storeURL,
                tmpMigrationDirURL: tmpMigrationDirURL
            )

            return true
        }
    }

    private func performMigration(
        from sourceVersion: UserStorageVersion,
        to destinationVersion: UserStorageVersion,
        sourceStoreURL: URL,
        destinationStoreURL: URL,
        tmpMigrationDirURL: URL
    ) throws {
        var currentVersion = sourceVersion
        var currentURL = sourceStoreURL

        let keystoreMigrator = keystoreMigratorFactory(
            sourceVersion,
            destinationVersion,
            keystore
        )

        let settingsMigrator = settingsMigratorFactory(
            sourceVersion,
            destinationVersion,
            settings
        )

        while currentVersion != destinationVersion {
            guard let nextVersion = currentVersion.nextVersion() else {
                throw UserStorageMigrationError.migrationPathUnavailable(
                    currentVersion,
                    destinationVersion
                )
            }

            let currentModel = try createManagedObjectModel(for: currentVersion)
            let nextModel = try createManagedObjectModel(for: nextVersion)
            let integrityAllowlist = try commonIntegrityAllowlist(
                from: currentVersion,
                to: nextVersion
            )
            let expectedHopIntegrity = try stagedStoreIntegritySnapshot(
                at: currentURL,
                model: currentModel,
                comparedWith: nextModel,
                allowlist: integrityAllowlist
            )
            let expectedSemanticIntegrity =
                try stagedStoreSemanticSnapshot(
                    at: currentURL,
                    model: currentModel,
                    storeVersion: currentVersion,
                    migratingFrom: currentVersion,
                    to: nextVersion
                )
            let expectedMetaAccountCount: Int?
            if shouldValidateMetaAccountCount(from: currentVersion) {
                expectedMetaAccountCount = try stagedMetaAccountCount(
                    at: currentURL,
                    model: currentModel
                )
            } else {
                expectedMetaAccountCount = nil
            }

            try keystoreMigrator.switchVersion()
            try settingsMigrator.switchVersion()

            let mapping = try createMapping(from: currentModel, nextModel: nextModel)

            let manager = NSMigrationManager(sourceModel: currentModel, destinationModel: nextModel)

            var userInfo = manager.userInfo ?? [AnyHashable: Any]()
            userInfo[UserStorageMigratorKeys.keystoreMigrator] = keystoreMigrator
            userInfo[UserStorageMigratorKeys.settingsMigrator] = settingsMigrator
            manager.userInfo = userInfo

            let nextStepURL = tmpMigrationDirURL.appendingPathComponent(UUID().uuidString)

            try performWithObjectiveCExceptionBoundary(
                phase: "staged migration"
            ) {
                try manager.migrateStore(
                    from: currentURL,
                    sourceType: NSSQLiteStoreType,
                    options: nil,
                    with: mapping,
                    toDestinationURL: nextStepURL,
                    destinationType: NSSQLiteStoreType,
                    destinationOptions: nil
                )
            }

            try stagedStoreWillValidate(nextStepURL, nextVersion)

            if let expectedMetaAccountCount {
                let actualMetaAccountCount = try stagedMetaAccountCount(
                    at: nextStepURL,
                    model: nextModel
                )

                guard
                    actualMetaAccountCount == expectedMetaAccountCount
                else {
                    throw UserStorageMigrationError
                        .stagedStoreValidationFailed
                }
            }

            let actualSemanticIntegrity =
                try stagedStoreSemanticSnapshot(
                    at: nextStepURL,
                    model: nextModel,
                    storeVersion: nextVersion,
                    migratingFrom: currentVersion,
                    to: nextVersion
                )
            guard
                actualSemanticIntegrity == expectedSemanticIntegrity
            else {
                throw UserStorageMigrationError
                    .stagedStoreValidationFailed
            }

            let actualHopIntegrity =
                try stagedStoreIntegritySnapshot(
                    at: nextStepURL,
                    model: nextModel,
                    comparedWith: currentModel,
                    allowlist: integrityAllowlist
                )

            guard actualHopIntegrity == expectedHopIntegrity else {
                throw UserStorageMigrationError
                    .stagedStoreValidationFailed
            }

            try NSPersistentStoreCoordinator.destroyStore(at: currentURL)

            currentVersion = nextVersion
            currentURL = nextStepURL
        }

        try keystoreMigrator.prepare()
        try settingsMigrator.prepare()

        let destinationModel = try createManagedObjectModel(
            for: destinationVersion
        )
        let expectedCommittedIntegrity = try stagedStoreIntegritySnapshot(
            at: currentURL,
            model: destinationModel,
            comparedWith: destinationModel
        )
        try crashConsistentStoreReplacer.replaceStore(
            with: currentURL
        ) { liveStoreURL in
            let actualCommittedIntegrity =
                try self.stagedStoreIntegritySnapshot(
                    at: liveStoreURL,
                    model: destinationModel,
                    comparedWith: destinationModel
                )

            guard
                actualCommittedIntegrity ==
                expectedCommittedIntegrity
            else {
                throw UserStorageMigrationError
                    .stagedStoreValidationFailed
            }
        }

        do {
            try keystoreMigrator.finalize()
        } catch {
            Logger.shared.error(
                "Unable to finish user-storage key cleanup"
            )
            throw error
        }

        do {
            try settingsMigrator.finalize()
        } catch {
            Logger.shared.error(
                "Unable to finish user-storage settings cleanup"
            )
            throw error
        }

        if currentURL != destinationStoreURL {
            do {
                try NSPersistentStoreCoordinator.destroyStore(at: currentURL)
            } catch {
                Logger.shared.error(
                    "Unable to remove temporary user-storage migration store"
                )
            }
        }
    }

    private func replaceCurrentVersionStore(
        with sanitizedStoreURL: URL,
        version: UserStorageVersion
    ) throws {
        let model = try createManagedObjectModel(for: version)
        let expectedIntegrity = try stagedStoreIntegritySnapshot(
            at: sanitizedStoreURL,
            model: model,
            comparedWith: model
        )
        try stagedStoreWillValidate(
            sanitizedStoreURL,
            version
        )
        let validatedIntegrity = try stagedStoreIntegritySnapshot(
            at: sanitizedStoreURL,
            model: model,
            comparedWith: model
        )
        guard validatedIntegrity == expectedIntegrity else {
            throw UserStorageMigrationError
                .stagedStoreValidationFailed
        }

        try crashConsistentStoreReplacer.replaceStore(
            with: sanitizedStoreURL
        ) { liveStoreURL in
            let actualIntegrity =
                try self.stagedStoreIntegritySnapshot(
                    at: liveStoreURL,
                    model: model,
                    comparedWith: model
                )

            guard actualIntegrity == expectedIntegrity else {
                throw UserStorageMigrationError
                    .stagedStoreValidationFailed
            }
        }
    }

    /// Migration is always performed from a disposable source copy. Unsafe
    /// preference archives are repaired only in that copy; the user's original
    /// store remains untouched until a validated atomic replacement.
    private func sanitizePrivateSourceCopy(
        at privateSourceURL: URL,
        version: UserStorageVersion
    ) throws -> Bool {
        let model = try createManagedObjectModel(for: version)
        let rawRepairedValueCount: Int

        do {
            rawRepairedValueCount =
                try SQLiteTransformableArchivePreflight
                    .repairOversizedArchives(
                        at: privateSourceURL,
                        columns: preferenceTransformableArchiveColumns(
                            in: model
                        ),
                        maximumArchiveByteCount:
                        integrityValidationLimits
                            .maximumTransformableArchiveBytes
                    )
        } catch {
            throw UserStorageMigrationError
                .privateSourceRepairFailed
        }
        var didRepair = rawRepairedValueCount > 0

        let coordinator = NSPersistentStoreCoordinator(
            managedObjectModel: model
        )
        var persistentStore: NSPersistentStore?

        try performWithObjectiveCExceptionBoundary(
            phase: "private source open"
        ) {
            persistentStore = try coordinator.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: privateSourceURL,
                options: [
                    NSSQLitePragmasOption: ["journal_mode": "DELETE"],
                    NSMigratePersistentStoresAutomaticallyOption: false,
                    NSInferMappingModelAutomaticallyOption: false
                ]
            )
        }

        defer {
            if let persistentStore {
                try? coordinator.remove(persistentStore)
            }
        }

        let context = NSManagedObjectContext(
            concurrencyType: .privateQueueConcurrencyType
        )
        context.persistentStoreCoordinator = coordinator

        if version == .version1 {
            try enforceVersion1PrivateSourceRowLimits(
                model: model,
                context: context
            )
            return didRepair
        }

        guard model.entitiesByName["CDMetaAccount"] != nil else {
            return didRepair
        }

        var contextError: Error?
        context.performAndWait {
            do {
                try self.performWithObjectiveCExceptionBoundary(
                    phase: "private source preference repair"
                ) {
                    let request = NSFetchRequest<NSFetchRequestResult>(
                        entityName: "CDMetaAccount"
                    )
                    request.resultType = .managedObjectIDResultType
                    request.includesPendingChanges = false
                    request.includesSubentities = false
                    request.affectedStores =
                        persistentStore.map { [$0] }

                    // Count and enforce the cap before fetching any IDs. The
                    // immutable exact-once cohort below can therefore never
                    // grow beyond a deterministic production bound.
                    let objectCount = try context.count(for: request)
                    guard
                        objectCount != NSNotFound,
                        objectCount <=
                        self.integrityValidationLimits
                        .maximumRowsPerEntity,
                        objectCount <=
                        self.integrityValidationLimits
                        .maximumRowsAcrossStore,
                        objectCount < Int.max
                    else {
                        throw UserStorageMigrationError
                            .privateSourceRepairFailed
                    }

                    request.fetchLimit = objectCount + 1
                    request.fetchBatchSize = min(
                        self.integrityValidationLimits.fetchBatchSize,
                        objectCount + 1
                    )
                    let cohortResults = try context.fetch(request)
                    let cohortObjectIDs = cohortResults.compactMap {
                        $0 as? NSManagedObjectID
                    }
                    guard
                        cohortObjectIDs.count ==
                        cohortResults.count,
                        cohortObjectIDs.count == objectCount,
                        Set(cohortObjectIDs).count == objectCount
                    else {
                        throw UserStorageMigrationError
                            .privateSourceRepairFailed
                    }

                    var pageStart = 0
                    while pageStart < cohortObjectIDs.count {
                        let remainingObjectCount =
                            cohortObjectIDs.count - pageStart
                        let pageLength = min(
                            self.integrityValidationLimits
                                .fetchBatchSize,
                            remainingObjectCount
                        )
                        let pageEnd = pageStart + pageLength
                        let pageObjectIDs = Array(
                            cohortObjectIDs[pageStart ..< pageEnd]
                        )
                        let pageRequest =
                            NSFetchRequest<NSFetchRequestResult>(
                                entityName: "CDMetaAccount"
                            )
                        pageRequest.resultType =
                            .managedObjectIDResultType
                        pageRequest.includesPendingChanges = false
                        pageRequest.includesSubentities = false
                        pageRequest.predicate = NSPredicate(
                            format: "SELF IN %@",
                            pageObjectIDs
                        )
                        pageRequest.affectedStores =
                            persistentStore.map { [$0] }
                        pageRequest.fetchLimit =
                            pageObjectIDs.count
                        pageRequest.fetchBatchSize =
                            pageObjectIDs.count

                        let fetchedResults =
                            try context.fetch(pageRequest)
                        let fetchedObjectIDs =
                            fetchedResults.compactMap {
                                $0 as? NSManagedObjectID
                            }
                        self.privateSourceObjectIDPageDidFetch(
                            fetchedObjectIDs.count,
                            pageObjectIDs.count
                        )
                        guard
                            fetchedObjectIDs.count ==
                            fetchedResults.count,
                            fetchedObjectIDs.count ==
                            pageObjectIDs.count,
                            Set(fetchedObjectIDs) ==
                            Set(pageObjectIDs)
                        else {
                            throw UserStorageMigrationError
                                .privateSourceRepairFailed
                        }

                        for objectID in pageObjectIDs {
                            if try self.sanitizePreferenceTransformables(
                                objectID: objectID,
                                model: model,
                                context: context,
                                persistentStore:
                                persistentStore
                            ) {
                                didRepair = true
                            }
                        }
                        pageStart = pageEnd
                    }

                    request.fetchLimit = 0
                    request.fetchBatchSize = 0
                    guard
                        pageStart == objectCount,
                        try context.count(for: request) == objectCount
                    else {
                        throw UserStorageMigrationError
                            .privateSourceRepairFailed
                    }
                }
            } catch {
                contextError = error
            }
        }

        if let contextError {
            throw contextError
        }

        return didRepair
    }

    private func enforceVersion1PrivateSourceRowLimits(
        model: NSManagedObjectModel,
        context: NSManagedObjectContext
    ) throws {
        guard model.entitiesByName["CDAccountItem"] != nil else {
            throw UserStorageMigrationError
                .privateSourceRepairFailed
        }
        let maximumLegacyAccountRows = min(
            min(
                integrityValidationLimits.maximumRowsPerEntity,
                integrityValidationLimits.maximumRowsAcrossStore
            ),
            KeystoreMigrationResourceLimits.production
                .maximumLegacyAccountRows
        )

        var contextError: Error?
        context.performAndWait {
            do {
                try self.performWithObjectiveCExceptionBoundary(
                    phase: "private version-1 source row inspection"
                ) {
                    let request =
                        NSFetchRequest<NSFetchRequestResult>(
                            entityName: "CDAccountItem"
                        )
                    request.includesPendingChanges = false
                    request.includesSubentities = false
                    let rowCount = try context.count(for: request)

                    guard
                        rowCount != NSNotFound,
                        rowCount <= maximumLegacyAccountRows
                    else {
                        throw UserStorageMigrationError
                            .privateSourceRepairFailed
                    }
                }
            } catch {
                contextError = error
            }
        }

        if let contextError {
            throw contextError
        }
    }

    private func preferenceTransformableArchiveColumns(
        in model: NSManagedObjectModel
    ) -> [SQLiteTransformableArchiveColumn] {
        guard
            let entity = model.entitiesByName["CDMetaAccount"]
        else {
            return []
        }

        return Self.resilientMetaAccountTransformableKeys
            .compactMap {
                key in

                guard
                    let attribute = entity.attributesByName[key],
                    attribute.attributeType ==
                    .transformableAttributeType
                else {
                    return nil
                }

                return SQLiteTransformableArchiveColumn(
                    entityName: "CDMetaAccount",
                    attributeName: key,
                    isOptional: attribute.isOptional,
                    valueTransformerName:
                    attribute.valueTransformerName
                )
            }
            .sorted {
                $0.attributeName < $1.attributeName
            }
    }

    func copyStoreFamily(
        from sourceURL: URL,
        to destinationURL: URL
    ) throws {
        try SQLiteStoreFamilyCopier.copy(
            from: sourceURL,
            to: destinationURL,
            includingSharedMemory: false,
            fileManager: fileManager,
            limits: privateSourceCopyLimits,
            availableCapacityProvider:
            privateSourceAvailableCapacityProvider
        )
    }

    private func withPrivateSourceCopy<Result>(
        _ operation: (
            URL,
            URL
        ) throws -> Result
    ) throws -> Result {
        let tmpMigrationDirURL = URL(
            fileURLWithPath: NSTemporaryDirectory(),
            isDirectory: true
        ).appendingPathComponent(UUID().uuidString)

        try fileManager.createDirectory(
            at: tmpMigrationDirURL,
            withIntermediateDirectories: true
        )
        defer {
            try? fileManager.removeItem(at: tmpMigrationDirURL)
        }

        let privateSourceURL = tmpMigrationDirURL
            .appendingPathComponent("SanitizedSource.sqlite")
        try copyStoreFamily(
            from: storeURL,
            to: privateSourceURL
        )

        return try operation(
            privateSourceURL,
            tmpMigrationDirURL
        )
    }

    private func readSourceVersion(
        at privateSourceURL: URL
    ) throws -> UserStorageVersion {
        var metadata: [String: Any]?

        do {
            try performWithObjectiveCExceptionBoundary(
                phase: "private source metadata read"
            ) {
                metadata = try self.metadataReader(privateSourceURL)
            }
        } catch let error as UserStorageMigrationError {
            guard case .objectiveCException = error else {
                throw UserStorageMigrationError.metadataUnreadable(
                    storeURL,
                    error
                )
            }

            throw error
        } catch {
            throw UserStorageMigrationError.metadataUnreadable(
                storeURL,
                error
            )
        }

        guard
            let metadata,
            let sourceVersion =
            compatibleVersionForStoreMetadata(metadata)
        else {
            throw UserStorageMigrationError.unknownStoreVersion(
                storeURL
            )
        }

        return sourceVersion
    }

    private func reconcilePendingStoreReplacement() throws {
        try crashConsistentStoreReplacer.reconcile {
            liveStoreURL in

            guard
                try self.readSourceVersion(at: liveStoreURL) ==
                self.targetVersion
            else {
                throw UserStorageMigrationError
                    .stagedStoreValidationFailed
            }
        }
    }

    private func commonIntegrityAllowlist(
        from sourceVersion: UserStorageVersion,
        to destinationVersion: UserStorageVersion
    ) throws -> StagedStoreIntegrityAllowlist {
        switch (sourceVersion, destinationVersion) {
        case (.version1, .version2),
             (.version2, .version3),
             (.version3, .version4),
             (.version4, .version5),
             (.version5, .version6),
             (.version6, .version7),
             (.version7, .version8),
             (.version8, .version9),
             (.version9, .version10),
             (.version10, .version11),
             (.version11, .version12),
             (.version12, .version14),
             (.version13, .version14):
            // Intentional renames, additions, and removals are outside the
            // common-schema contract. No same-named field is allowed to
            // change value on any supported hop.
            return .none
        default:
            throw UserStorageMigrationError.migrationPathUnavailable(
                sourceVersion,
                destinationVersion
            )
        }
    }

    private func stagedStoreSemanticSnapshot(
        at storeURL: URL,
        model: NSManagedObjectModel,
        storeVersion: UserStorageVersion,
        migratingFrom sourceVersion: UserStorageVersion,
        to destinationVersion: UserStorageVersion
    ) throws -> StagedStoreSemanticSnapshot? {
        switch (sourceVersion, destinationVersion) {
        case (.version1, .version2):
            guard
                storeVersion == sourceVersion ||
                storeVersion == destinationVersion
            else {
                throw UserStorageMigrationError
                    .stagedStoreValidationFailed
            }

            return try readStagedStoreSemanticSnapshot(
                at: storeURL,
                model: model,
                phase: "legacy account semantic validation"
            ) { context in
                if storeVersion == sourceVersion {
                    return try self.legacyAccountSourceSnapshot(
                        context: context
                    )
                }

                return try self.legacyAccountDestinationSnapshot(
                    context: context
                )
            }
        case (.version9, .version10):
            guard
                storeVersion == sourceVersion ||
                storeVersion == destinationVersion
            else {
                throw UserStorageMigrationError
                    .stagedStoreValidationFailed
            }

            return try readStagedStoreSemanticSnapshot(
                at: storeURL,
                model: model,
                phase: "asset visibility semantic validation"
            ) { context in
                if storeVersion == sourceVersion {
                    return try self.assetVisibilitySourceSnapshot(
                        context: context
                    )
                }

                return try self.assetVisibilityDestinationSnapshot(
                    context: context
                )
            }
        case (.version11, .version12):
            guard
                storeVersion == sourceVersion ||
                storeVersion == destinationVersion
            else {
                throw UserStorageMigrationError
                    .stagedStoreValidationFailed
            }

            return try readStagedStoreSemanticSnapshot(
                at: storeURL,
                model: model,
                phase: "network filter semantic validation"
            ) { context in
                if storeVersion == sourceVersion {
                    return try self.networkFilterSourceSnapshot(
                        context: context
                    )
                }

                return try self.networkFilterDestinationSnapshot(
                    context: context
                )
            }
        default:
            return nil
        }
    }

    private func readStagedStoreSemanticSnapshot(
        at storeURL: URL,
        model: NSManagedObjectModel,
        phase: String,
        makeSnapshot: @escaping (
            NSManagedObjectContext
        ) throws -> StagedStoreSemanticSnapshot
    ) throws -> StagedStoreSemanticSnapshot {
        let coordinator = NSPersistentStoreCoordinator(
            managedObjectModel: model
        )
        var persistentStore: NSPersistentStore?

        try performWithObjectiveCExceptionBoundary(
            phase: "\(phase) open"
        ) {
            persistentStore = try coordinator.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: storeURL,
                options: [
                    NSMigratePersistentStoresAutomaticallyOption: false,
                    NSInferMappingModelAutomaticallyOption: false
                ]
            )
        }

        defer {
            if let persistentStore {
                try? coordinator.remove(persistentStore)
            }
        }

        let context = NSManagedObjectContext(
            concurrencyType: .privateQueueConcurrencyType
        )
        context.persistentStoreCoordinator = coordinator

        var snapshot: StagedStoreSemanticSnapshot?
        var contextError: Error?
        context.performAndWait {
            do {
                try self.performWithObjectiveCExceptionBoundary(
                    phase: "\(phase) read"
                ) {
                    snapshot = try makeSnapshot(context)
                }
            } catch {
                contextError = error
            }
        }

        if let contextError {
            throw contextError
        }

        guard let snapshot else {
            throw UserStorageMigrationError
                .stagedStoreValidationFailed
        }

        return snapshot
    }

    private func legacyAccountSourceSnapshot(
        context: NSManagedObjectContext
    ) throws -> StagedStoreSemanticSnapshot {
        let addressFactory = SS58AddressFactory()
        var accountIds = Set<String>()

        _ = try stagedSemanticDigest(
            context: context,
            entityName: "CDAccountItem"
        ) { account in
            guard
                let address = account.value(
                    forKey: "identifier"
                ) as? AccountAddress
            else {
                throw UserStorageMigrationError
                    .stagedStoreValidationFailed
            }

            let accountId = try addressFactory.accountId(
                from: address
            ).toHex()
            accountIds.insert(accountId)

            return try self.canonicalSemanticStrings(
                [address, accountId]
            )
        }

        return .legacyAccountIds(accountIds.sorted())
    }

    private func legacyAccountDestinationSnapshot(
        context: NSManagedObjectContext
    ) throws -> StagedStoreSemanticSnapshot {
        var accountIds = Set<String>()
        let digest = try stagedSemanticDigest(
            context: context,
            entityName: "CDMetaAccount"
        ) { account in
            guard
                let accountId = account.value(
                    forKey: "substrateAccountId"
                ) as? String
            else {
                throw UserStorageMigrationError
                    .stagedStoreValidationFailed
            }

            accountIds.insert(accountId)
            return try self.canonicalSemanticStrings([accountId])
        }

        guard digest.rowCount == accountIds.count else {
            throw UserStorageMigrationError
                .stagedStoreValidationFailed
        }

        let destinationModel =
            context.persistentStoreCoordinator?
                .managedObjectModel
        guard let destinationModel else {
            throw UserStorageMigrationError
                .stagedStoreValidationFailed
        }
        for entityName in destinationModel.entitiesByName.keys
            where entityName != "CDMetaAccount" {
            let request =
                NSFetchRequest<NSFetchRequestResult>(
                    entityName: entityName
                )
            request.includesPendingChanges = false
            request.includesSubentities = false
            guard try context.count(for: request) == 0 else {
                throw UserStorageMigrationError
                    .stagedStoreValidationFailed
            }
        }

        return .legacyAccountIds(accountIds.sorted())
    }

    private func assetVisibilitySourceSnapshot(
        context: NSManagedObjectContext
    ) throws -> StagedStoreSemanticSnapshot {
        var visibilityRowCount = 0
        let digest = try stagedSemanticDigest(
            context: context,
            entityName: "CDMetaAccount"
        ) { wallet in
            guard
                let metaId = wallet.value(
                    forKey: "metaId"
                ) as? String
            else {
                throw UserStorageMigrationError
                    .stagedStoreValidationFailed
            }

            let assetIds: [String] =
                try SafeTransformableValueReader.read(
                    from: wallet,
                    key: "assetIdsEnabled"
                ) ?? []
            try self.validateSemanticStrings(
                assetIds,
                maximumCount:
                self.integrityValidationLimits
                    .maximumTransformableElements
            )
            guard
                visibilityRowCount <=
                self.integrityValidationLimits
                .maximumRelationshipDestinationsAcrossStore -
                assetIds.count
            else {
                throw UserStorageMigrationError
                    .stagedStoreValidationFailed
            }
            visibilityRowCount += assetIds.count

            return try self.canonicalSemanticStrings(
                [metaId] + assetIds.sorted()
            )
        }

        return .assetVisibility(
            walletRows: digest,
            visibilityRowCount: visibilityRowCount
        )
    }

    private func assetVisibilityDestinationSnapshot(
        context: NSManagedObjectContext
    ) throws -> StagedStoreSemanticSnapshot {
        var visibilityRowCount = 0
        let digest = try stagedSemanticDigest(
            context: context,
            entityName: "CDMetaAccount"
        ) { wallet in
            guard
                let metaId = wallet.value(
                    forKey: "metaId"
                ) as? String
            else {
                throw UserStorageMigrationError
                    .stagedStoreValidationFailed
            }

            let preflightCount =
                try self.preflightRelationshipDestinationCount(
                    for: wallet,
                    relationshipName: "assetsVisibility"
                )
            guard
                preflightCount <=
                self.integrityValidationLimits
                .maximumRelationshipDestinations,
                visibilityRowCount <=
                self.integrityValidationLimits
                .maximumRelationshipDestinationsAcrossStore -
                preflightCount,
                let visibilitySet = wallet.value(
                    forKey: "assetsVisibility"
                ) as? NSSet,
                visibilitySet.count == preflightCount
            else {
                throw UserStorageMigrationError
                    .stagedStoreValidationFailed
            }

            var assetIds = [String]()
            assetIds.reserveCapacity(preflightCount)
            for case let visibility as NSManagedObject
            in visibilitySet {
                guard
                    let assetId = visibility.value(
                        forKey: "assetId"
                    ) as? String,
                    let hidden = visibility.value(
                        forKey: "hidden"
                    ) as? NSNumber,
                    hidden.boolValue
                else {
                    throw UserStorageMigrationError
                        .stagedStoreValidationFailed
                }
                assetIds.append(assetId)
            }
            guard assetIds.count == preflightCount else {
                throw UserStorageMigrationError
                    .stagedStoreValidationFailed
            }
            try self.validateSemanticStrings(
                assetIds,
                maximumCount:
                self.integrityValidationLimits
                    .maximumTransformableElements
            )
            visibilityRowCount += assetIds.count

            return try self.canonicalSemanticStrings(
                [metaId] + assetIds.sorted()
            )
        }

        let visibilityRequest =
            NSFetchRequest<NSFetchRequestResult>(
                entityName: "CDAssetVisibility"
            )
        visibilityRequest.includesPendingChanges = false
        visibilityRequest.includesSubentities = false
        let storedVisibilityRowCount = try context.count(
            for: visibilityRequest
        )
        guard
            storedVisibilityRowCount != NSNotFound,
            storedVisibilityRowCount == visibilityRowCount
        else {
            throw UserStorageMigrationError
                .stagedStoreValidationFailed
        }

        return .assetVisibility(
            walletRows: digest,
            visibilityRowCount: visibilityRowCount
        )
    }

    private func networkFilterSourceSnapshot(
        context: NSManagedObjectContext
    ) throws -> StagedStoreSemanticSnapshot {
        let digest = try stagedSemanticDigest(
            context: context,
            entityName: "CDMetaAccount"
        ) { wallet in
            guard
                let metaId = wallet.value(
                    forKey: "metaId"
                ) as? String
            else {
                throw UserStorageMigrationError
                    .stagedStoreValidationFailed
            }
            let filter = wallet.value(
                forKey: "chainIdForFilter"
            ) as? String

            return try self.canonicalSemanticStrings(
                [metaId, filter]
            )
        }

        return .networkManagementFilters(digest)
    }

    private func networkFilterDestinationSnapshot(
        context: NSManagedObjectContext
    ) throws -> StagedStoreSemanticSnapshot {
        let digest = try stagedSemanticDigest(
            context: context,
            entityName: "CDMetaAccount"
        ) { wallet in
            guard
                let metaId = wallet.value(
                    forKey: "metaId"
                ) as? String
            else {
                throw UserStorageMigrationError
                    .stagedStoreValidationFailed
            }
            let filter = wallet.value(
                forKey: "networkManagmentFilter"
            ) as? String
            let favouriteChainIds: [String]? =
                try SafeTransformableValueReader.read(
                    from: wallet,
                    key: "favouriteChainIds"
                )
            guard favouriteChainIds?.isEmpty == true else {
                throw UserStorageMigrationError
                    .stagedStoreValidationFailed
            }

            return try self.canonicalSemanticStrings(
                [metaId, filter]
            )
        }

        return .networkManagementFilters(digest)
    }

    private func stagedSemanticDigest(
        context: NSManagedObjectContext,
        entityName: String,
        canonicalRow: (NSManagedObject) throws -> String
    ) throws -> IntegrityDigest {
        guard
            context.persistentStoreCoordinator?
            .managedObjectModel.entitiesByName[entityName] != nil
        else {
            throw UserStorageMigrationError
                .stagedStoreValidationFailed
        }

        let countRequest =
            NSFetchRequest<NSFetchRequestResult>(
                entityName: entityName
            )
        countRequest.includesPendingChanges = false
        countRequest.includesSubentities = false
        let rowCount = try context.count(for: countRequest)
        guard
            rowCount != NSNotFound,
            rowCount <=
            integrityValidationLimits.maximumRowsPerEntity,
            rowCount <=
            integrityValidationLimits.maximumRowsAcrossStore
        else {
            throw UserStorageMigrationError
                .stagedStoreValidationFailed
        }

        let identifierRequest =
            NSFetchRequest<NSFetchRequestResult>(
                entityName: entityName
            )
        identifierRequest.resultType =
            .managedObjectIDResultType
        identifierRequest.includesPendingChanges = false
        identifierRequest.includesSubentities = false
        identifierRequest.fetchLimit = rowCount + 1
        identifierRequest.fetchBatchSize = min(
            integrityValidationLimits.fetchBatchSize,
            rowCount + 1
        )
        let fetchedIdentifiers =
            try context.fetch(identifierRequest)
        let objectIDs = fetchedIdentifiers.compactMap {
            $0 as? NSManagedObjectID
        }
        guard
            objectIDs.count == fetchedIdentifiers.count,
            objectIDs.count == rowCount,
            Set(objectIDs).count == rowCount
        else {
            throw UserStorageMigrationError
                .stagedStoreValidationFailed
        }

        var accumulator = IntegrityDigestAccumulator()
        var pageStart = 0
        while pageStart < objectIDs.count {
            let pageEnd = min(
                pageStart +
                    integrityValidationLimits.fetchBatchSize,
                objectIDs.count
            )
            let pageObjectIDs = Array(
                objectIDs[pageStart ..< pageEnd]
            )
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
            let objects = try context.fetch(request)
            integrityObjectPageDidFetch(
                objects.count,
                pageObjectIDs.count
            )
            guard
                objects.count == pageObjectIDs.count,
                Set(objects.map(\.objectID)) ==
                Set(pageObjectIDs)
            else {
                throw UserStorageMigrationError
                    .stagedStoreValidationFailed
            }

            for object in objects {
                let row = try canonicalRow(object)
                guard
                    row.utf8.count <=
                    integrityValidationLimits
                    .maximumCanonicalRowBytes
                else {
                    throw UserStorageMigrationError
                        .stagedStoreValidationFailed
                }
                accumulator.append(canonicalRow: row)
            }

            pageStart = pageEnd
            context.reset()
        }

        guard
            accumulator.rowCount == rowCount,
            try context.count(for: countRequest) == rowCount
        else {
            throw UserStorageMigrationError
                .stagedStoreValidationFailed
        }

        return accumulator.digest
    }

    private func validateSemanticStrings(
        _ values: [String],
        maximumCount: Int? = nil
    ) throws {
        if let maximumCount {
            guard values.count <= maximumCount else {
                throw UserStorageMigrationError
                    .stagedStoreValidationFailed
            }
        }

        var cumulativeByteCount = 0
        for value in values {
            let byteCount = value.utf8.count
            guard
                byteCount <=
                integrityValidationLimits.maximumAttributeBytes,
                cumulativeByteCount <=
                integrityValidationLimits.maximumCanonicalRowBytes -
                byteCount
            else {
                throw UserStorageMigrationError
                    .stagedStoreValidationFailed
            }
            cumulativeByteCount += byteCount
        }
    }

    private func canonicalSemanticStrings(
        _ values: [String?]
    ) throws -> String {
        try validateSemanticStrings(values.compactMap { $0 })

        return values.map { value in
            guard let value else {
                return "nil"
            }

            return "value:" +
                Data(value.utf8).base64EncodedString()
        }.joined(separator: "|")
    }

    private func shouldValidateMetaAccountCount(
        from sourceVersion: UserStorageVersion
    ) -> Bool {
        sourceVersion != .version1
    }

    private func stagedMetaAccountCount(
        at storeURL: URL,
        model: NSManagedObjectModel
    ) throws -> Int {
        guard model.entitiesByName["CDMetaAccount"] != nil else {
            throw UserStorageMigrationError.stagedStoreValidationFailed
        }

        let coordinator = NSPersistentStoreCoordinator(
            managedObjectModel: model
        )
        var persistentStore: NSPersistentStore?

        try performWithObjectiveCExceptionBoundary(
            phase: "staged wallet-count validation open"
        ) {
            persistentStore = try coordinator.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: storeURL,
                options: [
                    NSMigratePersistentStoresAutomaticallyOption: false,
                    NSInferMappingModelAutomaticallyOption: false
                ]
            )
        }

        defer {
            if let persistentStore {
                try? coordinator.remove(persistentStore)
            }
        }

        let context = NSManagedObjectContext(
            concurrencyType: .privateQueueConcurrencyType
        )
        context.persistentStoreCoordinator = coordinator

        var count: Int?
        var contextError: Error?
        context.performAndWait {
            do {
                try self.performWithObjectiveCExceptionBoundary(
                    phase: "staged wallet-count validation read"
                ) {
                    let request =
                        NSFetchRequest<NSFetchRequestResult>(
                            entityName: "CDMetaAccount"
                        )
                    request.includesPendingChanges = false
                    request.includesSubentities = false
                    let fetchedCount = try context.count(for: request)

                    guard
                        fetchedCount != NSNotFound,
                        fetchedCount <=
                        self.integrityValidationLimits
                        .maximumRowsPerEntity,
                        fetchedCount <=
                        self.integrityValidationLimits
                        .maximumRowsAcrossStore
                    else {
                        throw UserStorageMigrationError
                            .stagedStoreValidationFailed
                    }

                    count = fetchedCount
                }
            } catch {
                contextError = error
            }
        }

        if let contextError {
            throw contextError
        }

        guard let count else {
            throw UserStorageMigrationError.stagedStoreValidationFailed
        }

        return count
    }

    private func stagedStoreIntegritySnapshot(
        at storeURL: URL,
        model: NSManagedObjectModel,
        comparedWith comparisonModel: NSManagedObjectModel,
        allowlist: StagedStoreIntegrityAllowlist = .none
    ) throws -> StagedStoreIntegritySnapshot {
        let coordinator = NSPersistentStoreCoordinator(
            managedObjectModel: model
        )
        var persistentStore: NSPersistentStore?

        try performWithObjectiveCExceptionBoundary(
            phase: "staged store validation open"
        ) {
            persistentStore = try coordinator.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: storeURL,
                options: [
                    NSMigratePersistentStoresAutomaticallyOption: false,
                    NSInferMappingModelAutomaticallyOption: false
                ]
            )
        }

        defer {
            if let persistentStore {
                try? coordinator.remove(persistentStore)
            }
        }

        let context = NSManagedObjectContext(
            concurrencyType: .privateQueueConcurrencyType
        )
        context.persistentStoreCoordinator = coordinator

        var snapshot: StagedStoreIntegritySnapshot?
        var contextError: Error?
        context.performAndWait {
            do {
                try self.performWithObjectiveCExceptionBoundary(
                    phase: "staged store validation read"
                ) {
                    snapshot = try self.makeStagedStoreIntegritySnapshot(
                        context: context,
                        model: model,
                        comparedWith: comparisonModel,
                        allowlist: allowlist
                    )
                }
            } catch {
                contextError = error
            }
        }

        if let contextError {
            throw contextError
        }

        guard let snapshot else {
            throw UserStorageMigrationError.stagedStoreValidationFailed
        }

        return snapshot
    }

    private func makeStagedStoreIntegritySnapshot(
        context: NSManagedObjectContext,
        model: NSManagedObjectModel,
        comparedWith comparisonModel: NSManagedObjectModel,
        allowlist: StagedStoreIntegrityAllowlist
    ) throws -> StagedStoreIntegritySnapshot {
        let commonEntityNames = Set(model.entitiesByName.keys)
            .intersection(comparisonModel.entitiesByName.keys)
            .subtracting(allowlist.entityNames)
            .sorted()
        var rowsByEntity = [String: IntegrityDigest]()
        var totalRowCount = 0
        var totalRelationshipDestinationCount = 0

        for entityName in commonEntityNames {
            let attributeNames = try commonAttributeNames(
                entityName: entityName,
                model: model,
                comparedWith: comparisonModel,
                excluding:
                allowlist.attributeNamesByEntity[entityName] ?? []
            )
            let relationshipNames =
                try commonRelationshipNames(
                    entityName: entityName,
                    model: model,
                    comparedWith: comparisonModel,
                    excluding:
                    allowlist.relationshipNamesByEntity[entityName] ?? []
                )
            let countRequest =
                NSFetchRequest<NSFetchRequestResult>(
                    entityName: entityName
                )
            countRequest.includesPendingChanges = false
            countRequest.includesSubentities = false
            let rowCount = try context.count(for: countRequest)
            guard
                rowCount != NSNotFound,
                rowCount < Int.max,
                rowCount <=
                integrityValidationLimits.maximumRowsPerEntity,
                totalRowCount <=
                integrityValidationLimits.maximumRowsAcrossStore -
                rowCount
            else {
                throw UserStorageMigrationError
                    .stagedStoreValidationFailed
            }
            totalRowCount += rowCount

            let identifierRequest =
                NSFetchRequest<NSFetchRequestResult>(
                    entityName: entityName
                )
            identifierRequest.resultType =
                .managedObjectIDResultType
            identifierRequest.includesPendingChanges = false
            identifierRequest.includesSubentities = false
            identifierRequest.fetchLimit = rowCount + 1
            identifierRequest.fetchBatchSize = min(
                integrityValidationLimits.fetchBatchSize,
                rowCount + 1
            )
            let fetchedIdentifiers =
                try context.fetch(identifierRequest)
            let objectIDs = fetchedIdentifiers.compactMap {
                $0 as? NSManagedObjectID
            }
            guard
                objectIDs.count == fetchedIdentifiers.count,
                objectIDs.count == rowCount,
                Set(objectIDs).count == rowCount
            else {
                throw UserStorageMigrationError
                    .stagedStoreValidationFailed
            }

            var accumulator = IntegrityDigestAccumulator()
            var pageStart = 0

            while pageStart < objectIDs.count {
                let remainingObjectCount =
                    objectIDs.count - pageStart
                let pageLength = min(
                    integrityValidationLimits.fetchBatchSize,
                    remainingObjectCount
                )
                let pageEnd = pageStart + pageLength
                let pageObjectIDs = Array(
                    objectIDs[pageStart ..< pageEnd]
                )
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
                let objects = try context.fetch(request)
                integrityObjectPageDidFetch(
                    objects.count,
                    pageObjectIDs.count
                )

                guard
                    objects.count == pageObjectIDs.count,
                    Set(objects.map(\.objectID)) ==
                    Set(pageObjectIDs)
                else {
                    throw UserStorageMigrationError
                        .stagedStoreValidationFailed
                }

                for object in objects {
                    let row = try integrityRow(
                        for: object,
                        entityName: entityName,
                        attributeNames: attributeNames,
                        relationshipNames: relationshipNames,
                        model: model,
                        comparedWith: comparisonModel,
                        allowlist: allowlist,
                        totalRelationshipDestinationCount:
                        &totalRelationshipDestinationCount
                    )
                    let canonicalRow = row.sortKey
                    guard
                        canonicalRow.utf8.count <=
                        integrityValidationLimits
                        .maximumCanonicalRowBytes
                    else {
                        throw UserStorageMigrationError
                            .stagedStoreValidationFailed
                    }
                    accumulator.append(canonicalRow: canonicalRow)
                }

                pageStart = pageEnd
                context.reset()
            }

            guard
                accumulator.rowCount == rowCount,
                try context.count(for: countRequest) == rowCount
            else {
                throw UserStorageMigrationError
                    .stagedStoreValidationFailed
            }
            rowsByEntity[entityName] = accumulator.digest
        }

        return StagedStoreIntegritySnapshot(
            rowsByEntity: rowsByEntity
        )
    }

    private func commonAttributeNames(
        entityName: String,
        model: NSManagedObjectModel,
        comparedWith comparisonModel: NSManagedObjectModel,
        excluding excludedNames: Set<String>
    ) throws -> [String] {
        guard
            let entity = model.entitiesByName[entityName],
            let comparisonEntity =
            comparisonModel.entitiesByName[entityName]
        else {
            throw UserStorageMigrationError
                .stagedStoreValidationFailed
        }

        let names = Set(entity.attributesByName.keys)
            .intersection(comparisonEntity.attributesByName.keys)
            .subtracting(excludedNames)
            .sorted()

        for name in names {
            guard
                entity.attributesByName[name]?.attributeType ==
                comparisonEntity.attributesByName[name]?.attributeType
            else {
                throw UserStorageMigrationError
                    .stagedStoreValidationFailed
            }
        }

        return names
    }

    private func commonRelationshipNames(
        entityName: String,
        model: NSManagedObjectModel,
        comparedWith comparisonModel: NSManagedObjectModel,
        excluding excludedNames: Set<String>
    ) throws -> [String] {
        guard
            let entity = model.entitiesByName[entityName],
            let comparisonEntity =
            comparisonModel.entitiesByName[entityName]
        else {
            throw UserStorageMigrationError
                .stagedStoreValidationFailed
        }

        let names = Set(entity.relationshipsByName.keys)
            .intersection(
                comparisonEntity.relationshipsByName.keys
            )
            .subtracting(excludedNames)
            .sorted()

        for name in names {
            guard
                let relationship =
                entity.relationshipsByName[name],
                let comparisonRelationship =
                comparisonEntity.relationshipsByName[name],
                relationship.isToMany ==
                comparisonRelationship.isToMany,
                relationship.isOrdered ==
                comparisonRelationship.isOrdered,
                relationship.destinationEntity?.name ==
                comparisonRelationship.destinationEntity?.name,
                let destinationName =
                relationship.destinationEntity?.name,
                model.entitiesByName[destinationName] != nil,
                comparisonModel.entitiesByName[destinationName] != nil
            else {
                throw UserStorageMigrationError
                    .stagedStoreValidationFailed
            }
        }

        return names
    }

    private func integrityRow(
        for object: NSManagedObject,
        entityName: String,
        attributeNames: [String],
        relationshipNames: [String],
        model: NSManagedObjectModel,
        comparedWith comparisonModel: NSManagedObjectModel,
        allowlist: StagedStoreIntegrityAllowlist,
        totalRelationshipDestinationCount: inout Int
    ) throws -> IntegrityRow {
        let identity = try integrityIdentity(
            for: object,
            entityName: entityName,
            attributeNames: attributeNames,
            model: model
        )
        let identityByteCount = identity.sortKey.utf8.count
        guard
            identityByteCount <=
            integrityValidationLimits.maximumCanonicalRowBytes
        else {
            throw UserStorageMigrationError
                .stagedStoreValidationFailed
        }

        var relationships = [IntegrityRelationship]()
        var cumulativeByteCount = identityByteCount
        for relationshipName in relationshipNames {
            let relationship = try integrityRelationship(
                for: object,
                entityName: entityName,
                relationshipName: relationshipName,
                model: model,
                comparedWith: comparisonModel,
                allowlist: allowlist,
                totalRelationshipDestinationCount:
                &totalRelationshipDestinationCount
            )
            let relationshipByteCount =
                relationship.sortKey.utf8.count
            guard
                relationshipByteCount <=
                integrityValidationLimits.maximumCanonicalRowBytes,
                cumulativeByteCount <=
                integrityValidationLimits.maximumCanonicalRowBytes -
                relationshipByteCount
            else {
                throw UserStorageMigrationError
                    .stagedStoreValidationFailed
            }
            cumulativeByteCount += relationshipByteCount
            relationships.append(relationship)
        }

        return IntegrityRow(
            identity: identity,
            relationships: relationships
        )
    }

    private func integrityRelationship(
        for object: NSManagedObject,
        entityName: String,
        relationshipName: String,
        model: NSManagedObjectModel,
        comparedWith comparisonModel: NSManagedObjectModel,
        allowlist: StagedStoreIntegrityAllowlist,
        totalRelationshipDestinationCount: inout Int
    ) throws -> IntegrityRelationship {
        guard
            let relationship =
            model.entitiesByName[entityName]?
                .relationshipsByName[relationshipName],
                let comparisonRelationship =
                comparisonModel.entitiesByName[entityName]?
                    .relationshipsByName[relationshipName],
                    relationship.isToMany ==
                    comparisonRelationship.isToMany,
                    relationship.isOrdered ==
                    comparisonRelationship.isOrdered,
                    let destinationName =
                    relationship.destinationEntity?.name,
                    destinationName ==
                    comparisonRelationship.destinationEntity?.name
        else {
            throw UserStorageMigrationError
                .stagedStoreValidationFailed
        }

        let relatedObjects: [NSManagedObject]
        if relationship.isToMany {
            let preflightCount =
                try preflightRelationshipDestinationCount(
                    for: object,
                    relationshipName: relationshipName
                )
            guard
                preflightCount <=
                integrityValidationLimits
                .maximumRelationshipDestinations
            else {
                throw UserStorageMigrationError
                    .stagedStoreValidationFailed
            }
            try accumulateRelationshipDestinationCount(
                preflightCount,
                total: &totalRelationshipDestinationCount
            )

            if preflightCount == 0 {
                relatedObjects = []
            } else {
                let value = object.value(
                    forKey: relationshipName
                )
                if relationship.isOrdered,
                   let orderedSet = value as? NSOrderedSet {
                    relatedObjects =
                        orderedSet.array.compactMap {
                            $0 as? NSManagedObject
                        }
                    guard
                        orderedSet.count == preflightCount,
                        relatedObjects.count == preflightCount
                    else {
                        throw UserStorageMigrationError
                            .stagedStoreValidationFailed
                    }
                } else if !relationship.isOrdered,
                          let set = value as? NSSet {
                    relatedObjects =
                        set.allObjects.compactMap {
                            $0 as? NSManagedObject
                        }
                    guard
                        set.count == preflightCount,
                        relatedObjects.count == preflightCount
                    else {
                        throw UserStorageMigrationError
                            .stagedStoreValidationFailed
                    }
                } else {
                    throw UserStorageMigrationError
                        .stagedStoreValidationFailed
                }
            }
        } else {
            let value = object.value(forKey: relationshipName)
            if let relatedObject = value as? NSManagedObject {
                relatedObjects = [relatedObject]
            } else if value == nil {
                relatedObjects = []
            } else {
                throw UserStorageMigrationError
                    .stagedStoreValidationFailed
            }
        }

        let destinationAttributeNames =
            try commonAttributeNames(
                entityName: destinationName,
                model: model,
                comparedWith: comparisonModel,
                excluding:
                allowlist.attributeNamesByEntity[destinationName] ?? []
            )
        var destinations = [IntegrityIdentity]()
        var cumulativeDestinationByteCount = 0
        for relatedObject in relatedObjects {
            guard relatedObject.entity.name == destinationName else {
                throw UserStorageMigrationError
                    .stagedStoreValidationFailed
            }

            let destination = try integrityIdentity(
                for: relatedObject,
                entityName: destinationName,
                attributeNames: destinationAttributeNames,
                model: model
            )
            let destinationByteCount =
                destination.sortKey.utf8.count
            guard
                destinationByteCount <=
                integrityValidationLimits.maximumCanonicalRowBytes,
                cumulativeDestinationByteCount <=
                integrityValidationLimits.maximumCanonicalRowBytes -
                destinationByteCount
            else {
                throw UserStorageMigrationError
                    .stagedStoreValidationFailed
            }
            cumulativeDestinationByteCount += destinationByteCount
            destinations.append(destination)
        }

        if !relationship.isOrdered {
            destinations.sort {
                $0.sortKey < $1.sortKey
            }
        }

        return IntegrityRelationship(
            name: relationshipName,
            destinations: destinations
        )
    }

    func accumulateRelationshipDestinationCount(
        _ count: Int,
        total: inout Int
    ) throws {
        guard count >= 0, total >= 0 else {
            throw UserStorageMigrationError
                .stagedStoreValidationFailed
        }
        let addition = total.addingReportingOverflow(count)
        guard
            !addition.overflow,
            addition.partialValue <=
            integrityValidationLimits
            .maximumRelationshipDestinationsAcrossStore
        else {
            throw UserStorageMigrationError
                .stagedStoreValidationFailed
        }

        total = addition.partialValue
    }

    func preflightRelationshipDestinationCount(
        for object: NSManagedObject,
        relationshipName: String
    ) throws -> Int {
        guard
            let context = object.managedObjectContext,
            let entityName = object.entity.name,
            let relationship =
            object.entity.relationshipsByName[relationshipName],
            relationship.isToMany
        else {
            throw UserStorageMigrationError
                .stagedStoreValidationFailed
        }
        guard
            let persistentStore =
            object.objectID.persistentStore
        else {
            throw UserStorageMigrationError
                .stagedStoreValidationFailed
        }

        let countDescription = NSExpressionDescription()
        countDescription.name = "relationshipDestinationCount"
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
            let number =
            rows[0][countDescription.name] as? NSNumber
        else {
            throw UserStorageMigrationError
                .stagedStoreValidationFailed
        }

        let count = number.int64Value
        guard
            count >= 0,
            UInt64(count) <= UInt64(Int.max)
        else {
            throw UserStorageMigrationError
                .stagedStoreValidationFailed
        }

        return Int(count)
    }

    private func integrityIdentity(
        for object: NSManagedObject,
        entityName: String,
        attributeNames: [String],
        model: NSManagedObjectModel
    ) throws -> IntegrityIdentity {
        guard
            object.entity.name == entityName,
            let entity = model.entitiesByName[entityName]
        else {
            throw UserStorageMigrationError
                .stagedStoreValidationFailed
        }

        var fields = [IntegrityField]()
        var cumulativeFieldByteCount =
            Data(entityName.utf8).base64EncodedString().utf8.count

        for attributeName in attributeNames {
            guard
                let attribute =
                entity.attributesByName[attributeName]
            else {
                throw UserStorageMigrationError
                    .stagedStoreValidationFailed
            }

            let field = IntegrityField(
                name: attributeName,
                value: try canonicalIntegrityValue(
                    from: object,
                    entityName: entityName,
                    attribute: attribute
                )
            )
            let fieldByteCount = field.sortKey.utf8.count
            guard
                fieldByteCount <=
                integrityValidationLimits.maximumCanonicalRowBytes,
                cumulativeFieldByteCount <=
                integrityValidationLimits.maximumCanonicalRowBytes -
                fieldByteCount
            else {
                throw UserStorageMigrationError
                    .stagedStoreValidationFailed
            }
            cumulativeFieldByteCount += fieldByteCount
            fields.append(field)
        }

        return IntegrityIdentity(
            entityName: entityName,
            fields: fields
        )
    }

    private func canonicalIntegrityValue(
        from object: NSManagedObject,
        entityName: String,
        attribute: NSAttributeDescription
    ) throws -> String {
        if attribute.attributeType ==
            .transformableAttributeType {
            guard
                entityName == "CDMetaAccount",
                Self.resilientMetaAccountTransformableKeys
                .contains(attribute.name)
            else {
                throw UserStorageMigrationError
                    .stagedStoreValidationFailed
            }

            let value: [String]? =
                try SafeTransformableValueReader.read(
                    from: object,
                    key: attribute.name
                )

            guard let value else {
                return "nil"
            }

            guard
                value.count <=
                integrityValidationLimits
                .maximumTransformableElements
            else {
                throw UserStorageMigrationError
                    .stagedStoreValidationFailed
            }
            var cumulativeByteCount = 0
            for item in value {
                let itemByteCount = item.utf8.count
                guard
                    itemByteCount <=
                    integrityValidationLimits.maximumAttributeBytes,
                    cumulativeByteCount <=
                    integrityValidationLimits.maximumAttributeBytes -
                    itemByteCount
                else {
                    throw UserStorageMigrationError
                        .stagedStoreValidationFailed
                }
                cumulativeByteCount += itemByteCount
            }

            return "string-array:" + value.map {
                Data($0.utf8).base64EncodedString()
            }.joined(separator: ",")
        }

        let value = object.value(forKey: attribute.name)

        guard let value else {
            return "nil"
        }

        if let value = value as? String {
            guard
                value.utf8.count <=
                integrityValidationLimits.maximumAttributeBytes
            else {
                throw UserStorageMigrationError
                    .stagedStoreValidationFailed
            }
            return "string:\(Data(value.utf8).base64EncodedString())"
        }

        if let value = value as? Data {
            guard
                value.count <=
                integrityValidationLimits.maximumAttributeBytes
            else {
                throw UserStorageMigrationError
                    .stagedStoreValidationFailed
            }
            return "data:\(value.base64EncodedString())"
        }

        if let value = value as? NSNumber {
            return "number:\(value.stringValue)"
        }

        if let value = value as? Date {
            return "date:\(value.timeIntervalSinceReferenceDate.bitPattern)"
        }

        if let value = value as? URL {
            guard
                value.absoluteString.utf8.count <=
                integrityValidationLimits.maximumAttributeBytes
            else {
                throw UserStorageMigrationError
                    .stagedStoreValidationFailed
            }
            return "url:\(Data(value.absoluteString.utf8).base64EncodedString())"
        }

        if let value = value as? UUID {
            return "uuid:\(value.uuidString)"
        }

        throw UserStorageMigrationError.stagedStoreValidationFailed
    }

    private func sanitizePreferenceTransformables(
        objectID: NSManagedObjectID,
        model: NSManagedObjectModel,
        context: NSManagedObjectContext,
        persistentStore: NSPersistentStore?
    ) throws -> Bool {
        guard let entity = model.entitiesByName["CDMetaAccount"] else {
            return false
        }

        var didRepair = false
        for key in Self.resilientMetaAccountTransformableKeys {
            guard
                let attribute = entity.attributesByName[key],
                attribute.attributeType == .transformableAttributeType
            else {
                continue
            }

            let needsRepair: Bool
            let request = NSFetchRequest<NSDictionary>(
                entityName: "CDMetaAccount"
            )
            request.resultType = .dictionaryResultType
            request.propertiesToFetch = [key]
            request.predicate = NSPredicate(
                format: "SELF == %@",
                objectID
            )
            request.affectedStores = persistentStore.map { [$0] }
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
                    throw UserStorageMigrationError
                        .privateSourceRepairFailed
                }

                let value = rows[0][key]
                if value == nil || value is NSNull {
                    needsRepair = !attribute.isOptional
                } else if let strings = value as? [String] {
                    needsRepair =
                        !isBoundedPreferenceStringArray(strings)
                } else {
                    needsRepair = true
                }
            } catch is SafeTransformableValueReaderError {
                needsRepair = true
            } catch let error as NSError
                where error.domain == NSCocoaErrorDomain &&
                error.code == NSCoderReadCorruptError {
                needsRepair = true
            }

            // A failed transformable decode can leave fetched state unusable.
            // Discard it before issuing a store-level repair.
            context.reset()

            guard needsRepair else {
                continue
            }

            // NSBatchUpdateRequest writes the replacement directly to the
            // disposable store. No managed object is changed or saved, so
            // Core Data never attempts to decode the corrupt prior archive.
            guard !context.hasChanges else {
                throw UserStorageMigrationError.privateSourceRepairFailed
            }

            let update = NSBatchUpdateRequest(
                entityName: "CDMetaAccount"
            )
            update.affectedStores = persistentStore.map { [$0] }
            update.predicate = NSPredicate(
                format: "SELF == %@",
                objectID
            )
            update.propertiesToUpdate = [key: NSArray()]
            update.resultType = .updatedObjectIDsResultType

            let result = try context.execute(update)
            guard
                let batchResult = result as? NSBatchUpdateResult,
                let updatedObjectIDs =
                batchResult.result as? [NSManagedObjectID],
                updatedObjectIDs == [objectID]
            else {
                throw UserStorageMigrationError.privateSourceRepairFailed
            }

            context.reset()
            didRepair = true
        }

        return didRepair
    }

    private func isBoundedPreferenceStringArray(
        _ value: [String]
    ) -> Bool {
        guard
            value.count <=
            integrityValidationLimits
            .maximumTransformableElements
        else {
            return false
        }

        var cumulativeByteCount = 0
        for item in value {
            let itemByteCount = item.utf8.count
            guard
                itemByteCount <=
                integrityValidationLimits.maximumAttributeBytes,
                cumulativeByteCount <=
                integrityValidationLimits.maximumAttributeBytes -
                itemByteCount
            else {
                return false
            }
            cumulativeByteCount += itemByteCount
        }

        return true
    }

    private func performWithObjectiveCExceptionBoundary(
        phase: String,
        _ operation: @escaping () throws -> Void
    ) throws {
        do {
            try SafeObjectiveCExceptionBoundary.perform(operation)
        } catch SafeTransformableValueReaderError.objectiveCException {
            Logger.shared.error(
                "User-storage recovery safely stopped during \(phase)"
            )
            throw UserStorageMigrationError.objectiveCException
        } catch {
            throw error
        }
    }

    private func checkIfMigrationNeeded(to version: UserStorageVersion) -> Bool {
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
            return try withPrivateSourceCopy {
                privateSourceURL,
                    _ in

                let sourceVersion = try readSourceVersion(
                    at: privateSourceURL
                )
                guard sourceVersion == version else {
                    return true
                }

                return try sanitizePrivateSourceCopy(
                    at: privateSourceURL,
                    version: sourceVersion
                )
            }
        } catch {
            return true
        }
    }

    private func compatibleVersionForStoreMetadata(_ metadata: [String: Any]) -> UserStorageVersion? {
        let compatibleVersion = UserStorageVersion.allCases.first {
            guard let model = try? createManagedObjectModel(for: $0) else {
                return false
            }

            return model.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
        }

        return compatibleVersion
    }

    private func createManagedObjectModel(
        for version: UserStorageVersion
    ) throws -> NSManagedObjectModel {
        guard
            let modelURL = version.modelURL(
                in: modelBundle,
                legacyModelDirectory: modelDirectory
            ),
            let model = NSManagedObjectModel(contentsOf: modelURL) else {
            throw UserStorageMigrationError.modelUnavailable(version)
        }

        return model
    }

    private func createMapping(
        from sourceModel: NSManagedObjectModel,
        nextModel: NSManagedObjectModel
    ) throws -> NSMappingModel {
        let maybeCustomMapping = NSMappingModel(
            from: [modelBundle],
            forSourceModel: sourceModel,
            destinationModel: nextModel
        )

        if let customMapping = maybeCustomMapping {
            return customMapping
        }

        return try NSMappingModel.inferredMappingModel(
            forSourceModel: sourceModel,
            destinationModel: nextModel
        )
    }
}

extension UserStorageMigrator: StorageMigrating {
    func requiresMigration() -> Bool {
        checkIfMigrationNeeded(to: targetVersion)
    }

    func migrate(_ completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else {
                return
            }

            do {
                try self.performMigration()
            } catch {
                Logger.shared.error(
                    "User-storage migration failed safely"
                )
                return
            }

            DispatchQueue.main.async {
                completion()
            }
        }
    }
}
