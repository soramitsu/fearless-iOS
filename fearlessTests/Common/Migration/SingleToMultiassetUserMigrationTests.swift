import XCTest
import CoreData
import RobinHood
import SSFUtils
import SSFCrypto
import IrohaCrypto
import SoraKeystore
@testable import fearless

class SingleToMultiassetUserMigrationTests: XCTestCase {
    enum MigrationTestError: Error {
        case coreData(String)
    }

    struct OldAccount {
        let address: String
        let cryptoType: UInt8
        let name: String
        let privateKey: Data
        let publicKey: Data
        let entropy: Data?
        let derivationPath: String?
        let seed: Data?
    }

    struct NewEntity {
        let metaId: String
        let name: String
        let isSelected: Bool
        let substrateAccountId: String
        let substratePublicKey: Data
        let substrateCryptoType: UInt8
        let ethereumAddress: String?
        let ethereumPublicKey: Data?
        let order: Int32
    }

    enum DuplicateRowOrder {
        case watchOnlyFirst
        case signerFirst
    }

    enum ConflictingRowOrder {
        case firstAliasFirst
        case secondAliasFirst
    }

    let databaseDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("CoreData")
    let databaseName = UUID().uuidString + ".sqlite"
    let modelDirectory = UserStorageParams.modelDirectory

    var storeURL: URL {
        databaseDirectory.appendingPathComponent(databaseName)
    }

    override func setUp() {
        super.setUp()

        try? FileManager.default.removeItem(at: databaseDirectory)
    }

    override func tearDown() {
        super.tearDown()

        try? FileManager.default.removeItem(at: databaseDirectory)
    }

    func testMigrationForCreatedAccountWithoutDerivPath() throws {
        try performTestUserMigration(
            hasEntropy: true,
            hasSeed: true,
            hasDerivationPath: false
        )
    }

    func testMigrationForCreatedAccountWithDerivPath() throws {
        try performTestUserMigration(
            hasEntropy: true,
            hasSeed: true,
            hasDerivationPath: true
        )
    }

    func testMigrationForImportedWithSeedAccountWithoutDerivPath() throws {
        try performTestUserMigration(
            hasEntropy: false,
            hasSeed: true,
            hasDerivationPath: false
        )
    }

    func testMigrationForImportedWithSeedAccountWithDerivPath() throws {
        try performTestUserMigration(
            hasEntropy: false,
            hasSeed: true,
            hasDerivationPath: true
        )
    }

    func testMigrationForImportedWithJSONAccountWithoutDerivPath() throws {
        try performTestUserMigration(
            hasEntropy: false,
            hasSeed: false,
            hasDerivationPath: false
        )
    }

    func testMigrationForImportedWithJSONAccountWithDerivPath() throws {
        try performTestUserMigration(
            hasEntropy: false,
            hasSeed: false,
            hasDerivationPath: true
        )
    }

    func testMigrationFromV1ToCurrentForCreatedAccountWithDerivationPath() throws {
        try performTestUserMigration(
            hasEntropy: true,
            hasSeed: true,
            hasDerivationPath: true,
            targetVersion: .current
        )
    }

    func testMigrationFromV1ToCurrentForImportedJSONAccount() throws {
        try performTestUserMigration(
            hasEntropy: false,
            hasSeed: false,
            hasDerivationPath: false,
            targetVersion: .current
        )
    }

    func testDuplicateAccountMigration_whenWatchOnlyRowIsInsertedFirst_thenSigningSecretsArePreserved() throws {
        try performDuplicateSignerMigration(rowOrder: .watchOnlyFirst)
    }

    func testDuplicateAccountMigration_whenSigningRowIsInsertedFirst_thenSigningSecretsArePreserved() throws {
        try performDuplicateSignerMigration(rowOrder: .signerFirst)
    }

    func testDuplicateAccountMigration_whenFirstAliasHasConflictingSecret_thenFailsWithoutReplacingStore() throws {
        try performConflictingDuplicateMigration(rowOrder: .firstAliasFirst)
    }

    func testDuplicateAccountMigration_whenSecondAliasHasConflictingSecret_thenFailsWithoutReplacingStore() throws {
        try performConflictingDuplicateMigration(rowOrder: .secondAliasFirst)
    }

    func testKeystoreResourceLimits_atEveryExactBoundary_prepareSucceeds() throws {
        let account = try generateOldAccount(
            hasEntropy: false,
            hasSeed: false,
            hasDerivationPath: false
        )
        let firstMetaId = "00000000-0000-4000-8000-000000000001"
        let secondMetaId = "00000000-0000-4000-8000-000000000002"
        let firstDestinationIdentifier =
            KeystoreTagV2.substrateSecretKeyTagForMetaId(firstMetaId)
        let secondDestinationIdentifier =
            KeystoreTagV2.substrateSeedTagForMetaId(secondMetaId)
        let legacyIdentifier =
            KeystoreTag.secretKeyTagForAddress(account.address)
        let firstKey = Data([0x01, 0x02, 0x03])
        let secondKey = Data([0x04, 0x05])
        let aggregateIdentifierBytes = [
            firstDestinationIdentifier,
            secondDestinationIdentifier,
            legacyIdentifier
        ].reduce(0) { $0 + $1.utf8.count }
        let stagedKeyBytes = firstKey.count + secondKey.count
        let calibrationLimits = makeResourceLimits(
            maximumLegacyAccountRows: 2,
            maximumStagedKeyCount: 2,
            maximumIdentifierUTF8Bytes: aggregateIdentifierBytes,
            maximumStagedKeyBytes: stagedKeyBytes,
            maximumDeletionCount: 1,
            maximumCleanupJournalBytes: Int.max
        )
        let calibrationKeystore = InMemoryKeychain()
        let calibrationMigrator = KeystoreMigrator(
            sourceVersion: .version1,
            destinationVersion: .version2,
            keystore: calibrationKeystore,
            resourceLimits: calibrationLimits
        )

        try stageExactBoundaryFixture(
            in: calibrationMigrator,
            firstIdentifier: firstDestinationIdentifier,
            firstKey: firstKey,
            secondIdentifier: secondDestinationIdentifier,
            secondKey: secondKey,
            legacyIdentifier: legacyIdentifier
        )
        try calibrationMigrator.prepare()
        let encodedJournal = try calibrationKeystore.fetchKey(
            for: KeystoreMigrator.pendingCleanupIdentifier
        )

        let exactLimits = makeResourceLimits(
            maximumLegacyAccountRows: 2,
            maximumStagedKeyCount: 2,
            maximumIdentifierUTF8Bytes: aggregateIdentifierBytes,
            maximumStagedKeyBytes: stagedKeyBytes,
            maximumDeletionCount: 1,
            maximumCleanupJournalBytes: encodedJournal.count
        )
        let exactKeystore = InMemoryKeychain()
        try exactKeystore.saveKey(
            account.privateKey,
            with: legacyIdentifier
        )
        let exactMigrator = KeystoreMigrator(
            sourceVersion: .version1,
            destinationVersion: .version2,
            keystore: exactKeystore,
            resourceLimits: exactLimits
        )

        try stageExactBoundaryFixture(
            in: exactMigrator,
            firstIdentifier: firstDestinationIdentifier,
            firstKey: firstKey,
            secondIdentifier: secondDestinationIdentifier,
            secondKey: secondKey,
            legacyIdentifier: legacyIdentifier
        )
        try exactMigrator.prepare()

        XCTAssertEqual(
            try exactKeystore.fetchKey(
                for: KeystoreMigrator.pendingCleanupIdentifier
            ).count,
            encodedJournal.count
        )
        XCTAssertEqual(
            try exactKeystore.fetchKey(
                for: firstDestinationIdentifier
            ),
            firstKey
        )
        XCTAssertEqual(
            try exactKeystore.fetchKey(
                for: secondDestinationIdentifier
            ),
            secondKey
        )

        try exactMigrator.finalize()

        XCTAssertFalse(try exactKeystore.checkKey(for: legacyIdentifier))
        XCTAssertFalse(
            try exactKeystore.checkKey(
                for: KeystoreMigrator.pendingCleanupIdentifier
            )
        )
    }

    func testKeystoreResourceLimits_whenLegacyRowLimitExceeded_freezesAndFailsBeforePrepareWrites() throws {
        let keystore = InMemoryKeychain()
        let migrator = KeystoreMigrator(
            sourceVersion: .version1,
            destinationVersion: .version2,
            keystore: keystore,
            resourceLimits: makeResourceLimits(
                maximumLegacyAccountRows: 1
            )
        )
        let destinationIdentifier =
            KeystoreTagV2.substrateSecretKeyTagForMetaId(
                "00000000-0000-4000-8000-000000000010"
            )

        try migrator.switchVersion()
        try migrator.registerLegacyAccountRow()
        XCTAssertThrowsError(
            try migrator.registerLegacyAccountRow()
        ) { error in
            self.assertResourceLimitError(
                error,
                resource: .legacyAccountRows,
                maximum: 1
            )
        }

        migrator.save(key: Data([0x01]), for: destinationIdentifier)

        XCTAssertTrue(migrator.tempKeystore.isEmpty)
        assertPrepareFailsClosed(
            migrator,
            keystore: keystore,
            resource: .legacyAccountRows,
            maximum: 1
        )
    }

    func testKeystoreResourceLimits_whenStagedKeyCountExceeded_freezesAndFailsBeforePrepareWrites() throws {
        let keystore = InMemoryKeychain()
        let migrator = makeVersion2KeystoreMigrator(
            keystore: keystore,
            resourceLimits: makeResourceLimits(
                maximumStagedKeyCount: 1
            )
        )
        let firstIdentifier =
            KeystoreTagV2.substrateSecretKeyTagForMetaId(
                "00000000-0000-4000-8000-000000000011"
            )
        let rejectedIdentifier =
            KeystoreTagV2.substrateSeedTagForMetaId(
                "00000000-0000-4000-8000-000000000012"
            )

        migrator.save(key: Data([0x01]), for: firstIdentifier)
        migrator.save(key: Data([0x02]), for: rejectedIdentifier)
        migrator.deleteKey(for: "ignored-after-first-limit")

        XCTAssertEqual(migrator.tempKeystore, [firstIdentifier: Data([0x01])])
        XCTAssertTrue(migrator.identifiersToRemoveOnFinalize.isEmpty)
        assertPrepareFailsClosed(
            migrator,
            keystore: keystore,
            resource: .stagedKeyCount,
            maximum: 1
        )
        XCTAssertFalse(try keystore.checkKey(for: firstIdentifier))
        XCTAssertFalse(try keystore.checkKey(for: rejectedIdentifier))
    }

    func testKeystoreResourceLimits_whenIdentifierBytesExceeded_freezesAndFailsBeforePrepareWrites() throws {
        let keystore = InMemoryKeychain()
        let identifier =
            KeystoreTagV2.substrateSecretKeyTagForMetaId(
                "00000000-0000-4000-8000-000000000013"
            )
        let maximum = identifier.utf8.count - 1
        let migrator = makeVersion2KeystoreMigrator(
            keystore: keystore,
            resourceLimits: makeResourceLimits(
                maximumIdentifierUTF8Bytes: maximum
            )
        )

        migrator.save(key: Data([0x01]), for: identifier)
        migrator.deleteKey(for: "ignored-after-first-limit")

        XCTAssertTrue(migrator.tempKeystore.isEmpty)
        XCTAssertTrue(migrator.identifiersToRemoveOnFinalize.isEmpty)
        assertPrepareFailsClosed(
            migrator,
            keystore: keystore,
            resource: .identifierUTF8Bytes,
            maximum: maximum
        )
        XCTAssertFalse(try keystore.checkKey(for: identifier))
    }

    func testKeystoreResourceLimits_whenStagedKeyBytesExceeded_freezesAndFailsBeforePrepareWrites() throws {
        let keystore = InMemoryKeychain()
        let identifier =
            KeystoreTagV2.substrateSecretKeyTagForMetaId(
                "00000000-0000-4000-8000-000000000014"
            )
        let key = Data([0x01, 0x02])
        let migrator = makeVersion2KeystoreMigrator(
            keystore: keystore,
            resourceLimits: makeResourceLimits(
                maximumStagedKeyBytes: key.count - 1
            )
        )

        migrator.save(key: key, for: identifier)
        migrator.save(
            key: Data([0x03]),
            for: KeystoreTagV2.substrateSeedTagForMetaId(
                "00000000-0000-4000-8000-000000000015"
            )
        )

        XCTAssertTrue(migrator.tempKeystore.isEmpty)
        assertPrepareFailsClosed(
            migrator,
            keystore: keystore,
            resource: .stagedKeyBytes,
            maximum: key.count - 1
        )
        XCTAssertFalse(try keystore.checkKey(for: identifier))
    }

    func testKeystoreResourceLimits_whenDeletionCountExceeded_freezesAndFailsBeforePrepareWrites() throws {
        let keystore = InMemoryKeychain()
        let destinationIdentifier =
            KeystoreTagV2.substrateSecretKeyTagForMetaId(
                "00000000-0000-4000-8000-000000000016"
            )
        let ignoredIdentifier =
            KeystoreTagV2.substrateSeedTagForMetaId(
                "00000000-0000-4000-8000-000000000017"
            )
        let migrator = makeVersion2KeystoreMigrator(
            keystore: keystore,
            resourceLimits: makeResourceLimits(
                maximumDeletionCount: 0
            )
        )

        migrator.save(key: Data([0x01]), for: destinationIdentifier)
        migrator.deleteKey(for: "first-rejected-deletion")
        migrator.save(key: Data([0x02]), for: ignoredIdentifier)

        XCTAssertEqual(
            migrator.tempKeystore,
            [destinationIdentifier: Data([0x01])]
        )
        XCTAssertTrue(migrator.identifiersToRemoveOnFinalize.isEmpty)
        assertPrepareFailsClosed(
            migrator,
            keystore: keystore,
            resource: .deletionCount,
            maximum: 0
        )
        XCTAssertFalse(try keystore.checkKey(for: destinationIdentifier))
        XCTAssertFalse(try keystore.checkKey(for: ignoredIdentifier))
    }

    func testKeystoreResourceLimits_whenEncodedJournalExceeded_failsBeforeJournalOrDestinationWrites() throws {
        let keystore = InMemoryKeychain()
        let destinationIdentifier =
            KeystoreTagV2.substrateSecretKeyTagForMetaId(
                "00000000-0000-4000-8000-000000000018"
            )
        let migrator = makeVersion2KeystoreMigrator(
            keystore: keystore,
            resourceLimits: makeResourceLimits(
                maximumCleanupJournalBytes: 0
            )
        )

        migrator.save(key: Data([0x01]), for: destinationIdentifier)

        assertPrepareFailsClosed(
            migrator,
            keystore: keystore,
            resource: .cleanupJournalBytes,
            maximum: 0
        )
        migrator.save(
            key: Data([0x02]),
            for: KeystoreTagV2.substrateSeedTagForMetaId(
                "00000000-0000-4000-8000-000000000019"
            )
        )

        XCTAssertEqual(
            migrator.tempKeystore,
            [destinationIdentifier: Data([0x01])]
        )
        XCTAssertFalse(try keystore.checkKey(for: destinationIdentifier))
    }

    func testCleanupRecovery_whenEncodedJournalExceedsProductionLimit_rejectsBeforeDecodeOrMutation() throws {
        let maximum = KeystoreMigrationResourceLimits.production
            .maximumCleanupJournalBytes
        let oversizedJournal = Data(
            repeating: 0x7B,
            count: maximum + 1
        )
        let keystore = RecordingMigrationKeychain()
        try keystore.saveKey(
            oversizedJournal,
            with: KeystoreMigrator.pendingCleanupIdentifier
        )
        keystore.resetMutationHistory()

        XCTAssertThrowsError(
            try KeystoreMigrator.recoverPendingCleanup(
                keystore: keystore,
                currentVersion: .version1
            )
        ) { error in
            self.assertResourceLimitError(
                error,
                resource: .cleanupJournalBytes,
                maximum: maximum
            )
        }

        XCTAssertTrue(keystore.mutatedIdentifiers.isEmpty)
        XCTAssertEqual(
            try keystore.fetchKey(
                for: KeystoreMigrator.pendingCleanupIdentifier
            ),
            oversizedJournal
        )
    }

    func testV1Migration_whenLegacyRowLimitExceeded_preservesLiveStoreAndKeychain() throws {
        let firstAccount = try generateOldAccount(
            hasEntropy: false,
            hasSeed: false,
            hasDerivationPath: false
        )
        let secondAccount = try generateOldAccount(
            hasEntropy: false,
            hasSeed: false,
            hasDerivationPath: false
        )
        let accounts = [firstAccount, secondAccount]
        try saveOldAccountRows(accounts)
        let keystore = RecordingMigrationKeychain()
        try accounts.forEach {
            try saveLegacySecrets(for: $0, keystore: keystore)
        }
        keystore.resetMutationHistory()
        var replacementAttempted = false
        let limits = makeResourceLimits(
            maximumLegacyAccountRows: 1
        )
        let migrator = UserStorageMigrator(
            targetVersion: .version2,
            storeURL: storeURL,
            modelDirectory: modelDirectory,
            keystore: keystore,
            settings: InMemorySettingsManager(),
            fileManager: FileManager.default,
            modelBundle: Bundle(for: UserDataStorageFacade.self),
            storeReplacer: { _, _ in
                replacementAttempted = true
            },
            keystoreMigratorFactory: { source, destination, keystore in
                KeystoreMigrator(
                    sourceVersion: source,
                    destinationVersion: destination,
                    keystore: keystore,
                    resourceLimits: limits
                )
            }
        )

        XCTAssertThrowsError(try migrator.performMigration()) { error in
            self.assertResourceLimitError(
                error,
                resource: .legacyAccountRows,
                maximum: 1
            )
        }

        XCTAssertFalse(replacementAttempted)
        XCTAssertTrue(keystore.mutatedIdentifiers.isEmpty)
        XCTAssertTrue(migrator.requiresMigration())
        XCTAssertEqual(try fetchOldAccountCount(), accounts.count)
        for account in accounts {
            XCTAssertEqual(
                try keystore.fetchKey(
                    for: KeystoreTag.secretKeyTagForAddress(
                        account.address
                    )
                ),
                account.privateKey
            )
        }
        XCTAssertFalse(
            try keystore.checkKey(
                for: KeystoreMigrator.pendingCleanupIdentifier
            )
        )
    }

    func testV1Migration_whenNonthrowingStagingLimitExceeded_preservesLiveStoreAndMakesNoKeychainWrites() throws {
        let account = try generateOldAccount(
            hasEntropy: false,
            hasSeed: false,
            hasDerivationPath: false
        )
        try saveOldAccountRows([account])
        let keystore = RecordingMigrationKeychain()
        try saveLegacySecrets(for: account, keystore: keystore)
        keystore.resetMutationHistory()
        var replacementAttempted = false
        let limits = makeResourceLimits(
            maximumStagedKeyCount: 0
        )
        let migrator = UserStorageMigrator(
            targetVersion: .version2,
            storeURL: storeURL,
            modelDirectory: modelDirectory,
            keystore: keystore,
            settings: InMemorySettingsManager(),
            fileManager: FileManager.default,
            modelBundle: Bundle(for: UserDataStorageFacade.self),
            storeReplacer: { _, _ in
                replacementAttempted = true
            },
            keystoreMigratorFactory: { source, destination, keystore in
                KeystoreMigrator(
                    sourceVersion: source,
                    destinationVersion: destination,
                    keystore: keystore,
                    resourceLimits: limits
                )
            }
        )

        XCTAssertThrowsError(try migrator.performMigration()) { error in
            self.assertResourceLimitError(
                error,
                resource: .stagedKeyCount,
                maximum: 0
            )
        }

        XCTAssertFalse(replacementAttempted)
        XCTAssertTrue(keystore.mutatedIdentifiers.isEmpty)
        XCTAssertTrue(migrator.requiresMigration())
        XCTAssertEqual(try fetchOldAccountCount(), 1)
        XCTAssertEqual(
            try keystore.fetchKey(
                for: KeystoreTag.secretKeyTagForAddress(account.address)
            ),
            account.privateKey
        )
        XCTAssertFalse(
            try keystore.checkKey(
                for: KeystoreMigrator.pendingCleanupIdentifier
            )
        )
    }

    func testV1Migration_whenEntropyExceedsStagedByteLimit_abortsBeforeCryptographicDerivation() throws {
        let account = try generateOldAccount(
            hasEntropy: false,
            hasSeed: false,
            hasDerivationPath: false
        )
        try saveOldAccountRows([account])
        let oversizedInvalidEntropy = Data([0xA5, 0xA5])
        let keystore = RecordingMigrationKeychain()
        try saveLegacySecrets(for: account, keystore: keystore)
        try keystore.saveKey(
            oversizedInvalidEntropy,
            with: KeystoreTag.entropyTagForAddress(account.address)
        )
        keystore.resetMutationHistory()
        var replacementAttempted = false
        let limits = makeResourceLimits(
            maximumStagedKeyBytes: oversizedInvalidEntropy.count - 1
        )
        let migrator = UserStorageMigrator(
            targetVersion: .version2,
            storeURL: storeURL,
            modelDirectory: modelDirectory,
            keystore: keystore,
            settings: InMemorySettingsManager(),
            fileManager: FileManager.default,
            modelBundle: Bundle(for: UserDataStorageFacade.self),
            storeReplacer: { _, _ in
                replacementAttempted = true
            },
            keystoreMigratorFactory: { source, destination, keystore in
                KeystoreMigrator(
                    sourceVersion: source,
                    destinationVersion: destination,
                    keystore: keystore,
                    resourceLimits: limits
                )
            }
        )

        XCTAssertThrowsError(try migrator.performMigration()) { error in
            self.assertResourceLimitError(
                error,
                resource: .stagedKeyBytes,
                maximum: oversizedInvalidEntropy.count - 1
            )
        }

        XCTAssertFalse(replacementAttempted)
        XCTAssertTrue(keystore.mutatedIdentifiers.isEmpty)
        XCTAssertTrue(migrator.requiresMigration())
        XCTAssertEqual(try fetchOldAccountCount(), 1)
        XCTAssertEqual(
            try keystore.fetchKey(
                for: KeystoreTag.entropyTagForAddress(account.address)
            ),
            oversizedInvalidEntropy
        )
        XCTAssertFalse(
            try keystore.checkKey(
                for: KeystoreMigrator.pendingCleanupIdentifier
            )
        )
    }

    private func performTestUserMigration(
        hasEntropy: Bool,
        hasSeed: Bool,
        hasDerivationPath: Bool,
        targetVersion: UserStorageVersion = .version2
    ) throws {
        // given

        let keystore = InMemoryKeychain()
        let settings = InMemorySettingsManager()

        let accounts = try generateAndSaveOldAccounts(
            count: 10,
            keystore: keystore,
            hasEntropy: hasEntropy,
            hasSeed: hasSeed,
            hasDerivationPath: hasDerivationPath
        )

        // we put some dummy data for serialized settings just to make sure that it is cleared
        settings.set(value: Data(), for: SettingsKey.selectedAccount.rawValue)
        settings.set(value: Data(), for: SettingsKey.selectedConnection.rawValue)

        let migrator = UserStorageMigrator(
            targetVersion: targetVersion,
            storeURL: storeURL,
            modelDirectory: modelDirectory,
            keystore: keystore,
            settings: settings,
            fileManager: FileManager.default,
            modelBundle: Bundle(for: UserDataStorageFacade.self)
        )

        guard migrator.requiresMigration() else {
            XCTFail("Migration not required")
            return
        }

        try migrator.performMigration()

        // then

        let newEntities = try fetchNewEntities(version: targetVersion)

        let addressFactory = SS58AddressFactory()

        for account in accounts {
            guard let newEntity = newEntities.first(where: { $0.substratePublicKey == account.publicKey }) else {
                XCTFail("Missing account after migration")
                continue
            }

            XCTAssertNotNil(newEntity.metaId)
            XCTAssertEqual(account.name, newEntity.name)
            XCTAssertEqual(account.publicKey, newEntity.substratePublicKey)
            XCTAssertEqual(account.cryptoType, newEntity.substrateCryptoType)

            let oldAccountId = try addressFactory.accountId(from: account.address)
            XCTAssertEqual(oldAccountId.toHex(), newEntity.substrateAccountId)

            let entropyExistence = try keystore.checkKey(for: KeystoreTagV2.entropyTagForMetaId(newEntity.metaId))
            let substrateSeedExistence = try keystore.checkKey(
                for: KeystoreTagV2.substrateSeedTagForMetaId(newEntity.metaId)
            )

            let ethSeedExistence = try keystore.checkKey(
                for: KeystoreTagV2.ethereumSeedTagForMetaId(newEntity.metaId)
            )

            let ethPrivateKeyExistence = try keystore.checkKey(
                for: KeystoreTagV2.ethereumSecretKeyTagForMetaId(newEntity.metaId)
            )

            let substrateDerivPathExistence = try keystore.checkKey(
                for: KeystoreTagV2.substrateDerivationTagForMetaId(newEntity.metaId)
            )

            let ethDerivPathExistence = try keystore.checkKey(
                for: KeystoreTagV2.ethereumDerivationTagForMetaId(newEntity.metaId)
            )

            if hasEntropy {
                let migratedEntropy = try keystore.fetchKey(for: KeystoreTagV2.entropyTagForMetaId(newEntity.metaId))
                XCTAssertEqual(account.entropy, migratedEntropy)
                XCTAssertNotNil(newEntity.ethereumPublicKey)
                XCTAssertNotNil(newEntity.ethereumAddress)
                XCTAssertTrue(ethSeedExistence)
                XCTAssertTrue(ethPrivateKeyExistence)
                XCTAssertTrue(ethDerivPathExistence)
            } else {
                XCTAssertNil(newEntity.ethereumPublicKey)
                XCTAssertNil(newEntity.ethereumAddress)
                XCTAssertFalse(entropyExistence)
                XCTAssertFalse(ethSeedExistence)
                XCTAssertFalse(ethPrivateKeyExistence)
                XCTAssertFalse(ethDerivPathExistence)
            }

            if hasSeed {
                let migratedSeed = try keystore.fetchKey(
                    for: KeystoreTagV2.substrateSeedTagForMetaId(newEntity.metaId)
                )
                XCTAssertEqual(account.seed, migratedSeed)
            } else {
                XCTAssertFalse(substrateSeedExistence)
            }

            if hasDerivationPath {
                let migratedDerivationPath = try keystore.fetchKey(
                    for: KeystoreTagV2.substrateDerivationTagForMetaId(newEntity.metaId)
                )

                XCTAssertEqual(account.derivationPath, String(data: migratedDerivationPath, encoding: .utf8))

            } else {
                XCTAssertFalse(substrateDerivPathExistence)
            }

            XCTAssertFalse(
                try keystore.checkKey(
                    for: KeystoreTag.secretKeyTagForAddress(account.address)
                )
            )
            XCTAssertFalse(
                try keystore.checkKey(
                    for: KeystoreTag.seedTagForAddress(account.address)
                )
            )
            XCTAssertFalse(
                try keystore.checkKey(
                    for: KeystoreTag.entropyTagForAddress(account.address)
                )
            )
            XCTAssertFalse(
                try keystore.checkKey(
                    for: KeystoreTag.deriviationTagForAddress(account.address)
                )
            )
        }

        let orders = Set(newEntities.map { $0.order })
        XCTAssertEqual(newEntities.count, orders.count)

        let hasSelected = newEntities.contains { $0.isSelected }
        XCTAssertTrue(hasSelected)

        XCTAssertNil(settings.data(for: SettingsKey.selectedAccount.rawValue))
        XCTAssertNil(settings.data(for: SettingsKey.selectedConnection.rawValue))
        XCTAssertFalse(
            try keystore.checkKey(
                for: KeystoreMigrator.pendingCleanupIdentifier
            )
        )
    }

    // MARK: Private

    private func createModelURL(for version: UserStorageVersion) -> URL {
        let bundles = [Bundle(for: type(of: self)), Bundle(for: UserDataStorageFacade.self), Bundle.main] +
            Bundle.allFrameworks + Bundle.allBundles

        for bundle in bundles {
            if let url = version.modelURL(
                in: bundle,
                legacyModelDirectory: modelDirectory
            ) {
                return url
            }
        }

        fatalError("Missing Core Data model for \(version.rawValue)")
    }

    private func createCoreDataService(for version: UserStorageVersion) -> CoreDataServiceProtocol {
        let modelURL = createModelURL(for: version)

        let persistentSettings = CoreDataPersistentSettings(
            databaseDirectory: databaseDirectory,
            databaseName: databaseName,
            incompatibleModelStrategy: .ignore
        )

        let configuration = CoreDataServiceConfiguration(
            modelURL: modelURL,
            storageType: .persistent(settings: persistentSettings)
        )

        return CoreDataService(configuration: configuration)
    }

    private func performDuplicateSignerMigration(
        rowOrder: DuplicateRowOrder
    ) throws {
        let keystore = InMemoryKeychain()
        let settings = InMemorySettingsManager()
        let generatedAccount = try generateOldAccount(
            hasEntropy: false,
            hasSeed: false,
            hasDerivationPath: false
        )
        let watchOnlyAddress = try SS58AddressFactory().address(
            fromAccountId: generatedAccount.publicKey,
            type: 2
        )
        let watchOnlyAccount = OldAccount(
            address: watchOnlyAddress,
            cryptoType: generatedAccount.cryptoType,
            name: "watch-only-alias",
            privateKey: generatedAccount.privateKey,
            publicKey: generatedAccount.publicKey,
            entropy: nil,
            derivationPath: nil,
            seed: nil
        )
        let signingAccount = OldAccount(
            address: generatedAccount.address,
            cryptoType: generatedAccount.cryptoType,
            name: "signing-alias",
            privateKey: generatedAccount.privateKey,
            publicKey: generatedAccount.publicKey,
            entropy: nil,
            derivationPath: nil,
            seed: nil
        )
        let accounts: [OldAccount]

        switch rowOrder {
        case .watchOnlyFirst:
            accounts = [watchOnlyAccount, signingAccount]
        case .signerFirst:
            accounts = [signingAccount, watchOnlyAccount]
        }

        try saveOldAccountRows(accounts)
        try keystore.saveKey(
            signingAccount.privateKey,
            with: KeystoreTag.secretKeyTagForAddress(signingAccount.address)
        )

        let migrator = UserStorageMigrator(
            targetVersion: .version2,
            storeURL: storeURL,
            modelDirectory: modelDirectory,
            keystore: keystore,
            settings: settings,
            fileManager: FileManager.default,
            modelBundle: Bundle(for: UserDataStorageFacade.self)
        )

        try migrator.performMigration()

        let newEntities = try fetchNewEntities(version: .version2)
        let migratedAccount = try XCTUnwrap(newEntities.first)

        XCTAssertEqual(newEntities.count, 1)
        XCTAssertEqual(migratedAccount.name, signingAccount.name)
        XCTAssertEqual(
            migratedAccount.substratePublicKey,
            signingAccount.publicKey
        )
        XCTAssertEqual(
            try keystore.fetchKey(
                for: KeystoreTagV2.substrateSecretKeyTagForMetaId(
                    migratedAccount.metaId
                )
            ),
            signingAccount.privateKey
        )
        XCTAssertFalse(
            try keystore.checkKey(
                for: KeystoreTag.secretKeyTagForAddress(signingAccount.address)
            )
        )
        XCTAssertFalse(
            try keystore.checkKey(
                for: KeystoreMigrator.pendingCleanupIdentifier
            )
        )
    }

    private func performConflictingDuplicateMigration(
        rowOrder: ConflictingRowOrder
    ) throws {
        let keystore = InMemoryKeychain()
        let generatedAccount = try generateOldAccount(
            hasEntropy: false,
            hasSeed: false,
            hasDerivationPath: false
        )
        let secondAddress = try SS58AddressFactory().address(
            fromAccountId: generatedAccount.publicKey,
            type: 2
        )
        let firstAccount = OldAccount(
            address: generatedAccount.address,
            cryptoType: generatedAccount.cryptoType,
            name: "first-signing-alias",
            privateKey: generatedAccount.privateKey,
            publicKey: generatedAccount.publicKey,
            entropy: nil,
            derivationPath: nil,
            seed: nil
        )
        let conflictingPrivateKey = Data(
            repeating: 0xA5,
            count: generatedAccount.privateKey.count
        )
        XCTAssertNotEqual(conflictingPrivateKey, generatedAccount.privateKey)
        let secondAccount = OldAccount(
            address: secondAddress,
            cryptoType: generatedAccount.cryptoType,
            name: "second-signing-alias",
            privateKey: conflictingPrivateKey,
            publicKey: generatedAccount.publicKey,
            entropy: nil,
            derivationPath: nil,
            seed: nil
        )
        let accounts: [OldAccount]

        switch rowOrder {
        case .firstAliasFirst:
            accounts = [firstAccount, secondAccount]
        case .secondAliasFirst:
            accounts = [secondAccount, firstAccount]
        }

        try saveOldAccountRows(accounts)
        try keystore.saveKey(
            firstAccount.privateKey,
            with: KeystoreTag.secretKeyTagForAddress(firstAccount.address)
        )
        try keystore.saveKey(
            secondAccount.privateKey,
            with: KeystoreTag.secretKeyTagForAddress(secondAccount.address)
        )

        var replacementAttempted = false
        let migrator = UserStorageMigrator(
            targetVersion: .version2,
            storeURL: storeURL,
            modelDirectory: modelDirectory,
            keystore: keystore,
            settings: InMemorySettingsManager(),
            fileManager: FileManager.default,
            modelBundle: Bundle(for: UserDataStorageFacade.self),
            storeReplacer: { _, _ in
                replacementAttempted = true
            }
        )

        XCTAssertThrowsError(try migrator.performMigration()) { error in
            guard let identifier = self.stagedConflictIdentifier(in: error) else {
                return XCTFail("Unexpected error: \(error)")
            }

            XCTAssertTrue(
                identifier.hasSuffix("-substrateSecretKey"),
                "Unexpected conflicting identifier: \(identifier)"
            )
        }

        XCTAssertFalse(replacementAttempted)
        XCTAssertTrue(migrator.requiresMigration())
        XCTAssertEqual(try fetchOldAccountCount(), 2)
        XCTAssertEqual(
            try keystore.fetchKey(
                for: KeystoreTag.secretKeyTagForAddress(firstAccount.address)
            ),
            firstAccount.privateKey
        )
        XCTAssertEqual(
            try keystore.fetchKey(
                for: KeystoreTag.secretKeyTagForAddress(secondAccount.address)
            ),
            secondAccount.privateKey
        )
        XCTAssertFalse(
            try keystore.checkKey(
                for: KeystoreMigrator.pendingCleanupIdentifier
            )
        )
    }

    private func makeResourceLimits(
        maximumLegacyAccountRows: Int = Int.max,
        maximumStagedKeyCount: Int = Int.max,
        maximumIdentifierUTF8Bytes: Int = Int.max,
        maximumStagedKeyBytes: Int = Int.max,
        maximumDeletionCount: Int = Int.max,
        maximumCleanupJournalBytes: Int = Int.max
    ) -> KeystoreMigrationResourceLimits {
        KeystoreMigrationResourceLimits(
            maximumLegacyAccountRows: maximumLegacyAccountRows,
            maximumStagedKeyCount: maximumStagedKeyCount,
            maximumIdentifierUTF8Bytes: maximumIdentifierUTF8Bytes,
            maximumStagedKeyBytes: maximumStagedKeyBytes,
            maximumDeletionCount: maximumDeletionCount,
            maximumCleanupJournalBytes: maximumCleanupJournalBytes
        )
    }

    private func makeVersion2KeystoreMigrator(
        keystore: KeystoreProtocol,
        resourceLimits: KeystoreMigrationResourceLimits
    ) -> KeystoreMigrator {
        let migrator = KeystoreMigrator(
            sourceVersion: .version1,
            destinationVersion: .version2,
            keystore: keystore,
            resourceLimits: resourceLimits
        )

        do {
            try migrator.switchVersion()
        } catch {
            XCTFail("Unable to advance keystore test migrator: \(error)")
        }

        return migrator
    }

    private func stageExactBoundaryFixture(
        in migrator: KeystoreMigrator,
        firstIdentifier: String,
        firstKey: Data,
        secondIdentifier: String,
        secondKey: Data,
        legacyIdentifier: String
    ) throws {
        try migrator.switchVersion()
        try migrator.registerLegacyAccountRow()
        try migrator.registerLegacyAccountRow()
        migrator.save(key: firstKey, for: firstIdentifier)
        migrator.save(key: secondKey, for: secondIdentifier)
        migrator.deleteKey(for: legacyIdentifier)
    }

    private func assertPrepareFailsClosed(
        _ migrator: KeystoreMigrator,
        keystore: KeystoreProtocol,
        resource: KeystoreMigrationResource,
        maximum: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(
            try migrator.prepare(),
            file: file,
            line: line
        ) { error in
            self.assertResourceLimitError(
                error,
                resource: resource,
                maximum: maximum,
                file: file,
                line: line
            )
        }

        XCTAssertFalse(
            try keystore.checkKey(
                for: KeystoreMigrator.pendingCleanupIdentifier
            ),
            file: file,
            line: line
        )
    }

    private func assertResourceLimitError(
        _ error: Error,
        resource: KeystoreMigrationResource,
        maximum: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard
            let violation = resourceLimitViolation(in: error)
        else {
            return XCTFail(
                "Unexpected error: \(error)",
                file: file,
                line: line
            )
        }

        XCTAssertEqual(
            violation.resource.rawValue,
            resource.rawValue,
            file: file,
            line: line
        )
        XCTAssertEqual(
            violation.maximum,
            maximum,
            file: file,
            line: line
        )
    }

    private func resourceLimitViolation(
        in error: Error
    ) -> (
        resource: KeystoreMigrationResource,
        maximum: Int
    )? {
        if
            let migrationError = error as? KeystoreMigratingError,
            case let .resourceLimitExceeded(
                resource,
                maximum
            ) = migrationError
        {
            return (resource, maximum)
        }

        let nsError = error as NSError
        if
            let underlyingError =
                nsError.userInfo[NSUnderlyingErrorKey] as? Error,
            let violation = resourceLimitViolation(in: underlyingError)
        {
            return violation
        }

        if
            let detailedErrors =
                nsError.userInfo[NSDetailedErrorsKey] as? [Error]
        {
            for detailedError in detailedErrors {
                if
                    let violation = resourceLimitViolation(
                        in: detailedError
                    )
                {
                    return violation
                }
            }
        }

        return nil
    }

    private func stagedConflictIdentifier(in error: Error) -> String? {
        if
            let migrationError = error as? KeystoreMigratingError,
            case let .stagedKeyConflict(identifier) = migrationError
        {
            return identifier
        }

        let nsError = error as NSError
        if
            let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? Error,
            let identifier = stagedConflictIdentifier(in: underlyingError)
        {
            return identifier
        }

        if let detailedErrors = nsError.userInfo[NSDetailedErrorsKey] as? [Error] {
            for detailedError in detailedErrors {
                if let identifier = stagedConflictIdentifier(in: detailedError) {
                    return identifier
                }
            }
        }

        return nil
    }

    private func fetchOldAccountCount() throws -> Int {
        let dbService = createCoreDataService(for: .version1)
        let semaphore = DispatchSemaphore(value: 0)
        var accountCount: Int?
        var fetchError: Error?

        dbService.performAsync { context, error in
            defer {
                semaphore.signal()
            }

            if let error {
                fetchError = error
                return
            }

            guard let context else {
                fetchError = MigrationTestError.coreData(
                    "Missing Core Data context while fetching legacy entities"
                )
                return
            }

            do {
                accountCount = try context.count(
                    for: NSFetchRequest<NSFetchRequestResult>(
                        entityName: "CDAccountItem"
                    )
                )
            } catch {
                fetchError = error
            }
        }

        semaphore.wait()
        if let fetchError {
            throw fetchError
        }

        try dbService.close()
        return accountCount ?? 0
    }

    private func fetchNewEntities(
        version: UserStorageVersion
    ) throws -> [NewEntity] {
        let dbService = createCoreDataService(for: version)
        let semaphore = DispatchSemaphore(value: 0)
        var newEntities: [NewEntity]?
        var fetchError: Error?

        dbService.performAsync { (context, error) in
            defer {
                semaphore.signal()
            }

            if let error {
                fetchError = error
                return
            }

            guard let context else {
                fetchError = MigrationTestError.coreData("Missing Core Data context while fetching migrated entities")
                return
            }

            let request = NSFetchRequest<NSManagedObject>(entityName: "CDMetaAccount")
            do {
                let results = try context.fetch(request)

                newEntities = results.compactMap { entity in
                    guard
                        let metaId = entity.value(forKey: "metaId") as? String,
                        let name = entity.value(forKey: "name") as? String,
                        let isSelected = entity.value(forKey: "isSelected") as? Bool,
                        let substrateAccountId = entity.value(forKey: "substrateAccountId") as? String,
                        let substratePublicKey = entity.value(forKey: "substratePublicKey") as? Data,
                        let substrateCryptoType = entity.value(forKey: "substrateCryptoType") as? UInt8,
                        let order = entity.value(forKey: "order") as? Int32
                    else {
                        return nil
                    }

                    let ethereumAddress = entity.value(forKey: "ethereumAddress") as? String
                    let ethereumPublicKey = entity.value(forKey: "ethereumPublicKey") as? Data

                    return NewEntity(
                        metaId: metaId,
                        name: name,
                        isSelected: isSelected,
                        substrateAccountId: substrateAccountId,
                        substratePublicKey: substratePublicKey,
                        substrateCryptoType: substrateCryptoType,
                        ethereumAddress: ethereumAddress,
                        ethereumPublicKey: ethereumPublicKey,
                        order: order
                    )
                }
            } catch {
                fetchError = error
            }
        }

        semaphore.wait()
        if let fetchError {
            throw fetchError
        }

        try dbService.close()

        return newEntities ?? []
    }

    private func generateAndSaveOldAccounts(
        count: Int,
        keystore: KeystoreProtocol,
        hasEntropy: Bool,
        hasSeed: Bool,
        hasDerivationPath: Bool
    ) throws -> [OldAccount] {
        let accounts = try (0..<count).map { _ in
            try generateOldAccount(hasEntropy: hasEntropy, hasSeed: hasSeed, hasDerivationPath: hasDerivationPath)
        }

        try saveOldAccountRows(accounts)

        try accounts.forEach { account in
            try saveLegacySecrets(for: account, keystore: keystore)
        }

        return accounts
    }

    private func saveOldAccountRows(_ accounts: [OldAccount]) throws {
        let dbService = createCoreDataService(for: .version1)
        let semaphore = DispatchSemaphore(value: 0)
        var saveError: Error?

        dbService.performAsync { (context, error) in
            defer {
                semaphore.signal()
            }

            if let error {
                saveError = error
                return
            }

            guard let context = context else {
                saveError = MigrationTestError.coreData("Missing Core Data context while saving legacy entities")
                return
            }

            accounts.enumerated().forEach { index, account in
                let entity = NSEntityDescription.insertNewObject(
                    forEntityName: "CDAccountItem",
                    into: context
                )

                entity.setValue(account.address, forKey: "identifier")
                entity.setValue(account.name, forKeyPath: "username")
                entity.setValue(0, forKey: "networkType")
                entity.setValue(account.cryptoType, forKey: "cryptoType")
                entity.setValue(account.publicKey, forKey: "publicKey")
                entity.setValue(Int32(index), forKeyPath: "order")
            }

            do {
                try context.save()
            } catch {
                saveError = error
            }
        }

        semaphore.wait()
        if let saveError {
            throw saveError
        }

        try dbService.close()
    }

    private func saveLegacySecrets(
        for account: OldAccount,
        keystore: KeystoreProtocol
    ) throws {
        try keystore.saveKey(
            account.privateKey,
            with: KeystoreTag.secretKeyTagForAddress(account.address)
        )

        if let seed = account.seed {
            try keystore.saveKey(
                seed,
                with: KeystoreTag.seedTagForAddress(account.address)
            )
        }

        if let entropy = account.entropy {
            try keystore.saveKey(
                entropy,
                with: KeystoreTag.entropyTagForAddress(account.address)
            )
        }

        if let derivationPath = account.derivationPath {
            try keystore.saveKey(
                derivationPath.data(using: .utf8)!,
                with: KeystoreTag.deriviationTagForAddress(account.address)
            )
        }
    }

    private func generateOldAccount(
        hasEntropy: Bool,
        hasSeed: Bool,
        hasDerivationPath: Bool
    ) throws -> OldAccount {
        let mnemonicGenerator = IRMnemonicCreator(language: .english)
        let mnemonic = try mnemonicGenerator.randomMnemonic(.entropy160)

        let seedFactory = SeedFactory(mnemonicLanguage: .english)
        let seedResult = try seedFactory.deriveSeed(from: mnemonic.toString(), password: "")

        let derivationPath = hasDerivationPath ? "//0/1" : nil

        let chaincodes = try derivationPath.map { try SubstrateJunctionFactory().parse(path: $0).chaincodes } ?? []

        let keypair = try SR25519KeypairFactory().createKeypairFromSeed(
            seedResult.seed.miniSeed,
            chaincodeList: chaincodes
        )

        let address = try SS58AddressFactory().address(fromAccountId: keypair.publicKey().rawData(), type: 0)

        return OldAccount(
            address: address,
            cryptoType: 0,
            name: UUID().uuidString,
            privateKey: keypair.privateKey().rawData(),
            publicKey: keypair.publicKey().rawData(),
            entropy: hasEntropy ? mnemonic.entropy() : nil,
            derivationPath: derivationPath,
            seed: hasSeed ? seedResult.seed : nil
        )
    }
}

private final class RecordingMigrationKeychain: KeystoreProtocol {
    private let keychain = InMemoryKeychain()
    private(set) var mutatedIdentifiers = [String]()

    func resetMutationHistory() {
        mutatedIdentifiers.removeAll(keepingCapacity: true)
    }

    func addKey(_ key: Data, with identifier: String) throws {
        mutatedIdentifiers.append(identifier)
        try keychain.addKey(key, with: identifier)
    }

    func updateKey(_ key: Data, with identifier: String) throws {
        mutatedIdentifiers.append(identifier)
        try keychain.updateKey(key, with: identifier)
    }

    func fetchKey(for identifier: String) throws -> Data {
        try keychain.fetchKey(for: identifier)
    }

    func checkKey(for identifier: String) throws -> Bool {
        try keychain.checkKey(for: identifier)
    }

    func deleteKey(for identifier: String) throws {
        mutatedIdentifiers.append(identifier)
        try keychain.deleteKey(for: identifier)
    }
}
