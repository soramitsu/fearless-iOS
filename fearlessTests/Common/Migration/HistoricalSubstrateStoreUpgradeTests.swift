import CoreData
import SQLite3
import XCTest
@testable import fearless

/// IK-2: every Substrate store model a build ever wrote is recognised by
/// exactly one model and reaches v10 without losing protected local data. A
/// store that still cannot be used never stops the app from opening: it is
/// kept whole in the retained archive (addendum U0.5).
///
/// The stores are created from the verbatim Git-history models (IK-1 test
/// fixtures) and migrated with the app bundle, so these tests exercise the
/// models and migrator that ship. Expectations are read back from the
/// fixture store with plain Core Data, never from the migrator's own digest.
final class HistoricalSubstrateStoreUpgradeTests: XCTestCase {
    private typealias HistoricalModel = UpgradeFixtureLoader.HistoricalStoreModel

    /// The values the migrator protects, compared on every fixture.
    private static let protectedAttributeNames: [String: [String]] = [
        "CDContact": ["address", "chainId", "name"],
        "CDContactItem": [
            "identifier",
            "peerAddress",
            "peerName",
            "targetAddress",
            "updatedAt"
        ],
        "CDTransactionHistoryItem": [
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
        "CDChain": ["chainId", "ecosystem", "name", "tonBridgeUrl"],
        "CDTonConnectedApp": [
            "appUrl",
            "clientId",
            "connectionType",
            "iconUrl",
            "identifier",
            "name",
            "privateKey",
            "publicKey",
            "walletId"
        ],
        "CDTonDapp": [
            "appDescription",
            "chains",
            "icon",
            "identifier",
            "isConnected",
            "name",
            "poster",
            "url"
        ]
    ]

    /// Entities populated with a value for every attribute; every attribute
    /// they share with v10 must arrive unchanged.
    private static let fullyPopulatedEntityNames = [
        "CDContact",
        "CDContactItem",
        "CDTransactionHistoryItem",
        "CDRuntimeMetadataItem",
        "CDChainStorageItem",
        "CDPolkaswapRemoteSettings",
        "CDPolkaswapDex",
        "CDTonConnectedApp",
        "CDTonDapp"
    ]

    private static let comparedEntityNames =
        fullyPopulatedEntityNames + ["CDChain"]

    private static let version8StartupEntityNames = [
        "CDAsset",
        "CDChain",
        "CDChainNode",
        "CDChainXcmConfig",
        "CDExternalApi",
        "CDPriceData",
        "CDPriceProvider",
        "CDRuntimeMetadataItem",
        "CDXcmAvailableAsset",
        "CDXcmAvailableDestination"
    ]

    private static let version8StartupToManyRelationships = [
        ("CDAsset", "priceData"),
        ("CDChain", "assets"),
        ("CDChain", "customNodes"),
        ("CDChain", "explorers"),
        ("CDChain", "nodes"),
        ("CDChainXcmConfig", "availableAssets"),
        ("CDChainXcmConfig", "availableDestinations"),
        ("CDXcmAvailableDestination", "assets")
    ]

    private static let purchaseProviders = ["historical-provider"]
    private static let tonPrivateKey = Data([0x01, 0x23, 0x45, 0x67])
    private static let tonBridgeURL = URL(string: "https://bridge.example.invalid/ton")

    private var testDirectory: URL!

    private var appBundle: Bundle {
        Bundle(for: SubstrateDataStorageFacade.self)
    }

    override func setUpWithError() throws {
        try super.setUpWithError()

        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HistoricalSubstrateStoreUpgradeTests")
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

    func testHistoricalManifest_matchesSubstrateEnumCases() throws {
        let entries = try substrateEntries()
        let bundledEntries = entries.filter(\.isAppBundled)
        let historicalCases = SubstrateStorageVersion.allCases.filter(\.isHistoricalResource)

        XCTAssertEqual(
            Set(historicalCases.map(\.rawValue)),
            Set(bundledEntries.map(\.resource)),
            "Every app-bundled manifest entry needs exactly one case and vice versa"
        )
        XCTAssertEqual(historicalCases.count, Set(historicalCases.map(\.rawValue)).count)

        for entry in bundledEntries {
            let version = try XCTUnwrap(SubstrateStorageVersion(rawValue: entry.resource), entry.resource)
            let allowedDrops = try XCTUnwrap(entry.allowedDrops, entry.resource)

            XCTAssertTrue(version.isCompatibilityResource, entry.resource)
            XCTAssertEqual(version.nextVersion()?.rawValue, entry.landing, entry.resource)
            XCTAssertEqual(version.historicalAllowedDrops.entities, Set(allowedDrops.entities), entry.resource)
            XCTAssertEqual(version.historicalAllowedDrops.attributes, Set(allowedDrops.attributes), entry.resource)
            XCTAssertEqual(version.historicalRequiredConstants, entry.requiredConstants, entry.resource)
            XCTAssertEqual(
                UpgradeFixtureLoader.schemaDigest(of: try appModel(for: version)),
                entry.digest,
                entry.resource
            )
        }

        for entry in entries {
            if let bundledName = entry.matchesBundled {
                let version = try XCTUnwrap(SubstrateStorageVersion(rawValue: bundledName), bundledName)
                XCTAssertFalse(version.isHistoricalResource, entry.resource)
            }
            if entry.excluded != nil {
                XCTAssertNil(SubstrateStorageVersion(rawValue: entry.resource), entry.resource)
            }
        }

        for version in SubstrateStorageVersion.allCases where !version.isHistoricalResource {
            XCTAssertTrue(version.historicalAllowedDrops.entities.isEmpty, version.rawValue)
            XCTAssertTrue(version.historicalAllowedDrops.attributes.isEmpty, version.rawValue)
            XCTAssertTrue(version.historicalRequiredConstants.isEmpty, version.rawValue)
        }

        XCTAssertEqual(SubstrateStorageVersion.current, .version10)
        XCTAssertEqual(SubstrateStorageParams.modelVersion, .version10)
    }

    func testEverySubstrateModelHasUniqueVersionHashes() throws {
        let hashes = try SubstrateStorageVersion.allCases.map { version in
            (version, try appModel(for: version).entityVersionHashesByName)
        }

        for (index, lhs) in hashes.enumerated() {
            for rhs in hashes[(index + 1)...] {
                XCTAssertNotEqual(lhs.1, rhs.1, "\(lhs.0.rawValue) and \(rhs.0.rawValue) open the same stores")
            }
        }
    }

    func testHistoricalCases_requireStartupGraphBoundsExactlyWhenTheyLandOnV10WithTheWholeStartupGraph() throws {
        for version in SubstrateStorageVersion.allCases where version.isHistoricalResource {
            let model = try appModel(for: version)
            let hasStartupGraph =
                Self.version8StartupEntityNames.allSatisfy { model.entitiesByName[$0] != nil } &&
                Self.version8StartupToManyRelationships.allSatisfy { entityName, relationshipName in
                    model.entitiesByName[entityName]?.relationshipsByName[relationshipName]?.isToMany == true
                }

            XCTAssertEqual(
                version.requiresStartupGraphBounds,
                version.nextVersion() == .version10 && hasStartupGraph,
                version.rawValue
            )
        }
    }

    func testDetection_eachReleaseFixtureMatchesExactlyOneVersion() throws {
        let models = try SubstrateStorageVersion.allCases.map { ($0, try appModel(for: $0)) }

        for entry in try substrateEntries() {
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

            let expected: [String]
            if entry.isAppBundled {
                expected = [entry.resource]
            } else if let bundledName = entry.matchesBundled {
                expected = [bundledName]
            } else {
                expected = []
            }

            XCTAssertEqual(matches, expected, "\(entry.digest) \(releaseSummary(entry))")
            XCTAssertEqual(
                makeMigrator(storeURL: storeURL).requiresMigration(),
                expected != [SubstrateStorageVersion.version10.rawValue],
                entry.resource
            )
        }
    }

    func testDetection_whenModelIsExcluded_thenMigrationFailsClosedAndStartupKeepsTheStoreWhole() throws {
        let excludedEntries = try substrateEntries().filter { $0.excluded != nil }
        XCTAssertFalse(excludedEntries.isEmpty)

        for entry in excludedEntries {
            let storeURL = try caseStoreURL(entry.resource)
            let fixtureModel = try UpgradeFixtureLoader.fixtureModel(for: entry)
            try createStore(at: storeURL, model: fixtureModel) { context in
                try self.insertObject(
                    "CDContact",
                    values: ["name": "Alice", "address": "5Alice"],
                    in: context,
                    model: fixtureModel
                )
            }
            let before = try durableStoreFamilySnapshot(at: storeURL)
            let migrator = makeMigrator(storeURL: storeURL)

            XCTAssertThrowsError(try migrator.performMigration()) { error in
                guard
                    let migrationError = error as? SubstrateStorageMigrationError,
                    case .unknownStoreVersion = migrationError
                else {
                    return XCTFail("Expected unknownStoreVersion for \(entry.digest), got \(error)")
                }
            }
            XCTAssertEqual(try durableStoreFamilySnapshot(at: storeURL), before, entry.resource)

            try assertStartupSetsWholeStoreAside(migrator, at: storeURL, family: before, label: entry.resource)
        }
    }

    func testDetection_whenTwoBundledModelsMatchTheStore_thenFailsClosedAndStartupKeepsTheStoreWhole() throws {
        // A bundle in which a historical resource is a copy of the v10 model.
        let modelBundle = try makeModelBundle { historicalDirectory in
            let currentModelURL = try XCTUnwrap(
                SubstrateStorageVersion.version10.modelURL(
                    in: self.appBundle,
                    modelDirectory: SubstrateStorageParams.modelDirectory
                )
            )
            let duplicateURL = historicalDirectory
                .appendingPathComponent(SubstrateStorageVersion.historical186efaed.rawValue)
                .appendingPathExtension(currentModelURL.pathExtension)
            try? FileManager.default.removeItem(at: duplicateURL)
            try FileManager.default.copyItem(at: currentModelURL, to: duplicateURL)
        }
        let storeURL = try caseStoreURL("ambiguous")
        let currentModel = try appModel(for: .version10)
        try createStore(at: storeURL, model: currentModel) { context in
            try self.insertObject("CDContact", values: ["name": "Alice"], in: context, model: currentModel)
        }
        let before = try durableStoreFamilySnapshot(at: storeURL)
        let migrator = makeMigrator(storeURL: storeURL, modelBundle: modelBundle)

        XCTAssertTrue(migrator.requiresMigration())
        for _ in 0 ..< 2 {
            XCTAssertThrowsError(try migrator.performMigrationWithRecovery()) { error in
                guard
                    let migrationError = error as? SubstrateStorageMigrationError,
                    case .ambiguousStoreVersion = migrationError
                else {
                    return XCTFail("Expected ambiguousStoreVersion, got \(error)")
                }
                XCTAssertFalse(migrationError.allowsCacheRebuild)
            }
            XCTAssertEqual(try durableStoreFamilySnapshot(at: storeURL), before)
            XCTAssertTrue(try recoveryDirectories(besides: storeURL).isEmpty)
        }

        try assertStartupSetsWholeStoreAside(migrator, at: storeURL, family: before, label: "ambiguous")
    }

    // MARK: - Every release

    func testUpgrade_everySubstrateRelease_emptyStore() throws {
        for entry in try migratableEntries() {
            try XCTContext.runActivity(named: "\(entry.digest) \(releaseSummary(entry))") { _ in
                let storeURL = try caseStoreURL(entry.resource)
                try createStore(at: storeURL, model: UpgradeFixtureLoader.fixtureModel(for: entry)) { _ in }
                let migrator = makeMigrator(storeURL: storeURL)

                try migrator.migrate()

                try assertIsCurrentStore(at: storeURL, migrator: migrator, entry: entry)
                for entityName in try appModel(for: .version10).entitiesByName.keys {
                    XCTAssertEqual(
                        try count(entityName, at: storeURL, model: appModel(for: .version10)),
                        0,
                        "\(entry.digest) created \(entityName) rows"
                    )
                }
            }
        }
    }

    func testUpgrade_everySubstrateRelease_populatedStore() throws {
        for entry in try migratableEntries() {
            try XCTContext.runActivity(named: "\(entry.digest) \(releaseSummary(entry))") { _ in
                let storeURL = try caseStoreURL(entry.resource)
                let fixtureModel = try UpgradeFixtureLoader.fixtureModel(for: entry)
                try createStore(at: storeURL, model: fixtureModel) { context in
                    try self.populate(context, model: fixtureModel)
                }
                let expected = try expectations(for: entry, at: storeURL, model: fixtureModel)
                let migrator = makeMigrator(storeURL: storeURL)

                try migrator.migrate()

                try assertMigrated(expected, at: storeURL, entry: entry)
                try assertIsCurrentStore(at: storeURL, migrator: migrator, entry: entry)
            }
        }
    }

    func testUpgrade_everyHistoricalModel_dropsExactlyTheManifestAllowlist() throws {
        for entry in try substrateEntries() where entry.isAppBundled {
            let version = try XCTUnwrap(SubstrateStorageVersion(rawValue: entry.resource))
            let landing = try XCTUnwrap(version.nextVersion())
            let source = try UpgradeFixtureLoader.fixtureModel(for: entry)
            let destination = try appModel(for: landing)

            let droppedEntities = Set(source.entitiesByName.keys).subtracting(destination.entitiesByName.keys)
            var droppedProperties = Set<String>()
            for (entityName, entity) in source.entitiesByName {
                guard let destinationEntity = destination.entitiesByName[entityName] else { continue }
                for propertyName in entity.propertiesByName.keys
                    where destinationEntity.propertiesByName[propertyName] == nil {
                    droppedProperties.insert("\(entityName).\(propertyName)")
                }
            }

            let allowedDrops = try XCTUnwrap(entry.allowedDrops)
            XCTAssertEqual(droppedEntities, Set(allowedDrops.entities), entry.resource)
            XCTAssertEqual(droppedProperties, Set(allowedDrops.attributes), entry.resource)
        }
    }

    // MARK: - Specific histories

    func testUpgrade_v1_0to1_6_historyGetsTransferCallPathAndRowsSurvive() throws {
        for digest in ["27378408dc2e9402", "d713024629483ef3"] {
            let entry = try substrateEntry(digest: digest)
            let fixtureModel = try UpgradeFixtureLoader.fixtureModel(for: entry)
            let historyEntity = try XCTUnwrap(fixtureModel.entitiesByName["CDTransactionHistoryItem"])
            XCTAssertNil(historyEntity.attributesByName["callName"])
            XCTAssertNotNil(historyEntity.attributesByName["amount"])

            let storeURL = try caseStoreURL(entry.resource)
            try createStore(at: storeURL, model: fixtureModel) { context in
                for index in 0 ..< 3 {
                    try self.insertObject(
                        "CDTransactionHistoryItem",
                        values: [
                            "identifier": "local-transfer-\(index)",
                            "sender": "5Sender\(index)",
                            "receiver": "5Receiver\(index)",
                            "amount": "1.\(index)",
                            "fee": "0.01"
                        ],
                        in: context,
                        model: fixtureModel
                    )
                }
                try self.insertObject(
                    "CDContactItem",
                    values: ["peerAddress": "5Peer", "peerName": "Peer"],
                    in: context,
                    model: fixtureModel
                )
            }

            try makeMigrator(storeURL: storeURL).migrate()

            let currentModel = try appModel(for: .version10)
            try inspectStore(at: storeURL, model: currentModel) { context in
                let history = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "CDTransactionHistoryItem"))
                    .sorted { ($0.value(forKey: "identifier") as? String ?? "") < ($1.value(forKey: "identifier") as? String ?? "") }

                XCTAssertEqual(history.count, 3, digest)
                for (index, item) in history.enumerated() {
                    XCTAssertEqual(item.value(forKey: "identifier") as? String, "local-transfer-\(index)")
                    XCTAssertEqual(item.value(forKey: "sender") as? String, "5Sender\(index)")
                    XCTAssertEqual(item.value(forKey: "receiver") as? String, "5Receiver\(index)")
                    XCTAssertEqual(item.value(forKey: "fee") as? String, "0.01")
                    XCTAssertEqual(item.value(forKey: "callName") as? String, "transfer")
                    XCTAssertEqual(item.value(forKey: "moduleName") as? String, "Balances")
                    XCTAssertNil(item.value(forKey: "call"))
                }

                let contactItem = try XCTUnwrap(
                    context.fetch(NSFetchRequest<NSManagedObject>(entityName: "CDContactItem")).first
                )
                XCTAssertEqual(contactItem.value(forKey: "peerAddress") as? String, "5Peer")
                XCTAssertEqual(contactItem.value(forKey: "peerName") as? String, "Peer")
            }
        }
    }

    func testUpgrade_2_0_0to2_0_3_chainWithoutSelectedNode_selectsTheNodeTheV2PolicyPicks() throws {
        let entry = try substrateEntry(digest: "6ca82510c9ee52ee")
        let fixtureModel = try UpgradeFixtureLoader.fixtureModel(for: entry)
        let chainEntity = try XCTUnwrap(fixtureModel.entitiesByName["CDChain"])
        XCTAssertNil(chainEntity.relationshipsByName["selectedNode"])
        XCTAssertNil(chainEntity.relationshipsByName["customNodes"])

        let storeURL = try caseStoreURL(entry.resource)
        try createStore(at: storeURL, model: fixtureModel) { context in
            let chain = try self.insertObject(
                "CDChain",
                values: ["chainId": "polkadot", "name": "Polkadot"],
                in: context,
                model: fixtureModel
            )
            // The URL order and the name order disagree on purpose.
            for (name, url) in [
                ("Parity", "wss://rpc.polkadot.io"),
                ("Dwellir", "wss://polkadot-rpc.dwellir.com"),
                ("Radium", "wss://dot-rpc.radiumblock.co")
            ] {
                try self.insertObject(
                    "CDChainNode",
                    values: ["name": name, "url": try XCTUnwrap(URL(string: url)), "chain": chain],
                    in: context,
                    model: fixtureModel
                )
            }
        }

        try makeMigrator(storeURL: storeURL).migrate()

        try inspectStore(at: storeURL, model: appModel(for: .version10)) { context in
            let chain = try XCTUnwrap(context.fetch(NSFetchRequest<NSManagedObject>(entityName: "CDChain")).first)
            let selectedNode = try XCTUnwrap(chain.value(forKey: "selectedNode") as? NSManagedObject)

            XCTAssertEqual(
                selectedNode.value(forKey: "url") as? URL,
                URL(string: "wss://dot-rpc.radiumblock.co")
            )
            XCTAssertEqual((chain.value(forKey: "nodes") as? Set<NSManagedObject>)?.count, 3)
            XCTAssertEqual((chain.value(forKey: "customNodes") as? Set<NSManagedObject>)?.count, 0)
        }
    }

    func testV2NodeSelection_everyModelReachingThePolicyHasUniqueNodeURLs() throws {
        // ChainSubstrateV2MigrationPolicy orders nodes by URL first; the
        // protected-data check repeats that order on the source store, which
        // is only deterministic because node URLs cannot repeat.
        let versions = SubstrateStorageVersion.allCases.filter {
            $0 == .version1 || $0.nextVersion() == .version1
        }
        XCTAssertGreaterThan(versions.count, 1)

        for version in versions {
            guard let nodeEntity = try appModel(for: version).entitiesByName["CDChainNode"] else {
                continue
            }

            let constraints = nodeEntity.uniquenessConstraints.map { $0.compactMap { $0 as? String } }
            XCTAssertTrue(constraints.contains(["url"]), version.rawValue)
        }
    }

    func testUpgrade_historicalV8_preservesTonPrivateKeyAndBridgeUrlNil() throws {
        for digest in ["201c41162d1b1604", "186efaedb554f36c"] {
            let entry = try substrateEntry(digest: digest)
            let fixtureModel = try UpgradeFixtureLoader.fixtureModel(for: entry)
            let sourceHasBridgeURL = fixtureModel.entitiesByName["CDChain"]?.attributesByName["tonBridgeUrl"] != nil
            let storeURL = try caseStoreURL(entry.resource)
            try createStore(at: storeURL, model: fixtureModel) { context in
                try self.populate(context, model: fixtureModel)
            }

            try makeMigrator(storeURL: storeURL).migrate()

            try inspectStore(at: storeURL, model: appModel(for: .version10)) { context in
                let app = try XCTUnwrap(
                    context.fetch(NSFetchRequest<NSManagedObject>(entityName: "CDTonConnectedApp")).first,
                    digest
                )
                XCTAssertEqual(app.value(forKey: "privateKey") as? Data, Self.tonPrivateKey, digest)
                XCTAssertNil(app.value(forKey: "connectionType"), digest)

                let chain = try XCTUnwrap(
                    context.fetch(NSFetchRequest<NSManagedObject>(entityName: "CDChain")).first,
                    digest
                )
                if sourceHasBridgeURL {
                    XCTAssertEqual(chain.value(forKey: "tonBridgeUrl") as? URL, Self.tonBridgeURL, digest)
                } else {
                    XCTAssertNil(chain.value(forKey: "tonBridgeUrl"), digest)
                }
            }
        }
    }

    // MARK: - Failing closed

    func testUpgrade_historicalUnexpectedDrop_failsClosedAndNeverDropsTheValue() throws {
        let entry = try substrateEntry(digest: "d484c09eddea88ca")
        let version = try XCTUnwrap(SubstrateStorageVersion(rawValue: entry.resource))
        // The same resource name, but with a contact attribute the landing
        // model does not have and the allowlist does not name.
        let tamperedModel = try XCTUnwrap(appModel(for: version).copy() as? NSManagedObjectModel)
        let contactEntity = try XCTUnwrap(tamperedModel.entitiesByName["CDContact"])
        let note = NSAttributeDescription()
        note.name = "legacyNote"
        note.attributeType = .stringAttributeType
        note.isOptional = true
        contactEntity.properties.append(note)
        let tamperedData = try NSKeyedArchiver.archivedData(withRootObject: tamperedModel, requiringSecureCoding: false)
        let modelBundle = try makeModelBundle { historicalDirectory in
            try tamperedData.write(
                to: historicalDirectory.appendingPathComponent("\(version.rawValue).mom"),
                options: .atomic
            )
        }
        let bundledModel = try XCTUnwrap(
            version.modelURL(in: modelBundle, modelDirectory: SubstrateStorageParams.modelDirectory)
                .flatMap(NSManagedObjectModel.init(contentsOf:))
        )
        XCTAssertNotNil(bundledModel.entitiesByName["CDContact"]?.attributesByName["legacyNote"])

        let storeURL = try caseStoreURL("unexpected-drop")
        try createStore(at: storeURL, model: bundledModel) { context in
            try self.insertObject(
                "CDContact",
                values: ["name": "Alice", "address": "5Alice", "legacyNote": "kept"],
                in: context,
                model: bundledModel
            )
        }
        let before = try durableStoreFamilySnapshot(at: storeURL)
        let migrator = makeMigrator(storeURL: storeURL, modelBundle: modelBundle)

        XCTAssertThrowsError(try migrator.performMigration()) { error in
            guard
                let migrationError = error as? SubstrateStorageMigrationError,
                case let .mappingUnavailable(source, destination, mappingError) = migrationError
            else {
                return XCTFail("Expected mappingUnavailable, got \(error)")
            }
            XCTAssertEqual(source, version)
            XCTAssertEqual(destination, .version5)
            XCTAssertTrue(mappingError.localizedDescription.contains("CDContact.legacyNote"), "\(mappingError)")
        }
        XCTAssertEqual(try durableStoreFamilySnapshot(at: storeURL), before)

        // A store with contacts never enters the prunable cache quarantine.
        XCTAssertThrowsError(try migrator.performMigrationWithRecovery()) { error in
            guard
                let migrationError = error as? SubstrateStorageMigrationError,
                case .cacheRecoveryBlockedByProtectedData = migrationError
            else {
                return XCTFail("Expected cacheRecoveryBlockedByProtectedData, got \(error)")
            }
        }
        XCTAssertEqual(try durableStoreFamilySnapshot(at: storeURL), before)
        XCTAssertTrue(try recoveryDirectories(besides: storeURL).isEmpty)

        try assertStartupSetsWholeStoreAside(migrator, at: storeURL, family: before, label: "unexpected drop")
    }

    func testUpgrade_historical_whenStagedStoreMutated_rejectsAndPreservesSource() throws {
        let entry = try substrateEntry(digest: "d484c09eddea88ca")
        let fixtureModel = try UpgradeFixtureLoader.fixtureModel(for: entry)
        let storeURL = try caseStoreURL(entry.resource)
        try createStore(at: storeURL, model: fixtureModel) { context in
            try self.populate(context, model: fixtureModel)
        }
        let before = try durableStoreFamilySnapshot(at: storeURL)
        let migrator = makeMigrator(
            storeURL: storeURL,
            stagedStoreMutationHook: { stagedURL, _ in
                try self.executeSQLite("UPDATE ZCDCONTACT SET ZNAME = 'Mallory'", at: stagedURL)
            }
        )

        for _ in 0 ..< 2 {
            XCTAssertThrowsError(try migrator.performMigrationWithRecovery()) { error in
                guard
                    let migrationError = error as? SubstrateStorageMigrationError,
                    case .stagedStoreProtectedDataMismatch = migrationError
                else {
                    return XCTFail("Expected stagedStoreProtectedDataMismatch, got \(error)")
                }
            }
            XCTAssertEqual(try durableStoreFamilySnapshot(at: storeURL), before)
            XCTAssertTrue(try recoveryDirectories(besides: storeURL).isEmpty)
        }

        // The changed copy is discarded; the store the release wrote is kept.
        try assertStartupSetsWholeStoreAside(migrator, at: storeURL, family: before, label: entry.resource)
    }

    func testUpgrade_historical_processDeathAtEveryReplacementBoundary_converges() throws {
        for digest in ["d484c09eddea88ca", "6ca82510c9ee52ee"] {
            let entry = try substrateEntry(digest: digest)
            let fixtureModel = try UpgradeFixtureLoader.fixtureModel(for: entry)

            var boundaries: [CrashConsistentStoreReplacementBoundary] = []
            let recordingURL = try caseStoreURL("\(digest)-recording")
            try createStore(at: recordingURL, model: fixtureModel) { context in
                try self.populate(context, model: fixtureModel)
            }
            try makeMigrator(
                storeURL: recordingURL,
                storeReplacementBoundaryHook: { boundaries.append($0) }
            ).migrate()
            XCTAssertTrue(boundaries.contains(.committedMarkerPersisted), digest)

            for (boundaryIndex, boundary) in boundaries.enumerated() {
                try XCTContext.runActivity(named: "\(digest) dies at \(boundary)") { _ in
                    let storeURL = try caseStoreURL("\(digest)-boundary-\(boundaryIndex)")
                    try createStore(at: storeURL, model: fixtureModel) { context in
                        try self.populate(context, model: fixtureModel)
                    }
                    let expected = try expectations(for: entry, at: storeURL, model: fixtureModel)
                    var crossedBoundaryCount = 0
                    let interruptedMigrator = makeMigrator(
                        storeURL: storeURL,
                        storeReplacementBoundaryHook: { _ in
                            defer { crossedBoundaryCount += 1 }
                            guard crossedBoundaryCount == boundaryIndex else { return }
                            throw CrashConsistentStoreReplacementInterruption.simulatedProcessDeath
                        }
                    )

                    XCTAssertThrowsError(try interruptedMigrator.migrate())

                    let relaunchedMigrator = makeMigrator(storeURL: storeURL)
                    try relaunchedMigrator.migrate()

                    try assertMigrated(expected, at: storeURL, entry: entry)
                    try assertIsCurrentStore(at: storeURL, migrator: relaunchedMigrator, entry: entry)
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

    func testUpgrade_3_5_3_largeStore_completesWithinMigrationDeadline() throws {
        let entry = try substrateEntry(digest: "d484c09eddea88ca")
        let fixtureModel = try UpgradeFixtureLoader.fixtureModel(for: entry)
        let storeURL = try caseStoreURL(entry.resource)
        let storageItemCount = 50000
        let historyItemCount = 1000
        try createStore(at: storeURL, model: fixtureModel) { context in
            for index in 0 ..< storageItemCount {
                try self.insertObject(
                    "CDChainStorageItem",
                    values: ["identifier": "storage-\(index)", "data": Data([0x00, 0x80, 0xFF])],
                    in: context,
                    model: fixtureModel
                )
                if (index + 1).isMultiple(of: 2048) {
                    try context.save()
                    context.reset()
                }
            }
            for index in 0 ..< historyItemCount {
                try self.insertObject(
                    "CDTransactionHistoryItem",
                    values: [
                        "identifier": "history-\(index)",
                        "callName": "transfer",
                        "moduleName": "Balances",
                        "sender": "5Sender",
                        "receiver": "5Receiver",
                        "timestamp": NSNumber(value: Int64(1_700_000_000 + index))
                    ],
                    in: context,
                    model: fixtureModel
                )
            }
        }
        let migrator = makeMigrator(storeURL: storeURL)

        let start = Date()
        try migrator.migrate()
        let elapsed = Date().timeIntervalSince(start)

        // RootInteractor's default migration deadline.
        XCTAssertLessThan(elapsed, 60, "Migrating the 3.5.3 store took \(elapsed) s")
        let currentModel = try appModel(for: .version10)
        XCTAssertEqual(try count("CDChainStorageItem", at: storeURL, model: currentModel), storageItemCount)
        XCTAssertEqual(try count("CDTransactionHistoryItem", at: storeURL, model: currentModel), historyItemCount)
        XCTAssertFalse(migrator.requiresMigration())
    }

    /// A store family a shipped build wrote on a device or simulator, too
    /// large to keep in the repository. Point
    /// `FEARLESS_SHIPPED_SUBSTRATE_STORE` at its `SubstrateDataModel.sqlite`
    /// (pass `TEST_RUNNER_FEARLESS_SHIPPED_SUBSTRATE_STORE` to xcodebuild).
    /// The family is copied first; the original is only read.
    func testUpgrade_storeWrittenByAShippedBuild_keepsEveryRowAndCompletesWithinMigrationDeadline() throws {
        guard
            let shippedPath = ProcessInfo.processInfo.environment["FEARLESS_SHIPPED_SUBSTRATE_STORE"],
            !shippedPath.isEmpty
        else {
            throw XCTSkip("FEARLESS_SHIPPED_SUBSTRATE_STORE is not set")
        }

        let shippedStoreURL = URL(fileURLWithPath: shippedPath)
        let shippedFamily = try durableStoreFamilySnapshot(at: shippedStoreURL)
        XCTAssertNotNil(shippedFamily[shippedStoreURL.lastPathComponent])

        let storeURL = try caseStoreURL("shipped")
        for (fileName, data) in shippedFamily {
            let name = SubstrateStorageParams.databaseName +
                fileName.dropFirst(shippedStoreURL.lastPathComponent.count)
            try data.write(to: storeURL.deletingLastPathComponent().appendingPathComponent(name))
        }

        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType,
            at: storeURL,
            options: nil
        )
        let sourceVersions = try SubstrateStorageVersion.allCases.filter {
            try appModel(for: $0).isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
        }
        XCTAssertEqual(sourceVersions.count, 1, "\(sourceVersions.map(\.rawValue))")
        let sourceVersion = try XCTUnwrap(sourceVersions.first)
        let sourceModel = try appModel(for: sourceVersion)
        let currentModel = try appModel(for: .version10)

        var expectedCounts: [String: Int] = [:]
        try inspectStore(at: storeURL, model: sourceModel) { context in
            for entityName in sourceModel.entitiesByName.keys
                where currentModel.entitiesByName[entityName] != nil && entityName != "CDChainAsset" {
                expectedCounts[entityName] = try context.count(
                    for: NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                )
            }
        }
        XCTContext.runActivity(named: "\(sourceVersion.rawValue) \(expectedCounts.sorted { $0.key < $1.key })") { _ in }

        let migrator = makeMigrator(storeURL: storeURL)
        let start = Date()
        try migrator.migrate()
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertLessThan(elapsed, 60, "Migrating the shipped store took \(elapsed) s")
        XCTAssertTrue(try retainedDirectories(besides: storeURL).isEmpty, "the shipped store was set aside")
        for (entityName, expectedCount) in expectedCounts {
            XCTAssertEqual(try count(entityName, at: storeURL, model: currentModel), expectedCount, entityName)
        }
        XCTAssertTrue(
            currentModel.isConfiguration(
                withName: nil,
                compatibleWithStoreMetadata: try NSPersistentStoreCoordinator.metadataForPersistentStore(
                    ofType: NSSQLiteStoreType,
                    at: storeURL,
                    options: nil
                )
            )
        )
        XCTAssertFalse(migrator.requiresMigration())
        XCTAssertEqual(try durableStoreFamilySnapshot(at: shippedStoreURL), shippedFamily, "the original was changed")
    }

    // MARK: - Starting up with a store that cannot be used

    func testStartup_whenAShippedStoreCannotBeMigrated_thenKeepsItWholeAndTheArchiveStillMigratesLosslessly() throws {
        // App Store 0.4.0–1.2.2, 3.2.2–3.5.3, and public 4.0.2 / private 4.0.4.
        for digest in ["27378408dc2e9402", "d484c09eddea88ca", "186efaedb554f36c"] {
            try XCTContext.runActivity(named: digest) { _ in
                let entry = try substrateEntry(digest: digest)
                let fixtureModel = try UpgradeFixtureLoader.fixtureModel(for: entry)
                let storeURL = try caseStoreURL(entry.resource)
                try createStore(at: storeURL, model: fixtureModel) { context in
                    try self.populate(context, model: fixtureModel)
                }
                let expected = try expectations(for: entry, at: storeURL, model: fixtureModel)
                let before = try durableStoreFamilySnapshot(at: storeURL)

                // Stands in for any defect that makes this build fail on the store.
                let failingMigrator = makeMigrator(
                    storeURL: storeURL,
                    stagedStoreMutationHook: { _, _ in throw InjectedMigrationDefect.failure }
                )
                let archiveURL = try assertStartupSetsWholeStoreAside(
                    failingMigrator,
                    at: storeURL,
                    family: before,
                    label: digest
                )

                // The next launch finds the fresh store the Core Data stack created.
                try createStore(at: storeURL, model: appModel(for: .version10)) { _ in }
                let relaunchedMigrator = makeMigrator(storeURL: storeURL)
                try relaunchedMigrator.migrate()
                XCTAssertFalse(relaunchedMigrator.requiresMigration(), digest)
                XCTAssertEqual(try retainedDirectories(besides: storeURL), [archiveURL], digest)

                // The archive is still exactly what the release wrote: a build
                // without the defect migrates it with every protected value.
                let restoredStoreURL = try caseStoreURL("\(entry.resource)-restored")
                for fileName in try FileManager.default.contentsOfDirectory(atPath: archiveURL.path) {
                    try FileManager.default.copyItem(
                        at: archiveURL.appendingPathComponent(fileName),
                        to: restoredStoreURL.deletingLastPathComponent().appendingPathComponent(fileName)
                    )
                }
                let restoringMigrator = makeMigrator(storeURL: restoredStoreURL)
                try restoringMigrator.performMigration()

                try assertMigrated(expected, at: restoredStoreURL, entry: entry)
                try assertIsCurrentStore(at: restoredStoreURL, migrator: restoringMigrator, entry: entry)
                XCTAssertEqual(
                    try durableStoreFamilySnapshot(at: archiveURL.appendingPathComponent(storeURL.lastPathComponent)),
                    before,
                    digest
                )
            }
        }
    }

    func testStartup_whenProcessDiesWhileSettingAStoreAside_thenRelaunchKeepsEveryByte() throws {
        let entry = try XCTUnwrap(try substrateEntries().first { $0.excluded != nil })
        let fixtureModel = try UpgradeFixtureLoader.fixtureModel(for: entry)

        // Every run installs the same family, with a rollback journal beside
        // the WAL sidecars, so the recorded boundaries are the ones each run
        // crosses.
        func installFamily(at storeURL: URL) throws {
            try createStore(at: storeURL, model: fixtureModel) { _ in }
            try Data("uncheckpointed".utf8).write(to: URL(fileURLWithPath: storeURL.path + "-journal"))
        }

        var boundaries: [RetainedStoreSetAsideBoundary] = []
        let recordingURL = try caseStoreURL("set-aside-recording")
        try installFamily(at: recordingURL)
        try makeMigrator(storeURL: recordingURL, storeSetAsideBoundaryHook: { boundaries.append($0) }).migrate()
        XCTAssertEqual(boundaries.first, .markerPersisted)
        XCTAssertTrue(boundaries.contains(.familyMemberMoved("-journal")))
        XCTAssertEqual(boundaries.last, .markerRemoved)

        for (boundaryIndex, boundary) in boundaries.enumerated() {
            try XCTContext.runActivity(named: "dies at \(boundary)") { _ in
                let storeURL = try caseStoreURL("set-aside-boundary-\(boundaryIndex)")
                try installFamily(at: storeURL)
                let before = try durableStoreFamilySnapshot(at: storeURL)
                var crossedBoundaryCount = 0
                let interruptedMigrator = makeMigrator(
                    storeURL: storeURL,
                    storeSetAsideBoundaryHook: { _ in
                        defer { crossedBoundaryCount += 1 }
                        guard crossedBoundaryCount == boundaryIndex else { return }
                        throw RetainedStoreSetAsideInterruption.simulatedProcessDeath
                    }
                )

                XCTAssertThrowsError(try interruptedMigrator.migrate()) { error in
                    XCTAssertTrue(error is RetainedStoreSetAsideInterruption, "\(error)")
                }

                let relaunchedMigrator = makeMigrator(storeURL: storeURL)
                XCTAssertEqual(relaunchedMigrator.requiresMigration(), boundary != .markerRemoved)
                try relaunchedMigrator.migrate()

                XCTAssertTrue(try durableStoreFamilySnapshot(at: storeURL).isEmpty)
                let archiveURL = try XCTUnwrap(try retainedDirectories(besides: storeURL).first)
                XCTAssertEqual(try retainedDirectories(besides: storeURL).count, 1)
                XCTAssertEqual(
                    try durableStoreFamilySnapshot(at: archiveURL.appendingPathComponent(storeURL.lastPathComponent)),
                    before
                )
                XCTAssertEqual(
                    Set(try FileManager.default.contentsOfDirectory(atPath: archiveURL.path)),
                    Set(before.keys)
                )
                XCTAssertFalse(relaunchedMigrator.requiresMigration())
            }
        }
    }

    // MARK: - Expectations

    private struct Expectations {
        /// Canonical records per compared entity, built from the fixture store.
        var records: [String: [String]] = [:]
        /// Source row count for every entity v10 still has.
        var rowCounts: [String: Int] = [:]
        var assetIdentifiers: Set<String> = []
        var assetPurchaseProviders: [String]?
        var defaultNodes: Set<String> = []
        var customNodes: Set<String> = []
        var selectedNode: String?
    }

    private func expectations(
        for entry: HistoricalModel,
        at storeURL: URL,
        model: NSManagedObjectModel
    ) throws -> Expectations {
        let currentModel = try appModel(for: .version10)
        var expected = Expectations()

        try inspectStore(at: storeURL, model: model) { context in
            for entityName in Self.comparedEntityNames {
                guard
                    let currentEntity = currentModel.entitiesByName[entityName],
                    let sourceEntity = model.entitiesByName[entityName]
                else {
                    continue
                }

                let attributeNames = comparedAttributeNames(
                    for: entityName,
                    source: sourceEntity,
                    current: currentEntity
                )
                expected.records[entityName] = try context
                    .fetch(NSFetchRequest<NSManagedObject>(entityName: entityName))
                    .map { object in
                        attributeNames.map { name -> String in
                            guard sourceEntity.attributesByName[name] != nil else {
                                let constant = entry.requiredConstants["\(entityName).\(name)"]
                                return "\(name)=\(describe(constant))"
                            }
                            return "\(name)=\(describe(object.value(forKey: name)))"
                        }.joined(separator: "|")
                    }
                    .sorted()
            }

            for entityName in model.entitiesByName.keys where currentModel.entitiesByName[entityName] != nil {
                expected.rowCounts[entityName] = try context.count(
                    for: NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                )
            }

            if model.entitiesByName["CDAsset"] != nil {
                let assets = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "CDAsset"))
                expected.assetIdentifiers = Set(assets.compactMap { $0.value(forKey: "id") as? String })
                let wrapperHasProviders =
                    model.entitiesByName["CDChainAsset"]?.attributesByName["purchaseProviders"] != nil
                let assetHasProviders =
                    model.entitiesByName["CDAsset"]?.attributesByName["purchaseProviders"] != nil
                expected.assetPurchaseProviders =
                    wrapperHasProviders || assetHasProviders ? Self.purchaseProviders : nil
            }

            if model.entitiesByName["CDChain"] != nil,
               let chain = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "CDChain")).first {
                let relationships = chain.entity.relationshipsByName
                expected.defaultNodes = Set(nodeObjects(in: chain, key: "nodes").map(nodeDescription))
                if relationships["customNodes"] != nil {
                    expected.customNodes = Set(nodeObjects(in: chain, key: "customNodes").map(nodeDescription))
                }
                if relationships["selectedNode"] != nil,
                   let selectedNode = chain.value(forKey: "selectedNode") as? NSManagedObject {
                    expected.selectedNode = nodeDescription(selectedNode)
                } else {
                    // Only a chain that reaches v1 can lack a selected node;
                    // ChainSubstrateV2MigrationPolicy then picks the lowest URL.
                    expected.selectedNode = nodeObjects(in: chain, key: "nodes")
                        .map { ($0.value(forKey: "url") as? URL)?.absoluteString ?? "" }
                        .min()
                        .flatMap { url in
                            nodeObjects(in: chain, key: "nodes").first {
                                ($0.value(forKey: "url") as? URL)?.absoluteString == url
                            }
                        }
                        .map(nodeDescription)
                }
            }
        }

        return expected
    }

    private func assertMigrated(
        _ expected: Expectations,
        at storeURL: URL,
        entry: HistoricalModel
    ) throws {
        let currentModel = try appModel(for: .version10)
        let label = "\(entry.digest) \(releaseSummary(entry))"
        let sourceModel = try UpgradeFixtureLoader.fixtureModel(for: entry)

        try inspectStore(at: storeURL, model: currentModel) { context in
            for (entityName, expectedRecords) in expected.records {
                let currentEntity = try XCTUnwrap(currentModel.entitiesByName[entityName])
                let sourceEntity = try XCTUnwrap(sourceModel.entitiesByName[entityName])
                let attributeNames = comparedAttributeNames(
                    for: entityName,
                    source: sourceEntity,
                    current: currentEntity
                )
                let records = try context
                    .fetch(NSFetchRequest<NSManagedObject>(entityName: entityName))
                    .map { object in
                        attributeNames.map { "\($0)=\(describe(object.value(forKey: $0)))" }
                            .joined(separator: "|")
                    }
                    .sorted()

                XCTAssertEqual(records, expectedRecords, "\(label): \(entityName) values changed")
            }

            for (entityName, expectedCount) in expected.rowCounts {
                XCTAssertEqual(
                    try context.count(for: NSFetchRequest<NSFetchRequestResult>(entityName: entityName)),
                    expectedCount,
                    "\(label): \(entityName) row count changed"
                )
            }

            let assets = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "CDAsset"))
            XCTAssertEqual(
                Set(assets.compactMap { $0.value(forKey: "id") as? String }),
                expected.assetIdentifiers,
                label
            )
            for asset in assets {
                XCTAssertEqual(
                    try SafeTransformableValueReader.read(from: asset, key: "purchaseProviders", as: [String].self),
                    expected.assetPurchaseProviders,
                    label
                )
            }

            let chains = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "CDChain"))
            if let chain = chains.first {
                XCTAssertEqual(Set(nodeObjects(in: chain, key: "nodes").map(nodeDescription)), expected.defaultNodes, label)
                XCTAssertEqual(
                    Set(nodeObjects(in: chain, key: "customNodes").map(nodeDescription)),
                    expected.customNodes,
                    label
                )
                XCTAssertEqual(
                    (chain.value(forKey: "selectedNode") as? NSManagedObject).map(nodeDescription),
                    expected.selectedNode,
                    label
                )
            } else {
                XCTAssertTrue(expected.defaultNodes.isEmpty, label)
            }
        }
    }

    private func assertIsCurrentStore(
        at storeURL: URL,
        migrator: SubstrateStorageMigrator,
        entry: HistoricalModel
    ) throws {
        // migrate() never fails on a store it cannot use, so a store that was
        // set aside instead of migrated must not pass for an upgrade.
        XCTAssertTrue(try retainedDirectories(besides: storeURL).isEmpty, "\(entry.resource) was set aside")
        XCTAssertTrue(try recoveryDirectories(besides: storeURL).isEmpty, "\(entry.resource) was quarantined")

        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType,
            at: storeURL,
            options: nil
        )
        XCTAssertTrue(
            try appModel(for: .version10).isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata),
            entry.resource
        )
        XCTAssertFalse(migrator.requiresMigration(), entry.resource)

        let migrated = try durableStoreFamilySnapshot(at: storeURL)
        try migrator.performMigration()
        XCTAssertEqual(try durableStoreFamilySnapshot(at: storeURL), migrated, "\(entry.resource) was not idempotent")
    }

    /// Every attribute a fully populated entity shares with v10, plus the
    /// protected ones; a protected attribute the source lacks must be nil
    /// (or the reviewed constant) after the migration.
    private func comparedAttributeNames(
        for entityName: String,
        source: NSEntityDescription,
        current: NSEntityDescription
    ) -> [String] {
        var names = Set(Self.protectedAttributeNames[entityName] ?? [])
        if Self.fullyPopulatedEntityNames.contains(entityName) {
            names.formUnion(source.attributesByName.keys)
        }

        return names.filter { current.attributesByName[$0] != nil }.sorted()
    }

    // MARK: - Population

    /// Writes the protected graph a user could have, adapted to the entities
    /// and relationships the model has.
    private func populate(_ context: NSManagedObjectContext, model: NSManagedObjectModel) throws {
        for entityName in ["CDContact", "CDContactItem", "CDRuntimeMetadataItem", "CDChainStorageItem", "CDTonDapp"]
            where model.entitiesByName[entityName] != nil {
            try insertObject(entityName, in: context, model: model, fillingEveryAttribute: true)
        }

        if model.entitiesByName["CDTransactionHistoryItem"] != nil {
            try insertObject("CDTransactionHistoryItem", in: context, model: model, fillingEveryAttribute: true)
            // A second row with only the mandatory values.
            try insertObject(
                "CDTransactionHistoryItem",
                values: ["identifier": "history-minimal"],
                in: context,
                model: model
            )
        }

        if model.entitiesByName["CDTonConnectedApp"] != nil {
            try insertObject(
                "CDTonConnectedApp",
                values: ["privateKey": Self.tonPrivateKey],
                in: context,
                model: model,
                fillingEveryAttribute: true
            )
        }

        if model.entitiesByName["CDPolkaswapRemoteSettings"] != nil {
            let dex = try insertObject("CDPolkaswapDex", in: context, model: model, fillingEveryAttribute: true)
            let settings = try insertObject(
                "CDPolkaswapRemoteSettings",
                in: context,
                model: model,
                fillingEveryAttribute: true
            )
            settings.mutableSetValue(forKey: "availableDexIds").add(dex)
        }

        let chain = try populateChain(in: context, model: model)
        try populateAsset(chain: chain, in: context, model: model)
    }

    @discardableResult
    private func populateChain(
        in context: NSManagedObjectContext,
        model: NSManagedObjectModel
    ) throws -> NSManagedObject? {
        guard
            let chainEntity = model.entitiesByName["CDChain"],
            model.entitiesByName["CDChainNode"] != nil
        else {
            return nil
        }

        var chainValues: [String: Any] = ["chainId": "historical-chain", "name": "Historical Chain"]
        if chainEntity.attributesByName["tonBridgeUrl"] != nil {
            chainValues["tonBridgeUrl"] = try XCTUnwrap(Self.tonBridgeURL)
        }
        let chain = try insertObject("CDChain", values: chainValues, in: context, model: model)

        // URL order and name order disagree, so a selection that does not
        // follow ChainSubstrateV2MigrationPolicy is caught.
        try insertObject(
            "CDChainNode",
            values: ["name": "Zulu node", "url": try XCTUnwrap(URL(string: "wss://alpha.example.invalid")), "chain": chain],
            in: context,
            model: model
        )
        let otherNode = try insertObject(
            "CDChainNode",
            values: ["name": "Alpha node", "url": try XCTUnwrap(URL(string: "wss://zulu.example.invalid")), "chain": chain],
            in: context,
            model: model
        )

        if chainEntity.relationshipsByName["customNodes"] != nil {
            let customNode = try insertObject(
                "CDChainNode",
                values: [
                    "name": "My node",
                    "url": try XCTUnwrap(URL(string: "wss://custom.example.invalid")),
                    "apiKeyName": "custom-key"
                ],
                in: context,
                model: model
            )
            chain.mutableSetValue(forKey: "customNodes").add(customNode)
        }

        if chainEntity.relationshipsByName["selectedNode"] != nil {
            chain.setValue(otherNode, forKey: "selectedNode")
        }

        return chain
    }

    private func populateAsset(
        chain: NSManagedObject?,
        in context: NSManagedObjectContext,
        model: NSManagedObjectModel
    ) throws {
        guard let assetEntity = model.entitiesByName["CDAsset"] else {
            return
        }

        var assetValues: [String: Any] = [
            "id": "historical-asset",
            "chainId": "historical-chain",
            "symbol": "HST",
            "precision": NSNumber(value: Int16(10))
        ]
        if assetEntity.attributesByName["purchaseProviders"] != nil {
            assetValues["purchaseProviders"] = NSArray(array: Self.purchaseProviders)
        }
        let asset = try insertObject("CDAsset", values: assetValues, in: context, model: model)

        if let chain, chain.entity.relationshipsByName["assets"]?.destinationEntity?.name == "CDChainAsset" {
            var wrapperValues: [String: Any] = [
                "assetId": "historical-asset",
                "isNative": true,
                "isUtility": true,
                "type": "normal",
                "asset": asset,
                "chain": chain
            ]
            if model.entitiesByName["CDChainAsset"]?.attributesByName["purchaseProviders"] != nil {
                wrapperValues["purchaseProviders"] = NSArray(array: Self.purchaseProviders)
            }
            try insertObject("CDChainAsset", values: wrapperValues, in: context, model: model)
        } else if let chain, assetEntity.relationshipsByName["chain"] != nil {
            asset.setValue(chain, forKey: "chain")
        }

        if model.entitiesByName["CDPriceProvider"] != nil, assetEntity.relationshipsByName["priceProvider"] != nil {
            let provider = try insertObject("CDPriceProvider", in: context, model: model, fillingEveryAttribute: true)
            asset.setValue(provider, forKey: "priceProvider")
        }

        if model.entitiesByName["CDPriceData"] != nil, assetEntity.relationshipsByName["priceData"] != nil {
            let priceData = try insertObject("CDPriceData", in: context, model: model, fillingEveryAttribute: true)
            asset.mutableSetValue(forKey: "priceData").add(priceData)
        }
    }

    /// Inserts an object with the given values (keys the entity lacks are
    /// ignored) and a deterministic sample for every mandatory attribute
    /// without a default, or for every attribute when asked.
    @discardableResult
    private func insertObject(
        _ entityName: String,
        values: [String: Any] = [:],
        in context: NSManagedObjectContext,
        model: NSManagedObjectModel,
        fillingEveryAttribute: Bool = false
    ) throws -> NSManagedObject {
        let entity = try XCTUnwrap(model.entitiesByName[entityName], entityName)
        let object = NSManagedObject(entity: entity, insertInto: context)

        for (name, attribute) in entity.attributesByName.sorted(by: { $0.key < $1.key }) {
            if let value = values[name] {
                object.setValue(value, forKey: name)
            } else if fillingEveryAttribute || (!attribute.isOptional && attribute.defaultValue == nil) {
                object.setValue(sampleValue(for: attribute, entityName: entityName), forKey: name)
            }
        }

        for (name, value) in values where entity.relationshipsByName[name] != nil {
            object.setValue(value, forKey: name)
        }

        return object
    }

    private func sampleValue(for attribute: NSAttributeDescription, entityName: String) -> Any? {
        let seed = "\(entityName).\(attribute.name)"

        switch attribute.attributeType {
        case .stringAttributeType:
            return seed
        case .integer16AttributeType:
            return NSNumber(value: Int16(7))
        case .integer32AttributeType:
            return NSNumber(value: Int32(70000))
        case .integer64AttributeType:
            return NSNumber(value: Int64(7_000_000_000))
        case .decimalAttributeType:
            return NSDecimalNumber(string: "12.5")
        case .doubleAttributeType:
            return NSNumber(value: Double(1.25))
        case .floatAttributeType:
            return NSNumber(value: Float(1.25))
        case .booleanAttributeType:
            return NSNumber(value: true)
        case .dateAttributeType:
            return Date(timeIntervalSinceReferenceDate: 720_000_000)
        case .binaryDataAttributeType:
            return Data(seed.utf8)
        case .UUIDAttributeType:
            return UUID(uuidString: "6F1D9D0E-8F1B-4E9E-9C55-3A0F3C2B1A00")
        case .URIAttributeType:
            return URL(string: "https://example.invalid/\(entityName)/\(attribute.name)")
        case .transformableAttributeType:
            // Every transformable a migratable historical model has is a
            // string array (SubstrateStorageMigrator's allowlist).
            return NSArray(array: [seed])
        default:
            return nil
        }
    }

    private func describe(_ value: Any?) -> String {
        switch value {
        case nil:
            return "nil"
        case let string as String:
            return "string:\(string)"
        case let url as URL:
            return "url:\(url.absoluteString)"
        case let data as Data:
            return "data:\(data.base64EncodedString())"
        case let date as Date:
            return "date:\(date.timeIntervalSinceReferenceDate)"
        case let decimal as NSDecimalNumber:
            return "decimal:\(decimal.stringValue)"
        case let number as NSNumber:
            return "number:\(number.stringValue)"
        case let array as NSArray:
            return "array:\(array.compactMap { $0 as? String }.joined(separator: ","))"
        case let uuid as UUID:
            return "uuid:\(uuid.uuidString)"
        default:
            return "unsupported:\(type(of: value as Any))"
        }
    }

    private func nodeObjects(in chain: NSManagedObject, key: String) -> [NSManagedObject] {
        guard chain.entity.relationshipsByName[key] != nil else {
            return []
        }

        return (chain.value(forKey: key) as? Set<NSManagedObject>).map(Array.init) ?? []
    }

    private func nodeDescription(_ node: NSManagedObject) -> String {
        [
            describe(node.value(forKey: "name")),
            describe(node.value(forKey: "url")),
            describe(node.entity.attributesByName["apiKeyName"] != nil ? node.value(forKey: "apiKeyName") : nil)
        ].joined(separator: "|")
    }

    // MARK: - Fixtures and stores

    private func substrateEntries() throws -> [HistoricalModel] {
        try UpgradeFixtureLoader.historicalStoreModels().filter { $0.store == .substrate }
    }

    private func migratableEntries() throws -> [HistoricalModel] {
        let entries = try substrateEntries().filter { $0.excluded == nil }
        XCTAssertGreaterThanOrEqual(entries.count, 50)
        return entries
    }

    private func substrateEntry(digest: String) throws -> HistoricalModel {
        try XCTUnwrap(substrateEntries().first { $0.digest == digest }, digest)
    }

    private func releaseSummary(_ entry: HistoricalModel) -> String {
        let releases = entry.releases + entry.interimTags + entry.heads.map(\.title) +
            entry.developmentCommits.map(\.title)
        guard let first = releases.first else {
            return entry.resource
        }

        return releases.count > 1 ? "\(first) … \(releases[releases.count - 1])" : first
    }

    private func appModel(for version: SubstrateStorageVersion) throws -> NSManagedObjectModel {
        let modelURL = version.modelURL(in: appBundle, modelDirectory: SubstrateStorageParams.modelDirectory)

        return try XCTUnwrap(
            modelURL.flatMap(NSManagedObjectModel.init(contentsOf:)),
            "Unable to load \(version.rawValue) from the app bundle"
        )
    }

    private func caseStoreURL(_ name: String) throws -> URL {
        let directory = testDirectory.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        return directory.appendingPathComponent(SubstrateStorageParams.databaseName)
    }

    private func makeMigrator(
        storeURL: URL,
        modelBundle: Bundle? = nil,
        stagedStoreMutationHook: @escaping (URL, NSManagedObjectModel) throws -> Void = { _, _ in },
        storeReplacementBoundaryHook: @escaping (CrashConsistentStoreReplacementBoundary) throws -> Void = { _ in },
        storeSetAsideBoundaryHook: @escaping (RetainedStoreSetAsideBoundary) throws -> Void = { _ in }
    ) -> SubstrateStorageMigrator {
        SubstrateStorageMigrator(
            targetVersion: SubstrateStorageParams.modelVersion,
            storeURL: storeURL,
            modelDirectory: SubstrateStorageParams.modelDirectory,
            fileManager: .default,
            modelBundle: modelBundle ?? appBundle,
            stagedStoreMutationHook: stagedStoreMutationHook,
            storeReplacementBoundaryHook: storeReplacementBoundaryHook,
            storeSetAsideBoundaryHook: storeSetAsideBoundaryHook
        )
    }

    /// The production entry point never fails for a store it cannot use. The
    /// family is kept, byte for byte, in the retained archive (never in the
    /// prunable cache quarantine) and nothing stays installed, so the Core
    /// Data stack starts a fresh store.
    @discardableResult
    private func assertStartupSetsWholeStoreAside(
        _ migrator: SubstrateStorageMigrator,
        at storeURL: URL,
        family: [String: Data],
        label: String
    ) throws -> URL {
        XCTAssertFalse(family.isEmpty, label)

        do {
            try migrator.migrate()
        } catch let error as SubstrateStorageMigrationError where error.isRetriedBeforeStoreSetAside {
            // Startup reports a failure that can pass once, with Retry, and keeps the store
            // installed; the retry sets it aside when it fails again.
            XCTAssertEqual(try durableStoreFamilySnapshot(at: storeURL), family, label)
            XCTAssertTrue(try retainedDirectories(besides: storeURL).isEmpty, label)
            try migrator.migrate()
        }

        XCTAssertTrue(try durableStoreFamilySnapshot(at: storeURL).isEmpty, label)
        let archiveURLs = try retainedDirectories(besides: storeURL)
        XCTAssertEqual(archiveURLs.count, 1, label)
        let archiveURL = try XCTUnwrap(archiveURLs.first, label)
        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: archiveURL.appendingPathComponent(storeURL.lastPathComponent)),
            family,
            label
        )
        XCTAssertEqual(
            Set(try FileManager.default.contentsOfDirectory(atPath: archiveURL.path)),
            Set(family.keys),
            label
        )
        XCTAssertTrue(try recoveryDirectories(besides: storeURL).isEmpty, label)
        XCTAssertFalse(migrator.requiresMigration(), label)

        // A relaunch before the fresh store exists changes nothing.
        try migrator.migrate()
        XCTAssertEqual(try retainedDirectories(besides: storeURL), archiveURLs, label)
        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: archiveURL.appendingPathComponent(storeURL.lastPathComponent)),
            family,
            label
        )

        return archiveURL
    }

    /// A copy of the app's Substrate models and mappings whose historical
    /// folder `customize` may change.
    private func makeModelBundle(customize: (URL) throws -> Void) throws -> Bundle {
        let bundleURL = testDirectory.appendingPathComponent(
            "SubstrateModels-\(UUID().uuidString).bundle",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)

        let infoPlist: [String: Any] = [
            "CFBundleIdentifier": "jp.co.soramitsu.fearlesswallet.tests.historical-models.\(UUID().uuidString)",
            "CFBundleName": "HistoricalSubstrateModels",
            "CFBundlePackageType": "BNDL",
            "CFBundleVersion": "1"
        ]
        try PropertyListSerialization.data(fromPropertyList: infoPlist, format: .xml, options: 0)
            .write(to: bundleURL.appendingPathComponent("Info.plist"))

        try FileManager.default.copyItem(
            at: try XCTUnwrap(appBundle.url(forResource: "SubstrateDataModel", withExtension: "momd")),
            to: bundleURL.appendingPathComponent(SubstrateStorageParams.modelDirectory, isDirectory: true)
        )
        for version in [SubstrateStorageVersion.legacyPublicVersion8, .legacyPublicVersion9] {
            let modelURL = try XCTUnwrap(
                version.modelURL(in: appBundle, modelDirectory: SubstrateStorageParams.modelDirectory)
            )
            try FileManager.default.copyItem(
                at: modelURL,
                to: bundleURL.appendingPathComponent(modelURL.lastPathComponent)
            )
        }
        for mappingName in ["SubstrateV2Mapping", "SubstrateV3toV4"] {
            let mappingURL = try XCTUnwrap(appBundle.url(forResource: mappingName, withExtension: "cdm"))
            try FileManager.default.copyItem(
                at: mappingURL,
                to: bundleURL.appendingPathComponent(mappingURL.lastPathComponent)
            )
        }

        let historicalDirectory = bundleURL.appendingPathComponent(
            SubstrateStorageVersion.historicalModelDirectory,
            isDirectory: true
        )
        try FileManager.default.copyItem(
            at: try XCTUnwrap(
                appBundle.url(forResource: SubstrateStorageVersion.historicalModelDirectory, withExtension: nil)
            ),
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
            .filter { $0.hasPrefix(url.lastPathComponent) }

        return try Dictionary(
            uniqueKeysWithValues: fileNames.map { fileName in
                (fileName, try Data(contentsOf: directory.appendingPathComponent(fileName)))
            }
        )
    }

    private func recoveryDirectories(besides storeURL: URL) throws -> [URL] {
        try directories(named: "SubstrateStoreRecovery", besides: storeURL)
    }

    private func retainedDirectories(besides storeURL: URL) throws -> [URL] {
        try directories(named: RetainedStoreSetAside.substrateRootName, besides: storeURL)
    }

    private func directories(named rootName: String, besides storeURL: URL) throws -> [URL] {
        let root = storeURL.deletingLastPathComponent().appendingPathComponent(rootName, isDirectory: true)
        guard FileManager.default.fileExists(atPath: root.path) else {
            return []
        }

        return try FileManager.default.contentsOfDirectory(atPath: root.path)
            .sorted()
            .map { root.appendingPathComponent($0, isDirectory: true) }
    }

    private func executeSQLite(_ sql: String, at url: URL) throws {
        var database: OpaquePointer?
        guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK, let database else {
            sqlite3_close(database)
            throw NSError(domain: "HistoricalSubstrateStoreUpgradeTests.SQLite", code: 1)
        }
        defer {
            sqlite3_close(database)
        }

        var errorMessage: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(database, sql, nil, nil, &errorMessage)
        defer {
            sqlite3_free(errorMessage)
        }
        guard result == SQLITE_OK else {
            throw NSError(
                domain: "HistoricalSubstrateStoreUpgradeTests.SQLite",
                code: Int(result),
                userInfo: [NSLocalizedDescriptionKey: errorMessage.map { String(cString: $0) } ?? "SQLite error"]
            )
        }
    }
}

private enum InjectedMigrationDefect: Error {
    case failure
}
