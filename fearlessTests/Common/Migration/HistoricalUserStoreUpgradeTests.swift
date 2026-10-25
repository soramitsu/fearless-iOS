import CoreData
@testable import fearless
import IrohaCrypto
import RobinHood
import SoraKeystore
import SQLite3
import SSFModels
import XCTest

/// IK-3: every User store model a build ever wrote is recognised by exactly
/// one model and reaches the current model with every wallet, selection,
/// per-chain account, preference and Keychain item intact. The three
/// TestFlight 2.x models the release did not recognise land on the lineage
/// model of their schema family.
///
/// The stores are created from the verbatim Git-history models (IK-1 test
/// fixtures) and migrated with the app bundle, so these tests exercise the
/// models and migrator that ship. Expectations are written down from what
/// the fixture stored, never read back through the migrator.
final class HistoricalUserStoreUpgradeTests: XCTestCase {
    private typealias HistoricalModel = UpgradeFixtureLoader.HistoricalStoreModel

    private struct ChainAccountRecord: Equatable {
        let chainId: String
        let accountId: String
        let publicKey: Data
        let cryptoType: Int16
        let ethereumBased: Bool?
        let ecosystem: String?
    }

    private struct WalletRecord: Equatable {
        let metaId: String
        let name: String
        let isSelected: Bool
        let order: Int32
        let substrateAccountId: String?
        let substratePublicKey: Data?
        let substrateCryptoType: Int16
        let ethereumAddress: String?
        let ethereumPublicKey: Data?
        let tonAddress: Data?
        let tonPublicKey: Data?
        let tonContractVersion: String?
        let canExportEthereumMnemonic: Bool
        let hasBackup: Bool
        let zeroBalanceAssetsHidden: Bool
        let assetKeysOrder: [String]?
        let assetFilterOptions: [String]?
        let unusedChainIds: [String]?
        let favouriteChainIds: [String]?
        let networkManagmentFilter: String?
        let assetsVisibility: [String: Bool]
        let selectedCurrencyId: String?
        let chainAccounts: [ChainAccountRecord]
    }

    /// Rows outside the wallet graph, as sorted canonical strings.
    private struct SettingsRecord: Equatable {
        let chainSettings: [String]
        let customNodes: [String]
        let currencies: [String]
        let accountInfos: [String]
    }

    private struct FixtureChainAccount {
        let chainId: String
        let accountId: Data
        let publicKey: Data
        let cryptoType: Int16
        let isEthereum: Bool
    }

    /// One wallet as a shipped build stored it. Columns the source model
    /// lacks are skipped when the store is written.
    private struct FixtureWallet {
        let metaId: String
        let name: String
        let order: Int32
        let isSelected: Bool
        let substrateAccountId: Data?
        let substratePublicKey: Data?
        let substrateCryptoType: Int16
        let ethereumAddress: Data?
        let ethereumPublicKey: Data?
        let ton: LegacyTonAccount?
        let chainAccounts: [FixtureChainAccount]
        /// Gives every preference column the source has a non-default value.
        let hasPreferences: Bool
        /// `nil` leaves an optional `hasBackup` column empty.
        let hasBackup: Bool?
        let secrets: [String: Data]

        var hasPresentableName: Bool {
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    /// A 1.x single-asset account and the Keychain items 1.x wrote under
    /// its address.
    private struct LegacyAccount {
        let address: String
        let accountId: Data
        let username: String
        let publicKey: Data
        let cryptoType: Int16
        let entropy: Data?
        let seed: Data?
        let secretKey: Data?
        let derivationPath: Data?
    }

    private static let pincode = Data("2468".utf8)
    private static let assetKeysOrder = ["asset-b", "asset-a"]
    private static let assetFilterOptions = ["filter-option"]
    private static let unusedChainIds = ["unused-chain"]
    private static let favouriteChainIds = ["favourite-chain"]

    private var testDirectory: URL!

    private var appBundle: Bundle {
        Bundle(for: UserDataStorageFacade.self)
    }

    override func setUpWithError() throws {
        try super.setUpWithError()

        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HistoricalUserStoreUpgradeTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: testDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        if let testDirectory {
            try? FileManager.default.removeItem(at: testDirectory)
        }

        try super.tearDownWithError()
    }

    // MARK: - Recognition

    func testHistoricalManifest_matchesUserEnumCases() throws {
        let entries = try userEntries()
        let bundledEntries = entries.filter(\.isAppBundled)
        let historicalCases = UserStorageVersion.allCases.filter(\.isHistoricalResource)

        XCTAssertEqual(entries.count, 15, "14 tagged User models plus the 4.2.0 TestFlight v13")
        XCTAssertEqual(
            Set(historicalCases.map(\.rawValue)),
            Set(bundledEntries.map(\.resource)),
            "Every app-bundled manifest entry needs exactly one case and vice versa"
        )
        XCTAssertEqual(historicalCases.count, 3)

        for entry in bundledEntries {
            let version = try XCTUnwrap(UserStorageVersion(rawValue: entry.resource), entry.resource)

            XCTAssertEqual(entry.tier, .testFlight, entry.resource)
            XCTAssertTrue(version.isCompatibilityResource, entry.resource)
            XCTAssertEqual(version.nextVersion()?.rawValue, entry.landing, entry.resource)
            XCTAssertEqual(entry.allowedDrops, HistoricalModel.Drops(entities: [], attributes: []), entry.resource)
            XCTAssertTrue(entry.requiredConstants.isEmpty, entry.resource)
            XCTAssertEqual(
                try UpgradeFixtureLoader.schemaDigest(of: appModel(for: version)),
                entry.digest,
                entry.resource
            )
        }

        for entry in entries {
            XCTAssertNil(entry.excluded, entry.resource)
            if let bundledName = entry.matchesBundled {
                let version = try XCTUnwrap(UserStorageVersion(rawValue: bundledName), bundledName)
                XCTAssertFalse(version.isHistoricalResource, entry.resource)
            }
        }

        XCTAssertEqual(UserStorageVersion.current, .version14)
        XCTAssertEqual(UserStorageParams.modelVersion, .version14)
        XCTAssertNil(UserStorageVersion.current.nextVersion())
    }

    func testEveryUserModelHasUniqueVersionHashes() throws {
        let hashes = try UserStorageVersion.allCases.map { version in
            try (version, appModel(for: version).entityVersionHashesByName)
        }

        for (index, lhs) in hashes.enumerated() {
            for rhs in hashes[(index + 1)...] {
                XCTAssertNotEqual(lhs.1, rhs.1, "\(lhs.0.rawValue) and \(rhs.0.rawValue) open the same stores")
            }
        }
    }

    func testDetection_eachUserFixtureMatchesExactlyOneVersion() throws {
        let models = try UserStorageVersion.allCases.map { try ($0, appModel(for: $0)) }

        for entry in try userEntries() {
            let storeURL = try caseStoreURL(entry.resource)
            try createStore(at: storeURL, model: UpgradeFixtureLoader.fixtureModel(for: entry)) { _ in }
            let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                ofType: NSSQLiteStoreType,
                at: storeURL,
                options: nil
            )
            let matches = models.filter { _, model in
                model.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
            }.map(\.0.rawValue)

            let expected = try [XCTUnwrap(entry.landing != nil ? entry.resource : entry.matchesBundled)]

            XCTAssertEqual(matches, expected, "\(entry.digest) \(releaseSummary(entry))")
            XCTAssertEqual(
                makeMigrator(storeURL: storeURL).requiresMigration(),
                expected != [UserStorageVersion.version14.rawValue],
                entry.resource
            )
        }
    }

    /// The landing models only add attributes, and the only same-named
    /// attribute whose definition changes is the one the migrator checks
    /// with a semantic snapshot instead of the generic comparison.
    func testHistoricalLandings_onlyAddAttributesAndChangeExactlyTheReviewedOne() throws {
        let expectedAdditions: [String: Set<String>] = [
            "0470cf6eb7223e09": ["CDMetaAccount.unusedChainIds"],
            "399fe7c2a5ba8b2c": ["CDMetaAccount.zeroBalanceAssetsHidden"],
            "ea8584ece2603f2a": []
        ]
        let expectedChanges: [String: Set<String>] = [
            "0470cf6eb7223e09": [],
            "399fe7c2a5ba8b2c": [],
            "ea8584ece2603f2a": ["CDMetaAccount.hasBackup"]
        ]

        for entry in try userEntries() where entry.isAppBundled {
            let version = try XCTUnwrap(UserStorageVersion(rawValue: entry.resource))
            let source = try UpgradeFixtureLoader.fixtureModel(for: entry)
            let destination = try appModel(for: XCTUnwrap(version.nextVersion()))

            XCTAssertEqual(propertyNames(in: source).subtracting(propertyNames(in: destination)), [], entry.resource)
            XCTAssertEqual(
                propertyNames(in: destination).subtracting(propertyNames(in: source)),
                expectedAdditions[entry.digest],
                entry.resource
            )
            XCTAssertEqual(changedAttributes(from: source, to: destination), expectedChanges[entry.digest], entry.resource)
        }
    }

    // MARK: - Every release

    func testUpgrade_everyUserRelease_emptyStore() throws {
        for entry in try userEntries() {
            try XCTContext.runActivity(named: "\(entry.digest) \(releaseSummary(entry))") { _ in
                let storeURL = try caseStoreURL(entry.resource)
                try createStore(at: storeURL, model: UpgradeFixtureLoader.fixtureModel(for: entry)) { _ in }
                let migrator = makeMigrator(storeURL: storeURL)

                try migrator.performMigration()

                XCTAssertFalse(migrator.requiresMigration(), entry.resource)
                let currentModel = try appModel(for: .version14)
                for entityName in currentModel.entitiesByName.keys {
                    XCTAssertEqual(
                        try count(entityName, at: storeURL, model: currentModel),
                        0,
                        "\(entry.digest) created \(entityName) rows"
                    )
                }
            }
        }
    }

    func testUpgrade_everyUserRelease_populatedStore() throws {
        for entry in try userEntries() {
            try XCTContext.runActivity(named: "\(entry.digest) \(releaseSummary(entry))") { _ in
                let fixtureModel = try UpgradeFixtureLoader.fixtureModel(for: entry)
                if fixtureModel.entitiesByName["CDMetaAccount"] == nil {
                    try assertSingleAssetReleaseUpgrade(entry: entry, model: fixtureModel)
                } else {
                    try assertMultiassetReleaseUpgrade(entry: entry, model: fixtureModel)
                }
            }
        }
    }

    // MARK: - TestFlight 2.4.1.1–2.4.1.2

    func testUpgrade_e47dee7e_nilHasBackupBecomesFalse() throws {
        let entry = try userEntry(digest: "ea8584ece2603f2a")
        let fixtureModel = try UpgradeFixtureLoader.fixtureModel(for: entry)
        let hasBackupAttribute = try XCTUnwrap(fixtureModel.entitiesByName["CDMetaAccount"]?.attributesByName["hasBackup"])
        XCTAssertTrue(hasBackupAttribute.isOptional)
        XCTAssertNil(hasBackupAttribute.defaultValue)

        let storeURL = try caseStoreURL(entry.resource)
        let flags: [String: Bool?] = ["backup-empty": nil, "backup-true": true, "backup-false": false]
        try createStore(at: storeURL, model: fixtureModel) { context in
            for (index, metaId) in flags.keys.sorted().enumerated() {
                let wallet = self.makeWallet(
                    metaId: metaId,
                    order: Int32(index),
                    isSelected: index == 0,
                    hasBackup: flags[metaId] ?? nil
                )
                try self.insert(wallet, in: context, model: fixtureModel)
            }
        }
        XCTAssertEqual(try storedBackupFlags(at: storeURL, model: fixtureModel), flags)
        XCTAssertEqual(try sqliteCount("SELECT COUNT(*) FROM ZCDMETAACCOUNT WHERE ZHASBACKUP IS NULL", at: storeURL), 1)

        try makeMigrator(storeURL: storeURL).performMigration()

        XCTAssertEqual(
            try storedBackupFlags(at: storeURL, model: appModel(for: .version14)),
            ["backup-empty": false, "backup-true": true, "backup-false": false]
        )
        // Core Data reads an empty required scalar as `false` as well, so
        // check the column itself holds a value for every wallet.
        XCTAssertEqual(try sqliteCount("SELECT COUNT(*) FROM ZCDMETAACCOUNT WHERE ZHASBACKUP IS NULL", at: storeURL), 0)
        XCTAssertEqual(try sqliteCount("SELECT COUNT(*) FROM ZCDMETAACCOUNT WHERE ZHASBACKUP = 0", at: storeURL), 2)
        XCTAssertFalse(makeMigrator(storeURL: storeURL).requiresMigration())

        let facade = try makeFacade(storeURL: storeURL)
        defer { try? facade.databaseService.close() }
        let wallets = try selectionModels(facade: facade)
        XCTAssertEqual(
            Dictionary(uniqueKeysWithValues: wallets.compactMap { model in model.wallet.map { (model.identifier, $0.hasBackup) } }),
            ["backup-empty": false, "backup-true": true, "backup-false": false]
        )
    }

    // MARK: - Failing closed

    func testUpgrade_e47dee7e_whenTheLandingChangesABackupFlag_failsClosedAndKeepsTheStore() throws {
        let entry = try userEntry(digest: "ea8584ece2603f2a")
        let mutations = [
            "UPDATE ZCDMETAACCOUNT SET ZHASBACKUP = 0 WHERE ZMETAID = 'backup-true'",
            "UPDATE ZCDMETAACCOUNT SET ZHASBACKUP = 1 WHERE ZMETAID = 'backup-empty'",
            "UPDATE ZCDMETAACCOUNT SET ZHASBACKUP = 1 WHERE ZMETAID = 'backup-false'"
        ]

        let flags: [(metaId: String, hasBackup: Bool?)] = [
            ("backup-empty", nil),
            ("backup-true", true),
            ("backup-false", false)
        ]

        for mutation in mutations {
            try XCTContext.runActivity(named: mutation) { _ in
                let fixtureModel = try UpgradeFixtureLoader.fixtureModel(for: entry)
                let storeURL = try caseStoreURL("\(entry.resource)-\(UUID().uuidString)")
                try createStore(at: storeURL, model: fixtureModel) { context in
                    for (index, flag) in flags.enumerated() {
                        try self.insert(
                            self.makeWallet(
                                metaId: flag.metaId,
                                order: Int32(index),
                                isSelected: index == 0,
                                hasBackup: flag.hasBackup
                            ),
                            in: context,
                            model: fixtureModel
                        )
                    }
                }

                try assertStagedLandingMutationFailsClosed(
                    storeURL: storeURL,
                    landing: .version11,
                    sql: mutation
                )
            }
        }
    }

    func testUpgrade_historical_whenTheLandingChangesAnyStoredValue_failsClosedAndKeepsTheStore() throws {
        for entry in try userEntries() where entry.isAppBundled {
            try XCTContext.runActivity(named: entry.resource) { _ in
                let version = try XCTUnwrap(UserStorageVersion(rawValue: entry.resource))
                let fixtureModel = try UpgradeFixtureLoader.fixtureModel(for: entry)
                let storeURL = try caseStoreURL(entry.resource)
                try createStore(at: storeURL, model: fixtureModel) { context in
                    try self.populate(context, model: fixtureModel, wallets: self.fixtureWallets(for: fixtureModel))
                }

                try assertStagedLandingMutationFailsClosed(
                    storeURL: storeURL,
                    landing: XCTUnwrap(version.nextVersion()),
                    sql: "UPDATE ZCDCHAINACCOUNT SET ZACCOUNTID = 'mallory' WHERE ZCHAINID = 'chain-substrate'"
                )
            }
        }
    }

    func testUpgrade_whenALandingWouldDropAStoredProperty_failsClosedBeforeWriting() throws {
        // A build in which the 2.2.2.3 resource is really the 2.4.1.1 model:
        // its landing (MultiassetUserDataModel_v9) has no `hasBackup`.
        let droppingEntry = try userEntry(digest: "ea8584ece2603f2a")
        let modelBundle = try makeModelBundle { historicalDirectory in
            let droppingModelURL = try UpgradeFixtureLoader.fixtureModelURL(for: droppingEntry)
            for version in [UserStorageVersion.historical399fe7c2, .historicalEa8584ec] {
                try? FileManager.default.removeItem(
                    at: historicalDirectory.appendingPathComponent(version.rawValue).appendingPathExtension("mom")
                )
            }
            try FileManager.default.copyItem(
                at: droppingModelURL,
                to: historicalDirectory
                    .appendingPathComponent(UserStorageVersion.historical399fe7c2.rawValue)
                    .appendingPathExtension("mom")
            )
        }
        let fixtureModel = try UpgradeFixtureLoader.fixtureModel(for: droppingEntry)
        let storeURL = try caseStoreURL("dropping-landing")
        try createStore(at: storeURL, model: fixtureModel) { context in
            try self.insert(
                self.makeWallet(metaId: "backed-up", order: 0, isSelected: true, hasBackup: true),
                in: context,
                model: fixtureModel
            )
        }
        let before = try durableStoreFamilySnapshot(at: storeURL)
        let keystore = SnapshotKeystore(values: [fearless.KeystoreTag.pincode.rawValue: Self.pincode])
        let migrator = makeMigrator(storeURL: storeURL, keystore: keystore, modelBundle: modelBundle)

        XCTAssertTrue(migrator.requiresMigration())
        for _ in 0 ..< 2 {
            XCTAssertThrowsError(try migrator.performMigration()) { error in
                guard
                    let migrationError = error as? UserStorageMigrationError,
                    case let .migrationPathUnavailable(source, destination) = migrationError
                else {
                    return XCTFail("Expected migrationPathUnavailable, got \(error)")
                }
                XCTAssertEqual(source, .historical399fe7c2)
                XCTAssertEqual(destination, .version10)
            }
            XCTAssertEqual(try durableStoreFamilySnapshot(at: storeURL), before)
            XCTAssertEqual(keystore.values, [fearless.KeystoreTag.pincode.rawValue: Self.pincode])
        }
    }

    func testUpgrade_historical_processDeathAtEveryReplacementBoundary_converges() throws {
        for digest in ["0470cf6eb7223e09", "ea8584ece2603f2a"] {
            let entry = try userEntry(digest: digest)
            let fixtureModel = try UpgradeFixtureLoader.fixtureModel(for: entry)
            let wallets = try fixtureWallets(for: fixtureModel)

            var boundaries: [CrashConsistentStoreReplacementBoundary] = []
            let recordingURL = try caseStoreURL("\(digest)-recording")
            try createStore(at: recordingURL, model: fixtureModel) { context in
                try self.populate(context, model: fixtureModel, wallets: wallets)
            }
            try makeMigrator(
                storeURL: recordingURL,
                storeReplacementBoundaryHook: { boundaries.append($0) }
            ).performMigration()
            XCTAssertTrue(boundaries.contains(.committedMarkerPersisted), digest)

            for (boundaryIndex, boundary) in boundaries.enumerated() {
                try XCTContext.runActivity(named: "\(digest) dies at \(boundary)") { _ in
                    let storeURL = try caseStoreURL("\(digest)-boundary-\(boundaryIndex)")
                    try createStore(at: storeURL, model: fixtureModel) { context in
                        try self.populate(context, model: fixtureModel, wallets: wallets)
                    }
                    let keystore = SnapshotKeystore(values: keychain(for: wallets))
                    var crossedBoundaryCount = 0
                    let interruptedMigrator = makeMigrator(
                        storeURL: storeURL,
                        keystore: keystore,
                        storeReplacementBoundaryHook: { _ in
                            defer { crossedBoundaryCount += 1 }
                            guard crossedBoundaryCount == boundaryIndex else { return }
                            throw CrashConsistentStoreReplacementInterruption.simulatedProcessDeath
                        }
                    )

                    XCTAssertThrowsError(try interruptedMigrator.performMigration())

                    let relaunchedMigrator = makeMigrator(storeURL: storeURL, keystore: keystore)
                    try relaunchedMigrator.performMigration()

                    XCTAssertFalse(relaunchedMigrator.requiresMigration())
                    XCTAssertEqual(
                        try walletRecords(at: storeURL),
                        wallets.map { expectedRecord(for: $0, sourceModel: fixtureModel) }
                    )
                    XCTAssertEqual(keystore.values, keychain(for: wallets))
                    XCTAssertFalse(
                        FileManager.default.fileExists(
                            atPath: storeURL.deletingLastPathComponent()
                                .appendingPathComponent(".FearlessStoreReplacement", isDirectory: true).path
                        )
                    )
                }
            }
        }
    }

    // MARK: - Release assertions

    /// 2.x and later: wallets, selection, per-chain accounts and preferences
    /// arrive as the build stored them, the Keychain is not touched, the
    /// wallets open, and a relaunch changes nothing.
    private func assertMultiassetReleaseUpgrade(
        entry: HistoricalModel,
        model fixtureModel: NSManagedObjectModel
    ) throws {
        let wallets = try fixtureWallets(for: fixtureModel)
        let storeURL = try caseStoreURL(entry.resource)
        try createStore(at: storeURL, model: fixtureModel) { context in
            try self.populate(context, model: fixtureModel, wallets: wallets)
        }
        let expectedWallets = wallets.map { expectedRecord(for: $0, sourceModel: fixtureModel) }
        let expectedSettings = expectedSettingsRecord(sourceModel: fixtureModel)
        let expectedKeychain = keychain(for: wallets)
        let keystore = SnapshotKeystore(values: expectedKeychain)
        let settings = legacySettings()
        let migrator = makeMigrator(storeURL: storeURL, keystore: keystore, settings: settings)

        XCTAssertEqual(try migrator.performMigration(), entry.matchesBundled != UserStorageVersion.version14.rawValue)

        XCTAssertEqual(try walletRecords(at: storeURL), expectedWallets)
        XCTAssertEqual(try settingsRecord(at: storeURL), expectedSettings)
        XCTAssertEqual(keystore.values, expectedKeychain)
        XCTAssertEqual(keystore.deletedIdentifiers, [])
        assertLegacySettings(settings, removedSelections: false)

        // A relaunch changes nothing.
        let migratedFamily = try durableStoreFamilySnapshot(at: storeURL)
        XCTAssertFalse(migrator.requiresMigration())
        XCTAssertFalse(try makeMigrator(storeURL: storeURL, keystore: keystore).performMigration())
        XCTAssertEqual(try durableStoreFamilySnapshot(at: storeURL), migratedFamily)
        XCTAssertEqual(keystore.values, expectedKeychain)

        try assertWalletsOpen(
            storeURL: storeURL,
            selectedMetaId: XCTUnwrap(wallets.first(where: \.isSelected)?.metaId),
            supportedMetaIds: Set(wallets.filter(\.hasPresentableName).map(\.metaId))
        )
        XCTAssertEqual(try walletRecords(at: storeURL), expectedWallets, "Opening the wallets rewrote a record")
    }

    /// 1.x: each account becomes a wallet, and its Keychain items move to the
    /// wallet's tags through the journaled v1 -> v2 key migration, the one
    /// documented Keychain change on any upgrade.
    private func assertSingleAssetReleaseUpgrade(
        entry: HistoricalModel,
        model fixtureModel: NSManagedObjectModel
    ) throws {
        let accounts = try legacyAccounts()
        let storeURL = try caseStoreURL(entry.resource)
        try createStore(at: storeURL, model: fixtureModel) { context in
            for (index, account) in accounts.enumerated() {
                try self.insertObject(
                    "CDAccountItem",
                    values: [
                        "identifier": account.address,
                        "username": account.username,
                        "publicKey": account.publicKey,
                        "cryptoType": account.cryptoType,
                        "networkType": Int16(42),
                        "order": Int16(index)
                    ],
                    in: context,
                    model: fixtureModel
                )
            }
            try self.insertObject(
                "CDConnectionItem",
                values: ["identifier": "wss://rpc.polkadot.io", "title": "Polkadot", "networkType": Int16(0)],
                in: context,
                model: fixtureModel
            )
        }
        var legacyKeychain = [fearless.KeystoreTag.pincode.rawValue: Self.pincode]
        for account in accounts {
            legacyKeychain[fearless.KeystoreTag.entropyTagForAddress(account.address)] = account.entropy
            legacyKeychain[fearless.KeystoreTag.seedTagForAddress(account.address)] = account.seed
            legacyKeychain[fearless.KeystoreTag.secretKeyTagForAddress(account.address)] = account.secretKey
            legacyKeychain[fearless.KeystoreTag.deriviationTagForAddress(account.address)] = account.derivationPath
        }
        let keystore = SnapshotKeystore(values: legacyKeychain)
        let settings = legacySettings()
        let migrator = makeMigrator(storeURL: storeURL, keystore: keystore, settings: settings)

        XCTAssertTrue(try migrator.performMigration())

        let records = try walletRecords(at: storeURL)
        XCTAssertEqual(records.count, accounts.count)
        XCTAssertEqual(records.filter(\.isSelected).count, 1)
        XCTAssertEqual(Set(records.map(\.order)), Set((0 ..< Int32(accounts.count)).map { $0 }))
        XCTAssertEqual(try settingsRecord(at: storeURL), SettingsRecord(chainSettings: [], customNodes: [], currencies: [], accountInfos: []))

        var expectedKeychain = [fearless.KeystoreTag.pincode.rawValue: Self.pincode]
        for account in accounts {
            let record = try XCTUnwrap(
                records.first { $0.substrateAccountId == account.accountId.toHex() },
                account.username
            )
            XCTAssertEqual(record.name, account.username)
            XCTAssertEqual(record.substratePublicKey, account.publicKey)
            XCTAssertEqual(record.substrateCryptoType, account.cryptoType)
            XCTAssertTrue(record.chainAccounts.isEmpty)

            let metaId = record.metaId
            expectedKeychain[fearless.KeystoreTagV2.entropyTagForMetaId(metaId)] = account.entropy
            expectedKeychain[fearless.KeystoreTagV2.substrateSeedTagForMetaId(metaId)] = account.seed
            expectedKeychain[fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(metaId)] = account.secretKey
            expectedKeychain[fearless.KeystoreTagV2.substrateDerivationTagForMetaId(metaId)] = account.derivationPath

            if let entropy = account.entropy {
                let ethereumPath = DerivationPathConstants.defaultEthereum
                let ethereum = try EthereumAccountImportWrapper().importEntropy(entropy, derivationPath: ethereumPath)
                let ethereumPublicKey = ethereum.keypair.publicKey().rawData()
                expectedKeychain[fearless.KeystoreTagV2.ethereumSeedTagForMetaId(metaId)] = ethereum.seed
                expectedKeychain[fearless.KeystoreTagV2.ethereumSecretKeyTagForMetaId(metaId)] =
                    ethereum.keypair.privateKey().rawData()
                expectedKeychain[fearless.KeystoreTagV2.ethereumDerivationTagForMetaId(metaId)] = Data(ethereumPath.utf8)
                XCTAssertEqual(record.ethereumPublicKey, ethereumPublicKey)
                XCTAssertEqual(record.ethereumAddress, try ethereumPublicKey.ethereumAddressFromPublicKey().toHex())
            } else {
                XCTAssertNil(record.ethereumPublicKey)
                XCTAssertNil(record.ethereumAddress)
            }
        }
        XCTAssertEqual(keystore.values, expectedKeychain)
        assertLegacySettings(settings, removedSelections: true)

        // A relaunch changes nothing.
        let migratedFamily = try durableStoreFamilySnapshot(at: storeURL)
        XCTAssertFalse(migrator.requiresMigration())
        XCTAssertFalse(try makeMigrator(storeURL: storeURL, keystore: keystore).performMigration())
        XCTAssertEqual(try durableStoreFamilySnapshot(at: storeURL), migratedFamily)
        XCTAssertEqual(keystore.values, expectedKeychain)

        try assertWalletsOpen(
            storeURL: storeURL,
            selectedMetaId: XCTUnwrap(records.first(where: \.isSelected)?.metaId),
            supportedMetaIds: Set(records.map(\.metaId))
        )
        XCTAssertEqual(try walletRecords(at: storeURL), records, "Opening the wallets rewrote a record")
    }

    /// Every wallet with a presentable name maps as supported (blank names
    /// are IK-5's), and wallet setup opens the wallet that was selected.
    private func assertWalletsOpen(
        storeURL: URL,
        selectedMetaId: String,
        supportedMetaIds: Set<String>
    ) throws {
        let facade = try makeFacade(storeURL: storeURL)
        defer { try? facade.databaseService.close() }

        let selections = try selectionModels(facade: facade)
        for selection in selections where supportedMetaIds.contains(selection.identifier) {
            XCTAssertEqual(selection.recordState, .supported, selection.identifier)
            XCTAssertNotNil(selection.wallet, selection.identifier)
        }
        XCTAssertTrue(
            supportedMetaIds.isSubset(of: Set(selections.map(\.identifier))),
            "A wallet identifier changed"
        )

        let selectedWalletSettings = SelectedWalletSettings(
            storageFacade: facade,
            operationQueue: OperationQueue()
        )
        let setupExpectation = expectation(description: "Migrated wallets open")
        var setupResult: Result<MetaAccountModel?, Error>?
        selectedWalletSettings.setup(runningCompletionIn: .main) { result in
            setupResult = result
            setupExpectation.fulfill()
        }
        wait(for: [setupExpectation], timeout: Constants.defaultExpectationDuration)

        let selectedWallet = try XCTUnwrap(try XCTUnwrap(setupResult).get())
        XCTAssertEqual(selectedWallet.metaId, selectedMetaId)
        XCTAssertEqual(selectedWalletSettings.storeState, .ready)
    }

    // MARK: - Fixture wallets

    private func fixtureWallets(for model: NSManagedObjectModel) throws -> [FixtureWallet] {
        let mainId = "historical-sr25519-evm"
        let substrateChainAccountId = Data(repeating: 0x21, count: 32)
        let evmChainAccountId = Data(repeating: 0x31, count: 20)
        let mainSecrets: [String: Data] = [
            fearless.KeystoreTagV2.entropyTagForMetaId(mainId): Data(repeating: 0xA1, count: 16),
            fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(mainId): Data(repeating: 0xA2, count: 64),
            fearless.KeystoreTagV2.substrateSeedTagForMetaId(mainId): Data(repeating: 0xA3, count: 32),
            fearless.KeystoreTagV2.substrateDerivationTagForMetaId(mainId): Data("//polkadot".utf8),
            fearless.KeystoreTagV2.ethereumSecretKeyTagForMetaId(mainId): Data(repeating: 0xA4, count: 32),
            fearless.KeystoreTagV2.ethereumSeedTagForMetaId(mainId): Data(repeating: 0xA5, count: 64),
            fearless.KeystoreTagV2.ethereumDerivationTagForMetaId(mainId): Data("m/44'/60'/0'/0/0".utf8),
            fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(mainId, accountId: substrateChainAccountId):
                Data(repeating: 0xA6, count: 64),
            fearless.KeystoreTagV2.ethereumSecretKeyTagForMetaId(mainId, accountId: evmChainAccountId):
                Data(repeating: 0xA7, count: 32)
        ]
        let ecdsaSecrets: [String: Data] = [
            fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId("historical-ecdsa"): Data(repeating: 0xB1, count: 32),
            fearless.KeystoreTagV2.substrateSeedTagForMetaId("historical-ecdsa"): Data(repeating: 0xB2, count: 32)
        ]
        let blankNameSecrets: [String: Data] = [
            fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId("historical-blank-name"): Data(repeating: 0xC1, count: 64)
        ]
        let mainChainAccounts: [FixtureChainAccount] = [
            FixtureChainAccount(
                chainId: "chain-substrate",
                accountId: substrateChainAccountId,
                publicKey: Data(repeating: 0x22, count: 32),
                cryptoType: Int16(CryptoType.ed25519.rawValue),
                isEthereum: false
            ),
            FixtureChainAccount(
                chainId: "chain-evm",
                accountId: evmChainAccountId,
                publicKey: Data(repeating: 0x32, count: 33),
                cryptoType: Int16(CryptoType.ecdsa.rawValue),
                isEthereum: true
            )
        ]
        var wallets: [FixtureWallet] = [
            FixtureWallet(
                metaId: mainId,
                name: "Main wallet 🛡️",
                order: 0,
                isSelected: true,
                substrateAccountId: Data(repeating: 0x11, count: 32),
                substratePublicKey: Data(repeating: 0x12, count: 32),
                substrateCryptoType: Int16(CryptoType.sr25519.rawValue),
                ethereumAddress: Data(repeating: 0x15, count: 20),
                ethereumPublicKey: Data(repeating: 0x16, count: 33),
                ton: nil,
                chainAccounts: mainChainAccounts,
                hasPreferences: true,
                hasBackup: true,
                secrets: mainSecrets
            ),
            FixtureWallet(
                metaId: "historical-ecdsa",
                name: "ECDSA",
                order: 1,
                isSelected: false,
                substrateAccountId: Data(repeating: 0x41, count: 32),
                substratePublicKey: Data(repeating: 0x42, count: 33),
                substrateCryptoType: Int16(CryptoType.ecdsa.rawValue),
                ethereumAddress: nil,
                ethereumPublicKey: nil,
                ton: nil,
                chainAccounts: [],
                hasPreferences: false,
                hasBackup: nil,
                secrets: ecdsaSecrets
            ),
            FixtureWallet(
                metaId: "historical-blank-name",
                name: "   ",
                order: 2,
                isSelected: false,
                substrateAccountId: Data(repeating: 0x51, count: 32),
                substratePublicKey: Data(repeating: 0x52, count: 32),
                substrateCryptoType: Int16(CryptoType.ed25519.rawValue),
                ethereumAddress: nil,
                ethereumPublicKey: nil,
                ton: nil,
                chainAccounts: [],
                hasPreferences: false,
                hasBackup: false,
                secrets: blankNameSecrets
            )
        ]

        let walletEntity = try XCTUnwrap(model.entitiesByName["CDMetaAccount"])
        if walletEntity.attributesByName["tonPublicKey"] != nil {
            let tonId = "historical-native-ton"
            let tonSecrets: [String: Data] = try [
                fearless.KeystoreTagV2.tonSecretKeyTagForMetaId(tonId): LegacyNativeTonFixture.privateKey(),
                fearless.KeystoreTagV2.entropyTagForMetaId(tonId): Data(LegacyNativeTonFixture.phrase.utf8)
            ]
            try wallets.append(
                FixtureWallet(
                    metaId: tonId,
                    name: "Native TON",
                    order: 3,
                    isSelected: false,
                    substrateAccountId: nil,
                    substratePublicKey: nil,
                    substrateCryptoType: 0,
                    ethereumAddress: nil,
                    ethereumPublicKey: nil,
                    ton: LegacyNativeTonFixture.account(),
                    chainAccounts: [],
                    hasPreferences: false,
                    hasBackup: false,
                    secrets: tonSecrets
                )
            )
        }

        return wallets
    }

    /// A minimal substrate wallet for single-column checks.
    private func makeWallet(metaId: String, order: Int32, isSelected: Bool, hasBackup: Bool?) -> FixtureWallet {
        FixtureWallet(
            metaId: metaId,
            name: metaId,
            order: order,
            isSelected: isSelected,
            substrateAccountId: Data(repeating: UInt8(0x60 + order), count: 32),
            substratePublicKey: Data(repeating: UInt8(0x70 + order), count: 32),
            substrateCryptoType: Int16(CryptoType.sr25519.rawValue),
            ethereumAddress: nil,
            ethereumPublicKey: nil,
            ton: nil,
            chainAccounts: [
                FixtureChainAccount(
                    chainId: "chain-substrate",
                    accountId: Data(repeating: UInt8(0x80 + order), count: 32),
                    publicKey: Data(repeating: UInt8(0x90 + order), count: 32),
                    cryptoType: Int16(CryptoType.sr25519.rawValue),
                    isEthereum: false
                )
            ],
            hasPreferences: false,
            hasBackup: hasBackup,
            secrets: [:]
        )
    }

    private func legacyAccounts() throws -> [LegacyAccount] {
        let addressFactory = SS58AddressFactory()

        func account(
            byte: UInt8,
            username: String,
            publicKeyLength: Int,
            cryptoType: CryptoType,
            entropy: Data?,
            seed: Data?,
            secretKey: Data?,
            derivationPath: Data?
        ) throws -> LegacyAccount {
            let accountId = Data(repeating: byte, count: 32)
            return try LegacyAccount(
                address: addressFactory.address(fromAccountId: accountId, type: 42),
                accountId: accountId,
                username: username,
                publicKey: Data(repeating: byte + 1, count: publicKeyLength),
                cryptoType: Int16(cryptoType.rawValue),
                entropy: entropy,
                seed: seed,
                secretKey: secretKey,
                derivationPath: derivationPath
            )
        }

        return try [
            // Created from a recovery phrase.
            account(
                byte: 0x81,
                username: "Created 1.x",
                publicKeyLength: 32,
                cryptoType: .sr25519,
                entropy: Data(repeating: 0xD1, count: 16),
                seed: Data(repeating: 0xD2, count: 32),
                secretKey: Data(repeating: 0xD3, count: 64),
                derivationPath: Data("//kusama".utf8)
            ),
            // Imported from JSON.
            account(
                byte: 0x91,
                username: "JSON 1.x",
                publicKeyLength: 32,
                cryptoType: .ed25519,
                entropy: nil,
                seed: nil,
                secretKey: Data(repeating: 0xE3, count: 64),
                derivationPath: nil
            ),
            // Imported from a raw seed.
            account(
                byte: 0xA1,
                username: "Seed 1.x",
                publicKeyLength: 33,
                cryptoType: .ecdsa,
                entropy: nil,
                seed: Data(repeating: 0xF2, count: 32),
                secretKey: Data(repeating: 0xF3, count: 32),
                derivationPath: nil
            )
        ]
    }

    private func keychain(for wallets: [FixtureWallet]) -> [String: Data] {
        wallets.reduce(into: [fearless.KeystoreTag.pincode.rawValue: Self.pincode]) { keychain, wallet in
            keychain.merge(wallet.secrets) { _, new in new }
        }
    }

    private func legacySettings() -> InMemorySettingsManager {
        let settings = InMemorySettingsManager()
        settings.set(value: "legacy-account", for: SettingsKey.selectedAccount.rawValue)
        settings.set(value: "legacy-connection", for: SettingsKey.selectedConnection.rawValue)
        settings.set(value: true, for: SettingsKey.biometryEnabled.rawValue)
        return settings
    }

    private func assertLegacySettings(
        _ settings: InMemorySettingsManager,
        removedSelections: Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let expectedSelection: (String) -> String? = { removedSelections ? nil : $0 }
        XCTAssertEqual(
            settings.string(for: SettingsKey.selectedAccount.rawValue),
            expectedSelection("legacy-account"),
            file: file,
            line: line
        )
        XCTAssertEqual(
            settings.string(for: SettingsKey.selectedConnection.rawValue),
            expectedSelection("legacy-connection"),
            file: file,
            line: line
        )
        XCTAssertEqual(settings.bool(for: SettingsKey.biometryEnabled.rawValue), true, file: file, line: line)
    }

    // MARK: - Population

    private func populate(
        _ context: NSManagedObjectContext,
        model: NSManagedObjectModel,
        wallets: [FixtureWallet]
    ) throws {
        try insertObject(
            "CDChainSettings",
            values: ["chainId": "chain-settings", "autobalanced": false, "issueMuted": true],
            in: context,
            model: model
        )
        try insertObject(
            "CDCustomChainNode",
            values: ["name": "Custom node", "url": XCTUnwrap(URL(string: "wss://node.example.invalid"))],
            in: context,
            model: model
        )
        if model.entitiesByName["CDAccountInfo"] != nil {
            try insertObject(
                "CDAccountInfo",
                values: ["identifier": "account-info", "data": Data([0x01, 0x02, 0x03])],
                in: context,
                model: model
            )
        }

        for wallet in wallets {
            try insert(wallet, in: context, model: model)
        }
    }

    private func insert(
        _ wallet: FixtureWallet,
        in context: NSManagedObjectContext,
        model: NSManagedObjectModel
    ) throws {
        var values: [String: Any] = [
            "metaId": wallet.metaId,
            "name": wallet.name,
            "isSelected": wallet.isSelected,
            "order": wallet.order,
            "substrateCryptoType": wallet.substrateCryptoType,
            "favouriteChainIds": (wallet.hasPreferences ? Self.favouriteChainIds : []) as NSArray
        ]
        values["substrateAccountId"] = wallet.substrateAccountId?.toHex()
        values["substratePublicKey"] = wallet.substratePublicKey
        values["ethereumAddress"] = wallet.ethereumAddress?.toHex()
        values["ethereumPublicKey"] = wallet.ethereumPublicKey
        values["tonAddress"] = wallet.ton?.serializedAddress
        values["tonPublicKey"] = wallet.ton?.publicKey
        values["tonContractVersion"] = wallet.ton?.contractVersion
        values["hasBackup"] = wallet.hasBackup

        if wallet.hasPreferences {
            values["canExportEthereumMnemonic"] = true
            values["zeroBalanceAssetsHidden"] = true
            values["assetKeysOrder"] = Self.assetKeysOrder as NSArray
            values["assetFilterOptions"] = Self.assetFilterOptions as NSArray
            values["unusedChainIds"] = Self.unusedChainIds as NSArray
            values["assetIdsEnabled"] = Self.assetKeysOrder as NSArray
            values["chainIdForFilter"] = "chain-filter"
            values["networkManagmentFilter"] = "network-filter"
        }

        let walletObject = try insertObject("CDMetaAccount", values: values, in: context, model: model)

        if wallet.hasPreferences, model.entitiesByName["CDAssetVisibility"] != nil {
            for (assetId, hidden) in [("asset-a", true), ("asset-b", false)] {
                try insertObject(
                    "CDAssetVisibility",
                    values: ["assetId": assetId, "hidden": hidden, "wallet": walletObject],
                    in: context,
                    model: model
                )
            }
        }

        if wallet.hasPreferences, model.entitiesByName["CDCurrency"] != nil {
            let currency = try insertObject(
                "CDCurrency",
                values: [
                    "id": "usd",
                    "symbol": "$",
                    "name": "US Dollar",
                    "icon": "https://icon.example.invalid/usd.svg",
                    "isSelected": true
                ],
                in: context,
                model: model
            )
            walletObject.setValue(currency, forKey: "selectedCurrency")
        }

        for chainAccount in wallet.chainAccounts {
            try insertObject(
                "CDChainAccount",
                values: [
                    "chainId": chainAccount.chainId,
                    "accountId": chainAccount.accountId.toHex(),
                    "publicKey": chainAccount.publicKey,
                    "cryptoType": chainAccount.cryptoType,
                    "ethereumBased": chainAccount.isEthereum,
                    "ecosystem": chainAccount.isEthereum
                        ? UniversalWalletEcosystem.evm.rawValue
                        : UniversalWalletEcosystem.substrate.rawValue,
                    "metaAccount": walletObject
                ],
                in: context,
                model: model
            )
        }
    }

    /// Inserts a row and sets only the properties the entity has, the way a
    /// build with that model could have stored it.
    @discardableResult
    private func insertObject(
        _ entityName: String,
        values: [String: Any],
        in context: NSManagedObjectContext,
        model: NSManagedObjectModel
    ) throws -> NSManagedObject {
        let entity = try XCTUnwrap(model.entitiesByName[entityName], entityName)
        let object = NSManagedObject(entity: entity, insertInto: context)
        for (key, value) in values where entity.propertiesByName[key] != nil {
            object.setValue(value, forKey: key)
        }

        return object
    }

    // MARK: - Expectations

    /// What the current store must hold for a wallet the source build stored.
    /// Columns the source lacked arrive with the defaults the release's own
    /// hops give them.
    private func expectedRecord(for wallet: FixtureWallet, sourceModel model: NSManagedObjectModel) -> WalletRecord {
        let walletProperties = model.entitiesByName["CDMetaAccount"]?.propertiesByName ?? [:]
        let chainAccountProperties = model.entitiesByName["CDChainAccount"]?.propertiesByName ?? [:]
        let has = { (name: String) in walletProperties[name] != nil }
        let preference = { (name: String) in wallet.hasPreferences && has(name) }

        let assetsVisibility: [String: Bool]
        if preference("assetsVisibility") {
            assetsVisibility = ["asset-a": true, "asset-b": false]
        } else if preference("assetIdsEnabled") {
            // What the release's 2.2 hop (MultiassetV9MigrationPolicy, as
            // shipped in App Store 2.2.3) makes of an assetIdsEnabled list.
            assetsVisibility = Dictionary(uniqueKeysWithValues: Self.assetKeysOrder.map { ($0, true) })
        } else {
            assetsVisibility = [:]
        }

        let networkManagmentFilter: String?
        if preference("networkManagmentFilter") {
            networkManagmentFilter = "network-filter"
        } else if preference("chainIdForFilter") {
            networkManagmentFilter = "chain-filter"
        } else {
            networkManagmentFilter = nil
        }

        return WalletRecord(
            metaId: wallet.metaId,
            name: wallet.name,
            isSelected: wallet.isSelected,
            order: wallet.order,
            substrateAccountId: wallet.substrateAccountId?.toHex(),
            substratePublicKey: wallet.substratePublicKey,
            substrateCryptoType: wallet.substrateCryptoType,
            ethereumAddress: wallet.ethereumAddress?.toHex(),
            ethereumPublicKey: wallet.ethereumPublicKey,
            tonAddress: wallet.ton?.serializedAddress,
            tonPublicKey: wallet.ton?.publicKey,
            tonContractVersion: wallet.ton?.contractVersion,
            canExportEthereumMnemonic: preference("canExportEthereumMnemonic"),
            hasBackup: has("hasBackup") ? wallet.hasBackup ?? false : false,
            zeroBalanceAssetsHidden: preference("zeroBalanceAssetsHidden"),
            assetKeysOrder: preference("assetKeysOrder") ? Self.assetKeysOrder : nil,
            assetFilterOptions: preference("assetFilterOptions") ? Self.assetFilterOptions : nil,
            unusedChainIds: preference("unusedChainIds") ? Self.unusedChainIds : nil,
            favouriteChainIds: preference("favouriteChainIds") ? Self.favouriteChainIds : [],
            networkManagmentFilter: networkManagmentFilter,
            assetsVisibility: assetsVisibility,
            selectedCurrencyId: preference("selectedCurrency") ? "usd" : nil,
            chainAccounts: wallet.chainAccounts.map { chainAccount in
                ChainAccountRecord(
                    chainId: chainAccount.chainId,
                    accountId: chainAccount.accountId.toHex(),
                    publicKey: chainAccount.publicKey,
                    cryptoType: chainAccount.cryptoType,
                    // A build before the field read its absence as "in use"; a store that
                    // never ran the 4.0.x ecosystem line gets that label when it is
                    // migrated (`UserStorageMigrator.labelPreEcosystemChainAccounts`).
                    ethereumBased: chainAccountProperties["ethereumBased"] != nil ||
                        chainAccountProperties["ecosystem"] == nil ? chainAccount.isEthereum : nil,
                    ecosystem: chainAccountProperties["ecosystem"] != nil
                        ? (chainAccount.isEthereum ? UniversalWalletEcosystem.evm : .substrate).rawValue
                        : nil
                )
            }.sorted { $0.chainId < $1.chainId }
        )
    }

    private func expectedSettingsRecord(sourceModel model: NSManagedObjectModel) -> SettingsRecord {
        let issueMuted = model.entitiesByName["CDChainSettings"]?.attributesByName["issueMuted"] != nil

        return SettingsRecord(
            chainSettings: ["chain-settings|false|\(issueMuted)"],
            customNodes: ["Custom node|wss://node.example.invalid"],
            currencies: model.entitiesByName["CDCurrency"] != nil
                ? ["usd|$|US Dollar|https://icon.example.invalid/usd.svg|true"]
                : [],
            accountInfos: model.entitiesByName["CDAccountInfo"] != nil ? ["account-info|AQID"] : []
        )
    }

    // MARK: - Reading the current store

    private func walletRecords(at storeURL: URL) throws -> [WalletRecord] {
        var records: [WalletRecord] = []
        try inspectStore(at: storeURL, model: appModel(for: .version14)) { context in
            let wallets = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "CDMetaAccount"))
            records = try wallets.map { try self.walletRecord(from: $0) }.sorted { $0.order < $1.order }
        }

        return records
    }

    private func walletRecord(from wallet: NSManagedObject) throws -> WalletRecord {
        let visibilityRows = (wallet.value(forKey: "assetsVisibility") as? NSSet)?.allObjects as? [NSManagedObject] ?? []
        var assetsVisibility: [String: Bool] = [:]
        for row in visibilityRows {
            let assetId = try XCTUnwrap(row.value(forKey: "assetId") as? String)
            assetsVisibility[assetId] = try XCTUnwrap(row.value(forKey: "hidden") as? NSNumber).boolValue
        }

        let chainRows = (wallet.value(forKey: "chainAccounts") as? NSSet)?.allObjects as? [NSManagedObject] ?? []
        let chainAccounts = try chainRows.map { row in
            try ChainAccountRecord(
                chainId: XCTUnwrap(row.value(forKey: "chainId") as? String),
                accountId: XCTUnwrap(row.value(forKey: "accountId") as? String),
                publicKey: XCTUnwrap(row.value(forKey: "publicKey") as? Data),
                cryptoType: XCTUnwrap(row.value(forKey: "cryptoType") as? NSNumber).int16Value,
                ethereumBased: (row.value(forKey: "ethereumBased") as? NSNumber)?.boolValue,
                ecosystem: row.value(forKey: "ecosystem") as? String
            )
        }.sorted { $0.chainId < $1.chainId }

        let flag = { (key: String) throws -> Bool in
            try XCTUnwrap(wallet.value(forKey: key) as? NSNumber, key).boolValue
        }
        let strings = { (key: String) throws -> [String]? in
            try SafeTransformableValueReader.read(from: wallet, key: key, as: [String].self)
        }

        return try WalletRecord(
            metaId: XCTUnwrap(wallet.value(forKey: "metaId") as? String),
            name: XCTUnwrap(wallet.value(forKey: "name") as? String),
            isSelected: flag("isSelected"),
            order: XCTUnwrap(wallet.value(forKey: "order") as? NSNumber).int32Value,
            substrateAccountId: wallet.value(forKey: "substrateAccountId") as? String,
            substratePublicKey: wallet.value(forKey: "substratePublicKey") as? Data,
            substrateCryptoType: XCTUnwrap(wallet.value(forKey: "substrateCryptoType") as? NSNumber).int16Value,
            ethereumAddress: wallet.value(forKey: "ethereumAddress") as? String,
            ethereumPublicKey: wallet.value(forKey: "ethereumPublicKey") as? Data,
            tonAddress: wallet.value(forKey: "tonAddress") as? Data,
            tonPublicKey: wallet.value(forKey: "tonPublicKey") as? Data,
            tonContractVersion: wallet.value(forKey: "tonContractVersion") as? String,
            canExportEthereumMnemonic: flag("canExportEthereumMnemonic"),
            hasBackup: flag("hasBackup"),
            zeroBalanceAssetsHidden: flag("zeroBalanceAssetsHidden"),
            assetKeysOrder: strings("assetKeysOrder"),
            assetFilterOptions: strings("assetFilterOptions"),
            unusedChainIds: strings("unusedChainIds"),
            favouriteChainIds: strings("favouriteChainIds"),
            networkManagmentFilter: wallet.value(forKey: "networkManagmentFilter") as? String,
            assetsVisibility: assetsVisibility,
            selectedCurrencyId: (wallet.value(forKey: "selectedCurrency") as? NSManagedObject)?
                .value(forKey: "id") as? String,
            chainAccounts: chainAccounts
        )
    }

    private func settingsRecord(at storeURL: URL) throws -> SettingsRecord {
        var record: SettingsRecord?
        try inspectStore(at: storeURL, model: appModel(for: .version14)) { context in
            func rows(_ entityName: String, _ describe: (NSManagedObject) -> String) throws -> [String] {
                try context.fetch(NSFetchRequest<NSManagedObject>(entityName: entityName)).map(describe).sorted()
            }
            func text(_ object: NSManagedObject, _ key: String) -> String {
                object.value(forKey: key).map { "\($0)" } ?? "nil"
            }
            func flag(_ object: NSManagedObject, _ key: String) -> String {
                (object.value(forKey: key) as? NSNumber).map { "\($0.boolValue)" } ?? "nil"
            }

            record = try SettingsRecord(
                chainSettings: rows("CDChainSettings") {
                    [text($0, "chainId"), flag($0, "autobalanced"), flag($0, "issueMuted")].joined(separator: "|")
                },
                customNodes: rows("CDCustomChainNode") {
                    [text($0, "name"), (($0.value(forKey: "url") as? URL)?.absoluteString ?? "nil")]
                        .joined(separator: "|")
                },
                currencies: rows("CDCurrency") {
                    [text($0, "id"), text($0, "symbol"), text($0, "name"), text($0, "icon"), flag($0, "isSelected")]
                        .joined(separator: "|")
                },
                accountInfos: rows("CDAccountInfo") {
                    [text($0, "identifier"), ($0.value(forKey: "data") as? Data)?.base64EncodedString() ?? "nil"]
                        .joined(separator: "|")
                }
            )
        }

        return try XCTUnwrap(record)
    }

    private func storedBackupFlags(at storeURL: URL, model: NSManagedObjectModel) throws -> [String: Bool?] {
        var flags: [String: Bool?] = [:]
        try inspectStore(at: storeURL, model: model) { context in
            for wallet in try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "CDMetaAccount")) {
                let metaId = try XCTUnwrap(wallet.value(forKey: "metaId") as? String)
                flags[metaId] = .some((wallet.value(forKey: "hasBackup") as? NSNumber)?.boolValue)
            }
        }

        return flags
    }

    private func selectionModels(facade: UserDataStorageFacade) throws -> [MetaAccountSelectionModel] {
        let repository = facade.createRepository(
            filter: nil,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(MetaAccountSelectionMapper())
        )
        let operation = repository.fetchAllOperation(
            with: RepositoryFetchOptions(includesProperties: true, includesSubentities: true)
        )
        OperationQueue().addOperations([operation], waitUntilFinished: true)

        return try XCTUnwrap(operation.result).get()
    }

    // MARK: - Fail-closed helpers

    /// Changes the staged landing store before validation. The migration
    /// must refuse it every time, and leave the store and Keychain exactly as
    /// the build wrote them.
    private func assertStagedLandingMutationFailsClosed(
        storeURL: URL,
        landing: UserStorageVersion,
        sql: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let before = try durableStoreFamilySnapshot(at: storeURL)
        let keystore = SnapshotKeystore(values: [fearless.KeystoreTag.pincode.rawValue: Self.pincode])
        var mutationCount = 0
        let migrator = makeMigrator(
            storeURL: storeURL,
            keystore: keystore,
            stagedStoreWillValidate: { stagedURL, version in
                guard version == landing else { return }
                mutationCount += 1
                try self.executeSQLite(sql, at: stagedURL)
            }
        )

        for attempt in 1 ... 2 {
            XCTAssertThrowsError(try migrator.performMigration(), file: file, line: line) { error in
                guard
                    let migrationError = error as? UserStorageMigrationError,
                    case .stagedStoreValidationFailed = migrationError
                else {
                    return XCTFail("Expected stagedStoreValidationFailed, got \(error)", file: file, line: line)
                }
            }
            XCTAssertEqual(mutationCount, attempt, file: file, line: line)
            XCTAssertEqual(try durableStoreFamilySnapshot(at: storeURL), before, file: file, line: line)
            XCTAssertEqual(keystore.values, [fearless.KeystoreTag.pincode.rawValue: Self.pincode], file: file, line: line)
        }
    }

    // MARK: - Models and stores

    private func userEntries() throws -> [HistoricalModel] {
        try UpgradeFixtureLoader.historicalStoreModels().filter { $0.store == .user }
    }

    private func userEntry(digest: String) throws -> HistoricalModel {
        try XCTUnwrap(userEntries().first { $0.digest == digest }, digest)
    }

    private func releaseSummary(_ entry: HistoricalModel) -> String {
        let releases = entry.releases + entry.interimTags + entry.heads.map(\.title)
        guard let first = releases.first else {
            return entry.resource
        }

        return releases.count > 1 ? "\(first) … \(releases[releases.count - 1])" : first
    }

    private func appModel(for version: UserStorageVersion) throws -> NSManagedObjectModel {
        let modelURL = version.modelURL(in: appBundle, legacyModelDirectory: UserStorageParams.modelDirectory)

        return try XCTUnwrap(
            modelURL.flatMap(NSManagedObjectModel.init(contentsOf:)),
            "Unable to load \(version.rawValue) from the app bundle"
        )
    }

    private func propertyNames(in model: NSManagedObjectModel) -> Set<String> {
        model.entitiesByName.reduce(into: Set<String>()) { names, element in
            names.insert(element.key)
            for propertyName in element.value.propertiesByName.keys {
                names.insert("\(element.key).\(propertyName)")
            }
        }
    }

    private func changedAttributes(from source: NSManagedObjectModel, to destination: NSManagedObjectModel) -> Set<String> {
        var changed = Set<String>()
        for (entityName, sourceEntity) in source.entitiesByName {
            guard let destinationEntity = destination.entitiesByName[entityName] else { continue }

            for (name, attribute) in sourceEntity.attributesByName {
                guard let other = destinationEntity.attributesByName[name] else { continue }

                if attribute.attributeType != other.attributeType ||
                    attribute.isOptional != other.isOptional ||
                    attribute.valueTransformerName != other.valueTransformerName ||
                    attribute.defaultValue.map({ "\($0)" }) != other.defaultValue.map({ "\($0)" }) {
                    changed.insert("\(entityName).\(name)")
                }
            }
        }

        return changed
    }

    private func caseStoreURL(_ name: String) throws -> URL {
        let directory = testDirectory.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        return directory.appendingPathComponent(UserStorageParams.databaseName)
    }

    private func makeMigrator(
        storeURL: URL,
        keystore: KeystoreProtocol = InMemoryKeychain(),
        settings: SettingsManagerProtocol = InMemorySettingsManager(),
        modelBundle: Bundle? = nil,
        stagedStoreWillValidate: @escaping (URL, UserStorageVersion) throws -> Void = { _, _ in },
        storeReplacementBoundaryHook: @escaping (CrashConsistentStoreReplacementBoundary) throws -> Void = { _ in }
    ) -> UserStorageMigrator {
        UserStorageMigrator(
            targetVersion: UserStorageParams.modelVersion,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: keystore,
            settings: settings,
            fileManager: .default,
            modelBundle: modelBundle ?? appBundle,
            stagedStoreWillValidate: stagedStoreWillValidate,
            storeReplacementBoundaryHook: storeReplacementBoundaryHook
        )
    }

    private func makeFacade(storeURL: URL) throws -> UserDataStorageFacade {
        XCTAssertEqual(storeURL.lastPathComponent, UserStorageParams.databaseName)

        return try UserDataStorageFacade(
            modelURL: XCTUnwrap(
                UserStorageVersion.version14.modelURL(in: appBundle, legacyModelDirectory: UserStorageParams.modelDirectory)
            ),
            databaseDirectory: storeURL.deletingLastPathComponent()
        )
    }

    /// A copy of the app's User models whose historical folder `customize`
    /// may change.
    private func makeModelBundle(customize: (URL) throws -> Void) throws -> Bundle {
        let bundleURL = testDirectory.appendingPathComponent(
            "UserModels-\(UUID().uuidString).bundle",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)

        let infoPlist: [String: Any] = [
            "CFBundleIdentifier": "jp.co.soramitsu.fearlesswallet.tests.historical-user-models.\(UUID().uuidString)",
            "CFBundleName": "HistoricalUserModels",
            "CFBundlePackageType": "BNDL",
            "CFBundleVersion": "1"
        ]
        try PropertyListSerialization.data(fromPropertyList: infoPlist, format: .xml, options: 0)
            .write(to: bundleURL.appendingPathComponent("Info.plist"))

        let lineageBundleName = try XCTUnwrap(
            UserStorageParams.modelDirectory.components(separatedBy: "/").first
        )
        try FileManager.default.copyItem(
            at: appBundle.bundleURL.appendingPathComponent(lineageBundleName, isDirectory: true),
            to: bundleURL.appendingPathComponent(lineageBundleName, isDirectory: true)
        )
        for version in [UserStorageVersion.version13, .version14] {
            let modelURL = try XCTUnwrap(
                version.modelURL(in: appBundle, legacyModelDirectory: UserStorageParams.modelDirectory)
            )
            try FileManager.default.copyItem(at: modelURL, to: bundleURL.appendingPathComponent(modelURL.lastPathComponent))
        }

        let historicalDirectory = bundleURL.appendingPathComponent(
            UserStorageVersion.historicalModelDirectory,
            isDirectory: true
        )
        try FileManager.default.copyItem(
            at: XCTUnwrap(appBundle.url(forResource: UserStorageVersion.historicalModelDirectory, withExtension: nil)),
            to: historicalDirectory
        )
        try customize(historicalDirectory)

        return try XCTUnwrap(Bundle(url: bundleURL))
    }

    private func createStore(
        at url: URL,
        model: NSManagedObjectModel,
        populate: (NSManagedObjectContext) throws -> Void
    ) throws {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let store = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: url,
            options: [
                NSSQLitePragmasOption: ["journal_mode": "WAL"],
                NSMigratePersistentStoresAutomaticallyOption: false,
                NSInferMappingModelAutomaticallyOption: false
            ]
        )
        defer {
            try? coordinator.remove(store)
        }

        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator

        var populationError: Error?
        context.performAndWait {
            do {
                try populate(context)
                if context.hasChanges {
                    try context.save()
                }
            } catch {
                populationError = error
            }
        }

        if let populationError {
            throw populationError
        }
    }

    private func inspectStore(
        at url: URL,
        model: NSManagedObjectModel,
        body: (NSManagedObjectContext) throws -> Void
    ) throws {
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

        var inspectionError: Error?
        context.performAndWait {
            do {
                try body(context)
            } catch {
                inspectionError = error
            }
        }

        if let inspectionError {
            throw inspectionError
        }
    }

    private func count(_ entityName: String, at url: URL, model: NSManagedObjectModel) throws -> Int {
        var result = 0
        try inspectStore(at: url, model: model) { context in
            result = try context.count(for: NSFetchRequest<NSFetchRequestResult>(entityName: entityName))
        }
        return result
    }

    private func durableStoreFamilySnapshot(at url: URL) throws -> [String: Data] {
        let directory = url.deletingLastPathComponent()
        let fileNames = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasPrefix(url.lastPathComponent) && !$0.hasSuffix("-shm") }

        return try Dictionary(
            uniqueKeysWithValues: fileNames.map { fileName in
                try (fileName, Data(contentsOf: directory.appendingPathComponent(fileName)))
            }
        )
    }

    private func sqliteCount(_ sql: String, at url: URL) throws -> Int {
        var database: OpaquePointer?
        guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let database else {
            sqlite3_close(database)
            throw NSError(domain: "HistoricalUserStoreUpgradeTests.SQLite", code: 1)
        }
        defer {
            sqlite3_close(database)
        }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw NSError(domain: "HistoricalUserStoreUpgradeTests.SQLite", code: 2)
        }
        defer {
            sqlite3_finalize(statement)
        }

        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw NSError(domain: "HistoricalUserStoreUpgradeTests.SQLite", code: 3)
        }

        return Int(sqlite3_column_int64(statement, 0))
    }

    private func executeSQLite(_ sql: String, at url: URL) throws {
        var database: OpaquePointer?
        guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK, let database else {
            sqlite3_close(database)
            throw NSError(domain: "HistoricalUserStoreUpgradeTests.SQLite", code: 1)
        }
        defer {
            sqlite3_close(database)
        }

        var errorMessage: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(database, sql, nil, nil, &errorMessage)
        defer {
            sqlite3_free(errorMessage)
        }
        guard result == SQLITE_OK, sqlite3_changes(database) > 0 else {
            throw NSError(
                domain: "HistoricalUserStoreUpgradeTests.SQLite",
                code: Int(result),
                userInfo: [NSLocalizedDescriptionKey: errorMessage.map { String(cString: $0) } ?? "No row changed"]
            )
        }
    }
}

/// A Keychain whose whole contents can be compared before and after.
private final class SnapshotKeystore: KeystoreProtocol {
    private(set) var values: [String: Data]
    private(set) var deletedIdentifiers: [String] = []

    init(values: [String: Data]) {
        self.values = values
    }

    func addKey(_ key: Data, with identifier: String) throws {
        guard values[identifier] == nil else {
            throw KeystoreError.duplicatedItem
        }

        values[identifier] = key
    }

    func updateKey(_ key: Data, with identifier: String) throws {
        values[identifier] = key
    }

    func fetchKey(for identifier: String) throws -> Data {
        guard let key = values[identifier] else {
            throw KeystoreError.noKeyFound
        }

        return key
    }

    func checkKey(for identifier: String) throws -> Bool {
        values[identifier] != nil
    }

    func deleteKey(for identifier: String) throws {
        guard values.removeValue(forKey: identifier) != nil else {
            throw KeystoreError.noKeyFound
        }

        deletedIdentifiers.append(identifier)
    }
}
