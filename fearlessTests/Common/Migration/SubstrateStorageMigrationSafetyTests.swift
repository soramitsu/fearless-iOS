import CoreData
import SQLite3
import XCTest
@testable import fearless

final class SubstrateStorageMigrationSafetyTests: XCTestCase {
    private var testDirectory: URL!

    private var storeURL: URL {
        testDirectory.appendingPathComponent("SubstrateDataModel.sqlite")
    }

    private var appBundle: Bundle {
        Bundle(for: SubstrateDataStorageFacade.self)
    }

    override func setUpWithError() throws {
        try super.setUpWithError()

        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SubstrateStorageMigrationSafetyTests")
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

    func testPerformMigration_whenStoreDoesNotExist_thenDoesNotCreateOrModifyAnything() throws {
        let migrator = makeMigrator()

        XCTAssertFalse(migrator.requiresMigration())
        try migrator.performMigration()

        XCTAssertFalse(FileManager.default.fileExists(atPath: storeURL.path))
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: testDirectory.path).isEmpty)
    }

    func testPerformMigration_whenStoreIsCurrent_thenRepeatedCallsAreByteForByteIdempotent() throws {
        let currentModel = try model(for: .version8)
        try createStore(at: storeURL, model: currentModel) { context in
            try self.insertRuntimeItem(identifier: "current-runtime", in: context, model: currentModel)
        }
        let before = try durableStoreFamilySnapshot(at: storeURL)
        let migrator = makeMigrator()

        XCTAssertFalse(migrator.requiresMigration())
        try migrator.performMigration()
        try migrator.performMigration()

        XCTAssertEqual(try durableStoreFamilySnapshot(at: storeURL), before)
        XCTAssertEqual(
            try count(entityName: "CDRuntimeMetadataItem", at: storeURL, model: currentModel),
            1
        )
    }

    func testPerformMigration_whenCurrentStoreHasOversizedRawArchive_thenRepairsPrivateCopyAtomicallyAndPreservesProtectedGraph() throws {
        try createCurrentTransformableAndProtectedGraph()
        try executeSQLite(
            """
            UPDATE ZCDASSET
            SET ZPURCHASEPROVIDERS = zeroblob(1025)
            """,
            at: storeURL
        )
        let damaged = try durableStoreFamilySnapshot(at: storeURL)
        let migrator = makeMigrator(
            protectedDataInspectionLimits:
            makeProtectedDataLimits(
                maximumTransformableArchiveByteCount: 1024
            )
        )

        XCTAssertTrue(migrator.requiresMigration())
        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: storeURL),
            damaged,
            "Detection must never mutate the installed current store"
        )

        try migrator.performMigration()

        XCTAssertFalse(migrator.requiresMigration())
        try assertCurrentTransformableAndProtectedGraph(
            expectedOptions: ["safe-option"],
            expectedPurchaseProviders: nil
        )
        let repaired = try durableStoreFamilySnapshot(at: storeURL)
        XCTAssertNotEqual(repaired, damaged)

        try migrator.performMigration()

        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: storeURL),
            repaired,
            "A repaired current store must become a byte-for-byte no-op"
        )
    }

    func testPerformMigration_whenCurrentStoreHasDecodedWrongTypeArchive_thenRepairsPrivateCopyAndPreservesOtherValues() throws {
        try createCurrentTransformableAndProtectedGraph()
        let wrongTypeArchive = try NSKeyedArchiver.archivedData(
            withRootObject: NSString(string: "not-an-array"),
            requiringSecureCoding: true
        )
        try executeSQLite(
            """
            UPDATE ZCDCHAIN
            SET ZOPTIONS = X'\(hex(wrongTypeArchive))'
            """,
            at: storeURL
        )
        let damaged = try durableStoreFamilySnapshot(at: storeURL)
        let migrator = makeMigrator()

        XCTAssertTrue(migrator.requiresMigration())
        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: storeURL),
            damaged
        )

        try migrator.performMigration()

        XCTAssertFalse(migrator.requiresMigration())
        try assertCurrentTransformableAndProtectedGraph(
            expectedOptions: [],
            expectedPurchaseProviders: ["safe-provider"]
        )
    }

    func testPerformMigration_whenCleanCurrentStartupGraphIsExactlyAtEveryRelationshipLimit_thenAuditsWithoutHookReplacementOrMutation() throws {
        try createCurrentStartupRelationshipGraph()
        let before = try durableStoreFamilySnapshot(at: storeURL)
        var stagedHookCalled = false
        var replacementCalled = false
        var countedRelationships =
            [(String, String, Bool, Int)]()
        var materializedRelationships = [(String, String)]()
        let migrator = makeMigrator(
            storeReplacer: { _, _ in
                replacementCalled = true
            },
            stagedStoreMutationHook: { _, _ in
                stagedHookCalled = true
            },
            protectedDataInspectionLimits:
            makeProtectedDataLimits(
                maximumRelationshipMembers: 1,
                maximumTotalRelationshipMembers: 8
            ),
            protectedRelationshipCountDidFetch: {
                countedRelationships.append(
                    (
                        $0.entity.name ?? "unknown",
                        $1,
                        $0.hasFault(forRelationshipNamed: $1),
                        $2
                    )
                )
            },
            protectedRelationshipWillMaterialize: {
                entityName,
                relationshipName,
                _ in
                materializedRelationships.append(
                    (entityName, relationshipName)
                )
            }
        )

        XCTAssertFalse(migrator.requiresMigration())
        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: storeURL),
            before
        )

        try migrator.performMigration()

        XCTAssertFalse(stagedHookCalled)
        XCTAssertFalse(replacementCalled)
        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: storeURL),
            before
        )
        let expectedRelationships: Set<String> = [
            "CDAsset.priceData",
            "CDChain.assets",
            "CDChain.customNodes",
            "CDChain.explorers",
            "CDChain.nodes",
            "CDChainXcmConfig.availableAssets",
            "CDChainXcmConfig.availableDestinations",
            "CDXcmAvailableDestination.assets"
        ]
        let auditedRelationships = Set(
            countedRelationships.map { "\($0.0).\($0.1)" }
        )
        XCTAssertTrue(
            expectedRelationships.isSubset(
                of: auditedRelationships
            )
        )
        XCTAssertTrue(
            countedRelationships.allSatisfy {
                $0.2 && $0.3 == 1
            },
            "Every SQL count must remain faulted at the exact boundary"
        )
        XCTAssertEqual(
            Set(
                materializedRelationships.map {
                    "\($0.0).\($0.1)"
                }
            ),
            ["CDChain.customNodes", "CDChain.nodes"],
            "Only protected node relationships may materialize after the complete SQL audit"
        )
    }

    func testPerformMigration_whenCleanCurrentStartupRootsAreExactlyAtRowLimits_thenAuditsWithoutHookReplacementOrMutation() throws {
        let currentModel = try model(for: .version8)
        try createStore(at: storeURL, model: currentModel) {
            context in
            try self.insertRuntimeItem(
                identifier: "bounded-runtime",
                in: context,
                model: currentModel
            )
            _ = try self.insertChainWithDefaultNode(
                in: context,
                model: currentModel
            )
        }
        let before = try durableStoreFamilySnapshot(at: storeURL)
        var stagedHookCalled = false
        var replacementCalled = false
        let migrator = makeMigrator(
            storeReplacer: { _, _ in
                replacementCalled = true
            },
            stagedStoreMutationHook: { _, _ in
                stagedHookCalled = true
            },
            protectedDataInspectionLimits:
            makeProtectedDataLimits(
                maximumRowsPerEntity: 1,
                maximumTotalRows: 2,
                maximumStartupRootRowsPerEntity: 1,
                maximumRelationshipMembers: 1,
                maximumTotalRelationshipMembers: 1
            )
        )

        XCTAssertFalse(migrator.requiresMigration())
        try migrator.performMigration()

        XCTAssertFalse(stagedHookCalled)
        XCTAssertFalse(replacementCalled)
        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: storeURL),
            before
        )
    }

    func testPerformMigration_whenCleanCurrentRuntimeRootExceedsRowLimit_thenRejectsBeforeHookReplacementOrMutation() throws {
        let currentModel = try model(for: .version8)
        try createStore(at: storeURL, model: currentModel) {
            context in
            for index in 0 ..< 2 {
                try self.insertRuntimeItem(
                    identifier: "runtime-\(index)",
                    in: context,
                    model: currentModel
                )
            }
        }
        let before = try durableStoreFamilySnapshot(at: storeURL)
        var stagedHookCalled = false
        var replacementCalled = false
        var materializedRelationships = [(String, String, Int)]()
        let migrator = makeMigrator(
            storeReplacer: { _, _ in
                replacementCalled = true
            },
            stagedStoreMutationHook: { _, _ in
                stagedHookCalled = true
            },
            protectedDataInspectionLimits:
            makeProtectedDataLimits(
                maximumStartupRootRowsPerEntity: 1
            ),
            protectedRelationshipWillMaterialize: {
                materializedRelationships.append(($0, $1, $2))
            }
        )

        XCTAssertTrue(migrator.requiresMigration())
        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: storeURL),
            before
        )
        XCTAssertThrowsError(try migrator.performMigration()) {
            error in
            guard
                let migrationError =
                    error as? SubstrateStorageMigrationError,
                case let .sourceStoreInspectionFailed(
                    _,
                    underlyingError
                ) = migrationError,
                case let .entityRowLimitExceeded(
                    entityName,
                    actual,
                    maximum
                ) =
                    underlyingError as?
                    SubstrateProtectedDataInspectionError
            else {
                return XCTFail(
                    "Expected current root row limit, got \(error)"
                )
            }

            XCTAssertEqual(entityName, "CDRuntimeMetadataItem")
            XCTAssertEqual(actual, 2)
            XCTAssertEqual(maximum, 1)
        }
        XCTAssertFalse(stagedHookCalled)
        XCTAssertFalse(replacementCalled)
        XCTAssertTrue(materializedRelationships.isEmpty)
        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: storeURL),
            before
        )
    }

    func testPerformMigration_whenCleanCurrentRootPayloadIsExactlyAtByteLimit_thenAuditsWithoutHookReplacementOrMutation() throws {
        let currentModel = try model(for: .version8)
        try createStore(at: storeURL, model: currentModel) {
            context in
            let runtime = try self.insertRuntimeItem(
                identifier: "root",
                in: context,
                model: currentModel
            )
            runtime.setValue(Data([1, 2, 3]), forKey: "metadata")
            runtime.setValue(Data([4, 5]), forKey: "resolver")
        }
        let before = try durableStoreFamilySnapshot(at: storeURL)
        var stagedHookCalled = false
        var replacementCalled = false
        let migrator = makeMigrator(
            storeReplacer: { _, _ in
                replacementCalled = true
            },
            stagedStoreMutationHook: { _, _ in
                stagedHookCalled = true
            },
            protectedDataInspectionLimits:
            makeProtectedDataLimits(
                maximumStartupRootPayloadByteCount: 11
            )
        )

        XCTAssertFalse(migrator.requiresMigration())
        try migrator.performMigration()

        XCTAssertFalse(stagedHookCalled)
        XCTAssertFalse(replacementCalled)
        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: storeURL),
            before
        )
    }

    func testPerformMigration_whenCleanCurrentRootPayloadExceedsByteLimit_thenRejectsBeforeHookReplacementOrMutation() throws {
        let currentModel = try model(for: .version8)
        try createStore(at: storeURL, model: currentModel) {
            context in
            let runtime = try self.insertRuntimeItem(
                identifier: "root",
                in: context,
                model: currentModel
            )
            runtime.setValue(Data([1, 2, 3]), forKey: "metadata")
            runtime.setValue(Data([4, 5]), forKey: "resolver")
        }
        let before = try durableStoreFamilySnapshot(at: storeURL)
        var stagedHookCalled = false
        var replacementCalled = false
        let migrator = makeMigrator(
            storeReplacer: { _, _ in
                replacementCalled = true
            },
            stagedStoreMutationHook: { _, _ in
                stagedHookCalled = true
            },
            protectedDataInspectionLimits:
            makeProtectedDataLimits(
                maximumStartupRootPayloadByteCount: 10
            )
        )

        XCTAssertTrue(migrator.requiresMigration())
        XCTAssertThrowsError(try migrator.performMigration()) {
            error in
            guard
                let migrationError =
                    error as? SubstrateStorageMigrationError,
                case let .sourceStoreInspectionFailed(
                    _,
                    underlyingError
                ) = migrationError,
                case let .startupRootPayloadByteLimitExceeded(
                    actual,
                    maximum
                ) =
                    underlyingError as?
                    SubstrateProtectedDataInspectionError
            else {
                return XCTFail(
                    "Expected startup root payload limit, got \(error)"
                )
            }

            XCTAssertEqual(actual, 11)
            XCTAssertEqual(maximum, 10)
        }
        XCTAssertFalse(stagedHookCalled)
        XCTAssertFalse(replacementCalled)
        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: storeURL),
            before
        )
    }

    func testPerformMigration_whenCurrentPriceStringIsExactlyAtStartupChildValueLimit_thenAuditsWithoutMutation() throws {
        let currentModel = try model(for: .version8)
        try createStore(at: storeURL, model: currentModel) {
            context in
            try self.insertStartupPayloadEntity(
                entityName: "CDPriceData",
                attributeName: "price",
                payload: String(repeating: "7", count: 1_024),
                in: context,
                model: currentModel
            )
        }
        let before = try durableStoreFamilySnapshot(at: storeURL)
        var stagedHookCalled = false
        var replacementCalled = false
        let migrator = makeMigrator(
            storeReplacer: { _, _ in
                replacementCalled = true
            },
            stagedStoreMutationHook: { _, _ in
                stagedHookCalled = true
            },
            protectedDataInspectionLimits:
            makeProtectedDataLimits(
                maximumStartupChildValueByteCount: 1_024
            )
        )

        XCTAssertFalse(migrator.requiresMigration())
        try migrator.performMigration()

        XCTAssertFalse(stagedHookCalled)
        XCTAssertFalse(replacementCalled)
        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: storeURL),
            before
        )
    }

    func testPerformMigration_whenCurrentPriceStringExceedsStartupChildValueLimit_thenRejectsBeforeCoreDataOrMutation() throws {
        try assertStartupChildValueLimitExceeded(
            entityName: "CDPriceData",
            attributeName: "price"
        )
    }

    func testPerformMigration_whenCurrentAssetNameExceedsStartupChildValueLimit_thenRejectsBeforeCoreDataOrMutation() throws {
        try assertStartupChildValueLimitExceeded(
            entityName: "CDAsset",
            attributeName: "name"
        )
    }

    func testPerformMigration_whenCurrentCustomNodeNameExceedsStartupChildValueLimit_thenRejectsBeforeCoreDataOrMutation() throws {
        try assertStartupChildValueLimitExceeded(
            entityName: "CDChainNode",
            attributeName: "name",
            attachNodeAsCustomNode: true
        )
    }

    func testPerformMigration_whenCurrentExplorerURLExceedsStartupChildValueLimit_thenRejectsBeforeCoreDataOrMutation() throws {
        try assertStartupChildValueLimitExceeded(
            entityName: "CDExternalApi",
            attributeName: "url"
        )
    }

    func testPerformMigration_whenCurrentXcmConfigVersionExceedsStartupChildValueLimit_thenRejectsBeforeCoreDataOrMutation() throws {
        try assertStartupChildValueLimitExceeded(
            entityName: "CDChainXcmConfig",
            attributeName: "xcmVersion"
        )
    }

    func testPerformMigration_whenCurrentXcmDestinationChainIdExceedsStartupChildValueLimit_thenRejectsBeforeCoreDataOrMutation() throws {
        try assertStartupChildValueLimitExceeded(
            entityName: "CDXcmAvailableDestination",
            attributeName: "chainId"
        )
    }

    func testPerformMigration_whenCurrentXcmAssetIdentifierExceedsStartupChildValueLimit_thenRejectsBeforeCoreDataOrMutation() throws {
        try assertStartupChildValueLimitExceeded(
            entityName: "CDXcmAvailableAsset",
            attributeName: "id"
        )
    }

    func testPerformMigration_whenCurrentPriceProviderIdentifierExceedsStartupChildValueLimit_thenRejectsBeforeCoreDataOrMutation() throws {
        try assertStartupChildValueLimitExceeded(
            entityName: "CDPriceProvider",
            attributeName: "id"
        )
    }

    func testPerformMigration_whenCurrentChildPayloadAggregateIsExactlyAtLimit_thenAuditsWithoutMutation() throws {
        let currentModel = try model(for: .version8)
        try createStore(at: storeURL, model: currentModel) {
            context in
            try self.insertStartupPayloadEntity(
                entityName: "CDPriceData",
                attributeName: "price",
                payload: "1234",
                in: context,
                model: currentModel
            )
        }
        let before = try durableStoreFamilySnapshot(at: storeURL)
        var stagedHookCalled = false
        var replacementCalled = false
        let migrator = makeMigrator(
            storeReplacer: { _, _ in
                replacementCalled = true
            },
            stagedStoreMutationHook: { _, _ in
                stagedHookCalled = true
            },
            protectedDataInspectionLimits:
            makeProtectedDataLimits(
                maximumStartupChildValueByteCount: 4,
                maximumStartupChildPayloadByteCount: 6
            )
        )

        XCTAssertFalse(migrator.requiresMigration())
        try migrator.performMigration()

        XCTAssertFalse(stagedHookCalled)
        XCTAssertFalse(replacementCalled)
        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: storeURL),
            before
        )
    }

    func testPerformMigration_whenCurrentChildPayloadAggregateExceedsLimitByOne_thenRejectsBeforeCoreDataOrMutation() throws {
        let currentModel = try model(for: .version8)
        try createStore(at: storeURL, model: currentModel) {
            context in
            try self.insertStartupPayloadEntity(
                entityName: "CDPriceData",
                attributeName: "price",
                payload: "1234",
                in: context,
                model: currentModel
            )
        }
        let before = try durableStoreFamilySnapshot(at: storeURL)
        var stagedHookCalled = false
        var replacementCalled = false
        let migrator = makeMigrator(
            storeReplacer: { _, _ in
                replacementCalled = true
            },
            stagedStoreMutationHook: { _, _ in
                stagedHookCalled = true
            },
            protectedDataInspectionLimits:
            makeProtectedDataLimits(
                maximumStartupChildValueByteCount: 4,
                maximumStartupChildPayloadByteCount: 5
            )
        )

        XCTAssertTrue(migrator.requiresMigration())
        XCTAssertThrowsError(try migrator.performMigration()) {
            error in
            guard
                let migrationError =
                    error as? SubstrateStorageMigrationError,
                case let .sourceStoreInspectionFailed(
                    failedURL,
                    underlyingError
                ) = migrationError,
                case let .startupChildPayloadByteLimitExceeded(
                    actual,
                    maximum
                ) =
                    underlyingError as?
                    SubstrateProtectedDataInspectionError
            else {
                return XCTFail(
                    "Expected startup child aggregate limit, got \(error)"
                )
            }

            XCTAssertEqual(failedURL, self.storeURL)
            XCTAssertEqual(actual, 6)
            XCTAssertEqual(maximum, 5)
        }
        XCTAssertFalse(stagedHookCalled)
        XCTAssertFalse(replacementCalled)
        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: storeURL),
            before
        )
    }

    func testPerformMigration_whenCleanCurrentNodesExceedRelationshipLimit_thenRejectsWhileFaultedBeforeHookReplacementOrMutation() throws {
        let currentModel = try model(for: .version8)
        try createStore(at: storeURL, model: currentModel) {
            context in
            try self.insertLegacyChainWithNodes(
                in: context,
                model: currentModel
            )
        }
        let before = try durableStoreFamilySnapshot(at: storeURL)
        var stagedHookCalled = false
        var replacementCalled = false
        var nodeCounts = [(Bool, Int)]()
        var materializedRelationships = [(String, String, Int)]()
        let migrator = makeMigrator(
            storeReplacer: { _, _ in
                replacementCalled = true
            },
            stagedStoreMutationHook: { _, _ in
                stagedHookCalled = true
            },
            protectedDataInspectionLimits:
            makeProtectedDataLimits(
                maximumRelationshipMembers: 1
            ),
            protectedRelationshipCountDidFetch: {
                guard $1 == "nodes" else {
                    return
                }
                nodeCounts.append(
                    (
                        $0.hasFault(forRelationshipNamed: $1),
                        $2
                    )
                )
            },
            protectedRelationshipWillMaterialize: {
                materializedRelationships.append(($0, $1, $2))
            }
        )

        XCTAssertTrue(migrator.requiresMigration())
        XCTAssertThrowsError(try migrator.performMigration()) {
            error in
            guard
                let migrationError =
                    error as? SubstrateStorageMigrationError,
                case let .sourceStoreInspectionFailed(
                    _,
                    underlyingError
                ) = migrationError,
                case let .relationshipLimitExceeded(
                    entityName,
                    relationshipName,
                    actual,
                    maximum
                ) =
                    underlyingError as?
                    SubstrateProtectedDataInspectionError
            else {
                return XCTFail(
                    "Expected current nodes limit, got \(error)"
                )
            }

            XCTAssertEqual(entityName, "CDChain")
            XCTAssertEqual(relationshipName, "nodes")
            XCTAssertEqual(actual, 2)
            XCTAssertEqual(maximum, 1)
        }
        XCTAssertEqual(nodeCounts.map(\.1), [2, 2])
        XCTAssertTrue(nodeCounts.allSatisfy(\.0))
        XCTAssertTrue(materializedRelationships.isEmpty)
        XCTAssertFalse(stagedHookCalled)
        XCTAssertFalse(replacementCalled)
        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: storeURL),
            before
        )
    }

    func testPerformMigration_whenCleanCurrentPriceDataExceedsRelationshipLimit_thenRejectsWhileFaultedBeforeHookReplacementOrMutation() throws {
        let currentModel = try model(for: .version8)
        try createStore(at: storeURL, model: currentModel) {
            context in
            let asset = try self.insertMigrationAsset(
                identifier: "bounded-price-asset",
                in: context,
                model: currentModel
            )
            try self.insertPriceData(
                count: 2,
                for: asset,
                in: context,
                model: currentModel
            )
        }
        let before = try durableStoreFamilySnapshot(at: storeURL)
        var stagedHookCalled = false
        var replacementCalled = false
        var priceDataCounts = [(Bool, Int)]()
        var materializedRelationships = [(String, String, Int)]()
        let migrator = makeMigrator(
            storeReplacer: { _, _ in
                replacementCalled = true
            },
            stagedStoreMutationHook: { _, _ in
                stagedHookCalled = true
            },
            protectedDataInspectionLimits:
            makeProtectedDataLimits(
                maximumRelationshipMembers: 1
            ),
            protectedRelationshipCountDidFetch: {
                guard $1 == "priceData" else {
                    return
                }
                priceDataCounts.append(
                    (
                        $0.hasFault(forRelationshipNamed: $1),
                        $2
                    )
                )
            },
            protectedRelationshipWillMaterialize: {
                materializedRelationships.append(($0, $1, $2))
            }
        )

        XCTAssertTrue(migrator.requiresMigration())
        XCTAssertThrowsError(try migrator.performMigration()) {
            error in
            guard
                let migrationError =
                    error as? SubstrateStorageMigrationError,
                case let .sourceStoreInspectionFailed(
                    _,
                    underlyingError
                ) = migrationError,
                case let .relationshipLimitExceeded(
                    entityName,
                    relationshipName,
                    actual,
                    maximum
                ) =
                    underlyingError as?
                    SubstrateProtectedDataInspectionError
            else {
                return XCTFail(
                    "Expected current priceData limit, got \(error)"
                )
            }

            XCTAssertEqual(entityName, "CDAsset")
            XCTAssertEqual(relationshipName, "priceData")
            XCTAssertEqual(actual, 2)
            XCTAssertEqual(maximum, 1)
        }
        XCTAssertEqual(priceDataCounts.map(\.1), [2, 2])
        XCTAssertTrue(priceDataCounts.allSatisfy(\.0))
        XCTAssertTrue(materializedRelationships.isEmpty)
        XCTAssertFalse(stagedHookCalled)
        XCTAssertFalse(replacementCalled)
        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: storeURL),
            before
        )
    }

    func testPerformMigration_whenCleanCurrentXcmRelationshipsExceedAggregateLimit_thenRejectsBeforeHookReplacementOrMutation() throws {
        let currentModel = try model(for: .version8)
        try createStore(at: storeURL, model: currentModel) {
            context in
            let graph = try self.insertChainWithDefaultNode(
                in: context,
                model: currentModel
            )
            try self.insertXcmRelationshipGraph(
                for: graph.chain,
                in: context,
                model: currentModel
            )
        }
        let before = try durableStoreFamilySnapshot(at: storeURL)
        var stagedHookCalled = false
        var replacementCalled = false
        var xcmCounts = [(String, Bool, Int)]()
        var materializedRelationships = [(String, String, Int)]()
        let migrator = makeMigrator(
            storeReplacer: { _, _ in
                replacementCalled = true
            },
            stagedStoreMutationHook: { _, _ in
                stagedHookCalled = true
            },
            protectedDataInspectionLimits:
            makeProtectedDataLimits(
                maximumRelationshipMembers: 1,
                maximumTotalRelationshipMembers: 2
            ),
            protectedRelationshipCountDidFetch: {
                guard
                    $0.entity.name == "CDChainXcmConfig"
                else {
                    return
                }
                xcmCounts.append(
                    (
                        $1,
                        $0.hasFault(forRelationshipNamed: $1),
                        $2
                    )
                )
            },
            protectedRelationshipWillMaterialize: {
                materializedRelationships.append(($0, $1, $2))
            }
        )

        XCTAssertTrue(migrator.requiresMigration())
        XCTAssertThrowsError(try migrator.performMigration()) {
            error in
            guard
                let migrationError =
                    error as? SubstrateStorageMigrationError,
                case let .sourceStoreInspectionFailed(
                    _,
                    underlyingError
                ) = migrationError,
                case let .totalRelationshipLimitExceeded(
                    actual,
                    maximum
                ) =
                    underlyingError as?
                    SubstrateProtectedDataInspectionError
            else {
                return XCTFail(
                    "Expected current XCM aggregate limit, got \(error)"
                )
            }

            XCTAssertEqual(actual, 3)
            XCTAssertEqual(maximum, 2)
        }
        XCTAssertEqual(
            xcmCounts.map(\.0),
            [
                "availableAssets",
                "availableDestinations",
                "availableAssets",
                "availableDestinations"
            ]
        )
        XCTAssertTrue(
            xcmCounts.allSatisfy {
                $0.1 && $0.2 == 1
            }
        )
        XCTAssertTrue(materializedRelationships.isEmpty)
        XCTAssertFalse(stagedHookCalled)
        XCTAssertFalse(replacementCalled)
        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: storeURL),
            before
        )
    }

    func testPerformMigration_whenRepairedCurrentStageIntroducesOversizedPriceDataRelationship_thenRejectsBeforeReplacement() throws {
        try createCurrentTransformableAndProtectedGraph()
        let wrongTypeArchive = try NSKeyedArchiver.archivedData(
            withRootObject: NSString(string: "repair-me"),
            requiringSecureCoding: true
        )
        try executeSQLite(
            """
            UPDATE ZCDCHAIN
            SET ZOPTIONS = X'\(hex(wrongTypeArchive))'
            """,
            at: storeURL
        )
        let before = try durableStoreFamilySnapshot(at: storeURL)
        var stagedHookCalled = false
        var replacementCalled = false
        let migrator = makeMigrator(
            storeReplacer: { _, _ in
                replacementCalled = true
            },
            stagedStoreMutationHook: { stagedURL, targetModel in
                stagedHookCalled = true
                try self.addPriceDataToSingleAsset(
                    count: 2,
                    at: stagedURL,
                    model: targetModel
                )
            },
            protectedDataInspectionLimits:
            makeProtectedDataLimits(
                maximumRelationshipMembers: 1
            )
        )

        XCTAssertThrowsError(try migrator.performMigration()) {
            error in
            guard
                let migrationError =
                    error as? SubstrateStorageMigrationError,
                case let .stagedStoreInspectionFailed(
                    _,
                    underlyingError
                ) = migrationError,
                case let .relationshipLimitExceeded(
                    entityName,
                    relationshipName,
                    actual,
                    maximum
                ) =
                    underlyingError as?
                    SubstrateProtectedDataInspectionError
            else {
                return XCTFail(
                    "Expected staged priceData limit, got \(error)"
                )
            }

            XCTAssertEqual(entityName, "CDAsset")
            XCTAssertEqual(relationshipName, "priceData")
            XCTAssertEqual(actual, 2)
            XCTAssertEqual(maximum, 1)
        }
        XCTAssertTrue(stagedHookCalled)
        XCTAssertFalse(replacementCalled)
        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: storeURL),
            before
        )
    }

    func testPerformMigration_whenCurrentStoreHasLargeSharedMemorySidecar_thenUsesOneDisposableCopyAndCleansIt() throws {
        let currentModel = try model(for: .version8)
        try createStore(at: storeURL, model: currentModel) { context in
            try self.insertRuntimeItem(
                identifier: "current-large-family",
                in: context,
                model: currentModel
            )
        }
        let sharedMemoryURL = URL(fileURLWithPath: storeURL.path + "-shm")
        try Data(repeating: 0xA5, count: 4 * 1_024 * 1_024).write(
            to: sharedMemoryURL,
            options: .atomic
        )
        let before = try durableStoreFamilySnapshot(at: storeURL)
        let fileManager = TemporaryStoreFootprintFileManager()
        let migrator = makeMigrator(fileManager: fileManager)

        try migrator.performMigration()

        XCTAssertEqual(try durableStoreFamilySnapshot(at: storeURL), before)
        XCTAssertEqual(fileManager.maximumTemporaryMainStoreCount, 1)
        XCTAssertFalse(fileManager.copiedSharedMemorySidecar)
        XCTAssertTrue(fileManager.temporaryRootsAreClean)
    }

    func testPerformMigration_whenSourceFamilyExceedsPrivateCopyLimit_thenRejectsBeforeCapacityInspectionOrMutation() throws {
        let sourceModel = try model(for: .version7)
        try createStore(at: storeURL, model: sourceModel) {
            context in
            try self.insertRuntimeItem(
                identifier: "oversized-private-copy",
                in: context,
                model: sourceModel
            )
        }
        let before = try durableStoreFamilySnapshot(at: storeURL)
        var capacityInspectionCount = 0
        var replacementAttempted = false
        let fileManager = TemporaryStoreFootprintFileManager()
        let migrator = makeMigrator(
            fileManager: fileManager,
            storeReplacer: { _, _ in
                replacementAttempted = true
            },
            privateSourceCopyLimits:
            SQLiteStoreFamilyCopyLimits(
                maximumFamilyByteCount: 1,
                minimumFreeStorageReserveByteCount: 0
            ),
            privateSourceAvailableCapacityProvider: { _ in
                capacityInspectionCount += 1
                return UInt64.max
            }
        )

        XCTAssertThrowsError(try migrator.performMigration()) {
            error in
            guard
                let migrationError =
                    error as? SubstrateStorageMigrationError,
                case let .sourceSnapshotFailed(
                    failedURL,
                    underlyingError
                ) = migrationError,
                case let .storeFamilyTooLarge(
                    actualByteCount,
                    maximumByteCount
                ) =
                    underlyingError as?
                    CrashConsistentStoreReplacementError
            else {
                return XCTFail(
                    "Expected bounded source-copy rejection, got \(error)"
                )
            }

            XCTAssertEqual(failedURL, self.storeURL)
            XCTAssertGreaterThan(actualByteCount, 1)
            XCTAssertEqual(maximumByteCount, 1)
        }
        XCTAssertEqual(capacityInspectionCount, 0)
        XCTAssertFalse(replacementAttempted)
        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: storeURL),
            before
        )
        XCTAssertTrue(fileManager.temporaryRootsAreClean)
    }

    func testPerformMigration_whenPrivateCopyCapacityIsInsufficient_thenRejectsBeforeCopyOrMutation() throws {
        let sourceModel = try model(for: .version7)
        try createStore(at: storeURL, model: sourceModel) {
            context in
            try self.insertRuntimeItem(
                identifier: "capacity-bounded-private-copy",
                in: context,
                model: sourceModel
            )
        }
        let before = try durableStoreFamilySnapshot(at: storeURL)
        var capacityInspectionCount = 0
        var replacementAttempted = false
        let fileManager = TemporaryStoreFootprintFileManager()
        let migrator = makeMigrator(
            fileManager: fileManager,
            storeReplacer: { _, _ in
                replacementAttempted = true
            },
            privateSourceCopyLimits:
            SQLiteStoreFamilyCopyLimits(
                maximumFamilyByteCount: UInt64.max,
                minimumFreeStorageReserveByteCount: 1
            ),
            privateSourceAvailableCapacityProvider: { _ in
                capacityInspectionCount += 1
                return 0
            }
        )

        XCTAssertThrowsError(try migrator.performMigration()) {
            error in
            guard
                let migrationError =
                    error as? SubstrateStorageMigrationError,
                case let .sourceSnapshotFailed(
                    failedURL,
                    underlyingError
                ) = migrationError,
                case let .insufficientStorageCapacity(
                    requiredByteCount,
                    availableByteCount
                ) =
                    underlyingError as?
                    CrashConsistentStoreReplacementError
            else {
                return XCTFail(
                    "Expected private-copy capacity rejection, got \(error)"
                )
            }

            XCTAssertEqual(failedURL, self.storeURL)
            XCTAssertGreaterThan(requiredByteCount, 1)
            XCTAssertEqual(availableByteCount, 0)
        }
        XCTAssertEqual(capacityInspectionCount, 1)
        XCTAssertFalse(replacementAttempted)
        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: storeURL),
            before
        )
        XCTAssertTrue(fileManager.temporaryRootsAreClean)
    }

    func testPerformMigration_whenStoreIsCorrupt_thenThrowsAndPreservesEveryStoreFile() throws {
        try Data("not-a-core-data-store".utf8).write(to: storeURL, options: .atomic)
        let before = try durableStoreFamilySnapshot(at: storeURL)
        let migrator = makeMigrator()

        XCTAssertTrue(migrator.requiresMigration())
        XCTAssertThrowsError(try migrator.performMigration()) { error in
            guard
                let migrationError = error as? SubstrateStorageMigrationError,
                case .metadataUnreadable = migrationError
            else {
                return XCTFail("Expected metadataUnreadable, got \(error)")
            }
        }

        XCTAssertEqual(try durableStoreFamilySnapshot(at: storeURL), before)
    }

    func testSyncMigration_whenStoreIsCorrupt_thenFailsClosedAndPreservesEverySidecar() throws {
        let corruptBytes = Data("not-a-core-data-store".utf8)
        try corruptBytes.write(to: storeURL, options: .atomic)
        try Data("substrate-wal".utf8).write(
            to: URL(fileURLWithPath: storeURL.path + "-wal"),
            options: .atomic
        )

        let userStoreURL = testDirectory.appendingPathComponent("UserDataModel.sqlite")
        let userWALURL = URL(fileURLWithPath: userStoreURL.path + "-wal")
        let userSHMURL = URL(fileURLWithPath: userStoreURL.path + "-shm")
        let userJournalURL = URL(fileURLWithPath: userStoreURL.path + "-journal")
        let userStoreBytes = Data("wallet-store-must-not-move".utf8)
        let userWALBytes = Data("wallet-wal-must-not-move".utf8)
        let userSHMBytes = Data("wallet-shm-must-not-move".utf8)
        let userJournalBytes = Data("wallet-journal-must-not-move".utf8)
        try userStoreBytes.write(to: userStoreURL, options: .atomic)
        try userWALBytes.write(to: userWALURL, options: .atomic)
        try userSHMBytes.write(to: userSHMURL, options: .atomic)
        try userJournalBytes.write(to: userJournalURL, options: .atomic)

        let migrator = makeMigrator()
        XCTAssertThrowsError(try migrator.migrate()) { error in
            guard
                let migrationError = error as? SubstrateStorageMigrationError,
                case .metadataUnreadable = migrationError
            else {
                return XCTFail("Expected metadataUnreadable, got \(error)")
            }
        }

        XCTAssertEqual(try Data(contentsOf: storeURL), corruptBytes)
        XCTAssertEqual(
            try Data(contentsOf: URL(fileURLWithPath: storeURL.path + "-wal")),
            Data("substrate-wal".utf8)
        )
        XCTAssertTrue(migrator.requiresMigration())
        XCTAssertEqual(try Data(contentsOf: userStoreURL), userStoreBytes)
        XCTAssertEqual(try Data(contentsOf: userWALURL), userWALBytes)
        XCTAssertEqual(try Data(contentsOf: userSHMURL), userSHMBytes)
        XCTAssertEqual(try Data(contentsOf: userJournalURL), userJournalBytes)
        XCTAssertTrue(try recoveryDirectories().isEmpty)

        XCTAssertThrowsError(try migrator.migrate())
        XCTAssertEqual(try Data(contentsOf: storeURL), corruptBytes)
        XCTAssertTrue(try recoveryDirectories().isEmpty)
        XCTAssertEqual(try Data(contentsOf: userStoreURL), userStoreBytes)
        XCTAssertEqual(try Data(contentsOf: userWALURL), userWALBytes)
        XCTAssertEqual(try Data(contentsOf: userSHMURL), userSHMBytes)
        XCTAssertEqual(try Data(contentsOf: userJournalURL), userJournalBytes)
    }

    func testPerformMigration_whenStoreVersionIsUnknown_thenThrowsAndPreservesEveryStoreFile() throws {
        try createStore(at: storeURL, model: makeUnknownModel()) { _ in }
        let before = try durableStoreFamilySnapshot(at: storeURL)
        let migrator = makeMigrator()

        XCTAssertTrue(migrator.requiresMigration())
        XCTAssertThrowsError(try migrator.performMigration()) { error in
            guard
                let migrationError = error as? SubstrateStorageMigrationError,
                case .unknownStoreVersion = migrationError
            else {
                return XCTFail("Expected unknownStoreVersion, got \(error)")
            }
        }

        XCTAssertEqual(try durableStoreFamilySnapshot(at: storeURL), before)
    }

    func testSyncMigration_whenStoreVersionIsUnknown_thenFailsClosedAndPreservesEveryStoreFile() throws {
        try createStore(at: storeURL, model: makeUnknownModel()) { _ in }
        let before = try durableStoreFamilySnapshot(at: storeURL)
        let migrator = makeMigrator()

        XCTAssertThrowsError(try migrator.migrate()) { error in
            guard
                let migrationError = error as? SubstrateStorageMigrationError,
                case .unknownStoreVersion = migrationError
            else {
                return XCTFail("Expected unknownStoreVersion, got \(error)")
            }
        }

        XCTAssertEqual(try durableStoreFamilySnapshot(at: storeURL), before)
        XCTAssertTrue(try recoveryDirectories().isEmpty)

        XCTAssertThrowsError(try migrator.migrate())
        XCTAssertEqual(try durableStoreFamilySnapshot(at: storeURL), before)
        XCTAssertTrue(try recoveryDirectories().isEmpty)
    }

    func testSyncMigration_whenKnownStoreCannotBeInspected_thenFailsClosedAndPreservesEveryStoreFile() throws {
        let sourceModel = try model(for: .version3)
        try createStore(at: storeURL, model: sourceModel) { context in
            try self.insertRuntimeItem(
                identifier: "uninspectable-runtime",
                in: context,
                model: sourceModel
            )
        }
        try executeSQLite(
            "PRAGMA journal_mode=DELETE; DROP TABLE ZCDCONTACT",
            at: storeURL
        )

        let before = try durableStoreFamilySnapshot(at: storeURL)
        let migrator = makeMigrator()

        for _ in 0 ..< 2 {
            XCTAssertThrowsError(try migrator.migrate()) { error in
                guard
                    let migrationError = error as? SubstrateStorageMigrationError,
                    case .sourceStoreInspectionFailed = migrationError
                else {
                    return XCTFail("Expected sourceStoreInspectionFailed, got \(error)")
                }
            }

            XCTAssertTrue(migrator.requiresMigration())
            XCTAssertEqual(try durableStoreFamilySnapshot(at: storeURL), before)
            XCTAssertTrue(try recoveryDirectories().isEmpty)
        }
    }

    func testPerformMigration_whenTargetModelIsMissing_thenThrowsBeforeCheckpointAndPreservesSource() throws {
        let sourceModel = try model(for: .version7)
        try createStore(at: storeURL, model: sourceModel) { context in
            try self.insertRuntimeItem(identifier: "missing-model", in: context, model: sourceModel)
        }
        let before = try durableStoreFamilySnapshot(at: storeURL)
        let modelBundle = try makeModelBundle(omitting: .version8)
        let migrator = makeMigrator(modelBundle: modelBundle)

        XCTAssertThrowsError(try migrator.performMigration()) { error in
            guard
                let migrationError = error as? SubstrateStorageMigrationError,
                case let .modelUnavailable(version) = migrationError
            else {
                return XCTFail("Expected modelUnavailable, got \(error)")
            }

            XCTAssertEqual(version, .version8)
        }

        XCTAssertEqual(try durableStoreFamilySnapshot(at: storeURL), before)
        XCTAssertEqual(
            try count(entityName: "CDRuntimeMetadataItem", at: storeURL, model: sourceModel),
            1
        )
    }

    func testPerformMigration_whenAskedToDowngrade_thenThrowsBeforeCheckpointAndPreservesSource() throws {
        let sourceModel = try model(for: .version8)
        try createStore(at: storeURL, model: sourceModel) { context in
            try self.insertRuntimeItem(identifier: "downgrade", in: context, model: sourceModel)
        }
        let before = try durableStoreFamilySnapshot(at: storeURL)
        let migrator = makeMigrator(targetVersion: .version7)

        XCTAssertThrowsError(try migrator.performMigration()) { error in
            guard
                let migrationError = error as? SubstrateStorageMigrationError,
                case let .migrationPathUnavailable(source, destination) = migrationError
            else {
                return XCTFail("Expected migrationPathUnavailable, got \(error)")
            }

            XCTAssertEqual(source, .version8)
            XCTAssertEqual(destination, .version7)
        }

        XCTAssertEqual(try durableStoreFamilySnapshot(at: storeURL), before)
        XCTAssertEqual(
            try count(entityName: "CDRuntimeMetadataItem", at: storeURL, model: sourceModel),
            1
        )
    }

    func testPerformMigration_whenVersion7Store_thenStagesValidVersion8AndPreservesRows() throws {
        let sourceModel = try model(for: .version7)
        try createStore(at: storeURL, model: sourceModel) { context in
            try self.insertRuntimeItem(identifier: "legacy-runtime", in: context, model: sourceModel)
            try self.insertMigrationAsset(
                identifier: "legacy-asset",
                in: context,
                model: sourceModel
            )
        }
        let migrator = makeMigrator()

        XCTAssertTrue(migrator.requiresMigration())
        try migrator.performMigration()

        let targetModel = try model(for: .version8)
        XCTAssertFalse(migrator.requiresMigration())
        XCTAssertTrue(try isStore(at: storeURL, compatibleWith: targetModel, version: .version8))
        XCTAssertEqual(
            try count(entityName: "CDRuntimeMetadataItem", at: storeURL, model: targetModel),
            1
        )
        XCTAssertEqual(
            try count(entityName: "CDAsset", at: storeURL, model: targetModel),
            1
        )
    }

    func testPerformMigration_whenEverySupportedLegacyVersion_thenReachesV8AndPreservesRows() throws {
        for sourceVersion in SubstrateStorageVersion.allCases where sourceVersion != .version8 {
            let caseDirectory = testDirectory.appendingPathComponent(
                sourceVersion.rawValue,
                isDirectory: true
            )
            try FileManager.default.createDirectory(
                at: caseDirectory,
                withIntermediateDirectories: true
            )
            let caseStoreURL = caseDirectory.appendingPathComponent(
                SubstrateStorageParams.databaseName
            )
            let sourceModel = try model(for: sourceVersion)
            try createStore(at: caseStoreURL, model: sourceModel) { context in
                try self.insertRuntimeItem(
                    identifier: "runtime-\(sourceVersion.rawValue)",
                    in: context,
                    model: sourceModel
                )
                try self.insertChainStorageItem(
                    identifier: "storage-\(sourceVersion.rawValue)",
                    in: context,
                    model: sourceModel
                )
                try self.insertMigrationAsset(
                    identifier: "asset-\(sourceVersion.rawValue)",
                    in: context,
                    model: sourceModel
                )
            }

            let migrator = makeMigrator(storeURL: caseStoreURL)
            XCTAssertTrue(
                migrator.requiresMigration(),
                "\(sourceVersion.rawValue) should require migration"
            )

            try migrator.performMigration()

            let targetModel = try model(for: .version8)
            XCTAssertFalse(
                migrator.requiresMigration(),
                "\(sourceVersion.rawValue) should reach v8"
            )
            XCTAssertTrue(
                try isStore(
                    at: caseStoreURL,
                    compatibleWith: targetModel,
                    version: .version8
                )
            )
            XCTAssertEqual(
                try count(
                    entityName: "CDRuntimeMetadataItem",
                    at: caseStoreURL,
                    model: targetModel
                ),
                1,
                "\(sourceVersion.rawValue) lost runtime metadata"
            )
            XCTAssertEqual(
                try count(
                    entityName: "CDChainStorageItem",
                    at: caseStoreURL,
                    model: targetModel
                ),
                1,
                "\(sourceVersion.rawValue) lost chain storage"
            )
            XCTAssertEqual(
                try count(
                    entityName: "CDAsset",
                    at: caseStoreURL,
                    model: targetModel
                ),
                1,
                "\(sourceVersion.rawValue) lost an asset"
            )
        }
    }

    func testPerformMigration_whenOldestLegacyStore_thenNeverRetainsCompletedIntermediates() throws {
        let sourceModel = try model(for: .version1)
        try createStore(at: storeURL, model: sourceModel) { context in
            try self.insertRuntimeItem(
                identifier: "bounded-footprint-runtime",
                in: context,
                model: sourceModel
            )
            try self.insertMigrationAsset(
                identifier: "bounded-footprint-asset",
                in: context,
                model: sourceModel
            )
        }
        let fileManager = TemporaryStoreFootprintFileManager()
        let migrator = makeMigrator(fileManager: fileManager)

        try migrator.performMigration()

        let expectedStepCount = SubstrateStorageVersion.allCases.count - 1
        XCTAssertEqual(fileManager.maximumTemporaryMainStoreCount, 2)
        XCTAssertEqual(
            fileManager.temporaryMainStoreCountsBeforeRemoval,
            Array(repeating: 2, count: expectedStepCount)
        )
        XCTAssertEqual(
            fileManager.removedTemporaryMainStoreCount,
            expectedStepCount
        )
        XCTAssertTrue(fileManager.temporaryRootsAreClean)
        XCTAssertTrue(
            try isStore(
                at: storeURL,
                compatibleWith: model(for: .version8),
                version: .version8
            )
        )
    }

    func testPerformMigration_whenTemporaryInputCleanupFails_thenAbortsAndCleansEveryPrivateStore() throws {
        let sourceModel = try model(for: .version7)
        try createStore(at: storeURL, model: sourceModel) { context in
            try self.insertRuntimeItem(
                identifier: "cleanup-failure-runtime",
                in: context,
                model: sourceModel
            )
        }
        let before = try durableStoreFamilySnapshot(at: storeURL)
        let fileManager = FailingTemporaryStoreCleanupFileManager()
        let migrator = makeMigrator(fileManager: fileManager)

        XCTAssertThrowsError(try migrator.performMigration()) { error in
            guard
                let migrationError = error as? SubstrateStorageMigrationError,
                case .temporaryStoreCleanupFailed = migrationError
            else {
                return XCTFail("Expected temporaryStoreCleanupFailed, got \(error)")
            }
        }

        XCTAssertTrue(fileManager.didInjectCleanupFailure)
        XCTAssertTrue(fileManager.temporaryRootsAreClean)
        XCTAssertEqual(try durableStoreFamilySnapshot(at: storeURL), before)
    }

    func testPerformMigration_whenVersion1ChainHasNoSelectedNode_thenSelectsStableNode() throws {
        let sourceModel = try model(for: .version1)
        try createStore(at: storeURL, model: sourceModel) { context in
            try self.insertLegacyChainWithNodes(in: context, model: sourceModel)
        }

        try makeMigrator().performMigration()

        let targetModel = try model(for: .version8)
        try inspectStore(at: storeURL, model: targetModel) { context in
            let chain = try XCTUnwrap(
                try context.fetch(
                    NSFetchRequest<NSManagedObject>(entityName: "CDChain")
                ).first
            )
            let nodes = try XCTUnwrap(
                chain.value(forKey: "nodes") as? Set<NSManagedObject>
            )
            let selectedNode = try XCTUnwrap(
                chain.value(forKey: "selectedNode") as? NSManagedObject
            )

            XCTAssertEqual(nodes.count, 2)
            XCTAssertEqual(
                selectedNode.value(forKey: "url") as? URL,
                URL(string: "wss://alpha.example.invalid")
            )
            XCTAssertTrue(nodes.contains(selectedNode))
            XCTAssertEqual(selectedNode.value(forKey: "chain") as? NSManagedObject, chain)
        }
    }

    func testPerformMigration_whenVersion3ContainsChainGraph_thenUsesCustomV4Policy() throws {
        let sourceModel = try model(for: .version3)
        try createStore(at: storeURL, model: sourceModel) { context in
            try self.insertLegacyChainGraph(in: context, model: sourceModel)
        }

        try makeMigrator().performMigration()

        let targetModel = try model(for: .version8)
        XCTAssertEqual(
            try count(entityName: "CDChain", at: storeURL, model: targetModel),
            1
        )
        XCTAssertEqual(
            try count(entityName: "CDChainNode", at: storeURL, model: targetModel),
            1
        )
        XCTAssertEqual(
            try count(entityName: "CDAsset", at: storeURL, model: targetModel),
            1
        )

        try inspectStore(at: storeURL, model: targetModel) { context in
            let chain = try XCTUnwrap(
                try context.fetch(
                    NSFetchRequest<NSManagedObject>(entityName: "CDChain")
                ).first
            )
            let assets = try XCTUnwrap(
                chain.value(forKey: "assets") as? Set<NSManagedObject>
            )
            let asset = try XCTUnwrap(assets.first)

            XCTAssertEqual(assets.count, 1)
            XCTAssertEqual(asset.value(forKey: "id") as? String, "migration-asset")
            XCTAssertEqual(asset.value(forKey: "symbol") as? String, "MIG")
            XCTAssertEqual(asset.value(forKey: "isNative") as? Bool, true)
            XCTAssertEqual(asset.value(forKey: "isUtility") as? Bool, false)
            XCTAssertEqual(asset.value(forKey: "type") as? String, "normal")
            XCTAssertEqual(chain.value(forKey: "disabled") as? Bool, false)
            XCTAssertEqual(asset.value(forKey: "chain") as? NSManagedObject, chain)
        }
    }

    func testPerformMigration_whenV3ChainOptionsArchiveIsRawGarbage_thenDefaultsOnlyThatCache() throws {
        try assertAdversarialTransformableMigration(
            sourceVersion: .version3,
            updateSQL: "UPDATE ZCDCHAIN SET ZOPTIONS = X'00FF00'",
            expectedDefaultedKeys: ["CDChain.options"]
        )
    }

    func testPerformMigration_whenV3ExternalTypesArchiveIsEmpty_thenDefaultsOnlyThatCache() throws {
        try assertAdversarialTransformableMigration(
            sourceVersion: .version3,
            updateSQL: "UPDATE ZCDEXTERNALAPI SET ZTYPES = X''",
            expectedDefaultedKeys: ["CDExternalApi.types"]
        )
    }

    func testPerformMigration_whenV3PurchaseProvidersArchiveIsTruncated_thenV4PolicyStillPreservesGraph() throws {
        let truncatedArchive = try NSKeyedArchiver.archivedData(
            withRootObject: NSArray(object: "provider-a"),
            requiringSecureCoding: true
        ).prefix(8)

        try assertAdversarialTransformableMigration(
            sourceVersion: .version3,
            updateSQL:
                "UPDATE ZCDCHAINASSET SET ZPURCHASEPROVIDERS = " +
                "X'\(hex(Data(truncatedArchive)))'",
            expectedDefaultedKeys: ["CDChainAsset.purchaseProviders"]
        )
    }

    func testPerformMigration_whenV4AssetPurchaseProvidersArchiveIsRawGarbage_thenDefaultsOnlyAssetCache() throws {
        try assertAdversarialTransformableMigration(
            sourceVersion: .version4,
            updateSQL:
                "UPDATE ZCDASSET SET ZPURCHASEPROVIDERS = X'00FF00'",
            expectedDefaultedKeys: ["CDAsset.purchaseProviders"]
        )
    }

    func testPerformMigration_whenBothV3PolkaswapArchivesHaveWrongTypes_thenDefaultsBothRequiredArrays() throws {
        let wrongTypeArchive = try NSKeyedArchiver.archivedData(
            withRootObject: NSString(string: "not-an-array"),
            requiringSecureCoding: true
        )
        let archiveHex = hex(wrongTypeArchive)

        try assertAdversarialTransformableMigration(
            sourceVersion: .version3,
            updateSQL: """
            UPDATE ZCDPOLKASWAPREMOTESETTINGS
            SET ZAVAILABLESOURCES = X'\(archiveHex)',
                ZFORCESMARTIDS = X'\(archiveHex)'
            """,
            expectedDefaultedKeys: [
                "CDPolkaswapRemoteSettings.availableSources",
                "CDPolkaswapRemoteSettings.forceSmartIds"
            ]
        )
    }

    func testPerformMigration_whenV4LegacyXcmArchiveContainsDisallowedClass_thenDefaultsConfigAndPreservesDestination() throws {
        let disallowedArchive = try NSKeyedArchiver.archivedData(
            withRootObject: DisallowedSubstrateTransformablePayload(
                value: "must-not-decode"
            ),
            requiringSecureCoding: true
        )

        try assertAdversarialTransformableMigration(
            sourceVersion: .version4,
            updateSQL:
                "UPDATE ZCDCHAINXCMCONFIG SET ZAVAILABLEASSETS = " +
                "X'\(hex(disallowedArchive))'",
            expectedDefaultedKeys: ["CDChainXcmConfig.availableAssets"]
        )
    }

    func testPerformMigration_whenV3LegacyDestinationAssetsArchiveIsInvalid_thenDefaultsDestinationAndPreservesConfig() throws {
        try assertAdversarialTransformableMigration(
            sourceVersion: .version3,
            updateSQL:
                "UPDATE ZCDXCMAVAILABLEDESTINATION SET ZASSETS = X'00FF00'",
            expectedDefaultedKeys: ["CDXcmAvailableDestination.assets"]
        )
    }

    func testPerformMigration_whenAllV3TransformableArchivesAreValid_thenPreservesEveryValueAndProtectedRelationship() throws {
        try assertAdversarialTransformableMigration(
            sourceVersion: .version3,
            updateSQL: "UPDATE ZCDCHAIN SET ZOPTIONS = ZOPTIONS",
            expectedDefaultedKeys: []
        )
    }

    func testPerformMigration_whenEveryV3TransformableArchiveIsDamagedTogether_thenRepairsEveryKeyAndPreservesProtectedGraph() throws {
        let wrongTypeArchive = try NSKeyedArchiver.archivedData(
            withRootObject: NSString(string: "not-an-array"),
            requiringSecureCoding: true
        )
        let wrongTypeHex = hex(wrongTypeArchive)

        try assertAdversarialTransformableMigration(
            sourceVersion: .version3,
            updateSQL: """
            UPDATE ZCDCHAIN SET ZOPTIONS = X'00FF00';
            UPDATE ZCDCHAINASSET SET ZPURCHASEPROVIDERS = X'';
            UPDATE ZCDEXTERNALAPI SET ZTYPES = X'\(wrongTypeHex)';
            UPDATE ZCDPOLKASWAPREMOTESETTINGS
            SET ZAVAILABLESOURCES = X'00FF00',
                ZFORCESMARTIDS = X'\(wrongTypeHex)';
            UPDATE ZCDCHAINXCMCONFIG
            SET ZAVAILABLEASSETS = X'\(wrongTypeHex)';
            UPDATE ZCDXCMAVAILABLEDESTINATION SET ZASSETS = X'00FF00';
            """,
            expectedDefaultedKeys: [
                "CDChain.options",
                "CDChainAsset.purchaseProviders",
                "CDExternalApi.types",
                "CDPolkaswapRemoteSettings.availableSources",
                "CDPolkaswapRemoteSettings.forceSmartIds",
                "CDChainXcmConfig.availableAssets",
                "CDXcmAvailableDestination.assets"
            ]
        )
    }

    func testPerformMigration_whenTransformableElementCountIsExactlyAtLimit_thenPreservesArray() throws {
        try createVersion7AssetStore(
            purchaseProviders: ["provider-a", "provider-b"]
        )

        try makeMigrator(
            protectedDataInspectionLimits:
            makeProtectedDataLimits(
                maximumTransformableElements: 2
            )
        ).performMigration()

        XCTAssertEqual(
            try migratedAssetPurchaseProviders(),
            ["provider-a", "provider-b"]
        )
    }

    func testPerformMigration_whenTransformableElementCountExceedsLimit_thenRepairsArray() throws {
        try createVersion7AssetStore(
            purchaseProviders: [
                "provider-a",
                "provider-b",
                "provider-c"
            ]
        )

        try makeMigrator(
            protectedDataInspectionLimits:
            makeProtectedDataLimits(
                maximumTransformableElements: 2
            )
        ).performMigration()

        XCTAssertEqual(try migratedAssetPurchaseProviders(), [])
    }

    func testPerformMigration_whenTransformableUTF8BytesAreExactlyAtLimit_thenPreservesArray() throws {
        // One composed character plus two ASCII characters occupy four
        // cumulative UTF-8 bytes.
        try createVersion7AssetStore(
            purchaseProviders: ["é", "ab"]
        )

        try makeMigrator(
            protectedDataInspectionLimits:
            makeProtectedDataLimits(maximumValueByteCount: 4)
        ).performMigration()

        XCTAssertEqual(
            try migratedAssetPurchaseProviders(),
            ["é", "ab"]
        )
    }

    func testPerformMigration_whenTransformableUTF8BytesExceedLimit_thenRepairsArray() throws {
        // Each element is individually within budget, while their cumulative
        // UTF-8 representation is five bytes.
        try createVersion7AssetStore(
            purchaseProviders: ["é", "abc"]
        )

        try makeMigrator(
            protectedDataInspectionLimits:
            makeProtectedDataLimits(maximumValueByteCount: 4)
        ).performMigration()

        XCTAssertEqual(try migratedAssetPurchaseProviders(), [])
    }

    func testPerformMigration_whenRawTransformableArchiveIsExactlyAtLimit_thenPreservesArray() throws {
        try createVersion7AssetStore(
            purchaseProviders: ["raw-boundary"]
        )
        let archiveByteCount = try sqliteInteger(
            "SELECT length(ZPURCHASEPROVIDERS) FROM ZCDASSET LIMIT 1",
            at: storeURL
        )
        XCTAssertGreaterThan(archiveByteCount, 0)
        XCTAssertLessThanOrEqual(archiveByteCount, Int64(Int.max))

        try makeMigrator(
            protectedDataInspectionLimits:
            makeProtectedDataLimits(
                maximumTransformableArchiveByteCount:
                Int(archiveByteCount)
            )
        ).performMigration()

        XCTAssertEqual(
            try migratedAssetPurchaseProviders(),
            ["raw-boundary"]
        )
    }

    func testPerformMigration_whenRawTransformableArchiveExceedsLimit_thenRepairsBeforeCoreDataDecode() throws {
        try createVersion7AssetStore(
            purchaseProviders: ["will-be-replaced"]
        )
        try executeSQLite(
            """
            UPDATE ZCDASSET
            SET ZPURCHASEPROVIDERS = zeroblob(1025)
            """,
            at: storeURL
        )

        try makeMigrator(
            protectedDataInspectionLimits:
            makeProtectedDataLimits(
                maximumTransformableArchiveByteCount: 1024
            )
        ).performMigration()

        XCTAssertNil(try migratedAssetPurchaseProviders())
    }

    func testPerformMigration_whenOptionalTransformableUsesWrongSQLiteStorageClass_thenRepairsBeforeDecode() throws {
        try createVersion7AssetStore(
            purchaseProviders: ["will-be-replaced"]
        )
        try executeSQLite(
            """
            UPDATE ZCDASSET
            SET ZPURCHASEPROVIDERS = 'not-a-blob'
            """,
            at: storeURL
        )

        try makeMigrator().performMigration()

        XCTAssertNil(try migratedAssetPurchaseProviders())
    }

    func testPerformMigration_whenRequiredTransformableUsesWrongSQLiteStorageClass_thenWritesValidEmptyArchive() throws {
        let sourceModel = try model(for: .version7)
        try createStore(at: storeURL, model: sourceModel) {
            context in
            let settings = try self.insert(
                entityName: "CDPolkaswapRemoteSettings",
                in: context,
                model: sourceModel
            )
            settings.setValue("v1", forKey: "version")
            settings.setValue(
                NSArray(object: "source-a"),
                forKey: "availableSources"
            )
            settings.setValue(
                NSArray(object: "smart-a"),
                forKey: "forceSmartIds"
            )
        }
        try executeSQLite(
            """
            UPDATE ZCDPOLKASWAPREMOTESETTINGS
            SET ZFORCESMARTIDS = 42
            """,
            at: storeURL
        )

        try makeMigrator().performMigration()

        let targetModel = try model(for: .version8)
        try inspectStore(at: storeURL, model: targetModel) {
            context in
            let settings = try self.fetchSingleObject(
                entityName: "CDPolkaswapRemoteSettings",
                context: context
            )
            XCTAssertEqual(
                try self.stringArray(
                    in: settings,
                    key: "availableSources"
                ),
                ["source-a"]
            )
            XCTAssertEqual(
                try self.stringArray(
                    in: settings,
                    key: "forceSmartIds"
                ),
                []
            )
        }
    }

    func testPerformMigrationWithRecovery_whenTransformableEntityExceedsRowCap_thenRejectsBeforePagingReplacementOrQuarantine() throws {
        let sourceModel = try model(for: .version3)
        try createStore(at: storeURL, model: sourceModel) {
            context in
            try self.insertTransformableAndProtectedGraph(
                in: context,
                model: sourceModel
            )
        }
        try executeSQLite(
            "UPDATE ZCDCHAIN SET ZOPTIONS = X'00FF00'",
            at: storeURL
        )
        let before = try durableStoreFamilySnapshot(at: storeURL)
        var replacementAttempted = false
        var fetchedPages = [(String, Int, Int)]()
        let migrator = makeMigrator(
            storeReplacer: { _, _ in
                replacementAttempted = true
            },
            protectedDataInspectionLimits:
            makeProtectedDataLimits(maximumRowsPerEntity: 0),
            transformableObjectIDPageDidFetch: {
                fetchedPages.append(($0, $1, $2))
            }
        )

        XCTAssertThrowsError(
            try migrator.performMigrationWithRecovery()
        ) { error in
            guard
                let migrationError =
                    error as? SubstrateStorageMigrationError,
                case let .transformableSanitizationFailed(
                    version,
                    _
                ) = migrationError
            else {
                return XCTFail(
                    "Expected transformableSanitizationFailed, got \(error)"
                )
            }
            XCTAssertEqual(version, .version3)
        }

        XCTAssertTrue(fetchedPages.isEmpty)
        XCTAssertFalse(replacementAttempted)
        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: storeURL),
            before
        )
        XCTAssertTrue(try recoveryDirectories().isEmpty)
    }

    func testPerformMigration_whenBatchRepairsResetContext_thenImmutableIDCohortRepairsEveryRowExactlyOnce() throws {
        let sourceModel = try model(for: .version7)
        try createStore(at: storeURL, model: sourceModel) {
            context in
            try self.insertMigrationAsset(
                identifier: "paged-asset-a",
                in: context,
                model: sourceModel
            )
            try self.insertMigrationAsset(
                identifier: "paged-asset-b",
                in: context,
                model: sourceModel
            )
            let request = NSFetchRequest<NSManagedObject>(
                entityName: "CDAsset"
            )
            for asset in try context.fetch(request) {
                asset.setValue(
                    NSArray(object: "provider"),
                    forKey: "purchaseProviders"
                )
            }
        }
        try executeSQLite(
            """
            UPDATE ZCDASSET
            SET ZPURCHASEPROVIDERS = X'00FF00'
            """,
            at: storeURL
        )
        var fetchedPages = [(String, Int, Int)]()
        let migrator = makeMigrator(
            protectedDataInspectionLimits:
            makeProtectedDataLimits(fetchPageSize: 1),
            transformableObjectIDPageDidFetch: {
                fetchedPages.append(($0, $1, $2))
            }
        )

        try migrator.performMigration()

        let assetPages = fetchedPages.filter {
            $0.0 == "CDAsset"
        }
        XCTAssertEqual(assetPages.count, 2)
        XCTAssertTrue(
            assetPages.allSatisfy {
                $0.1 == 1 && $0.2 == 1
            }
        )
        let targetModel = try model(for: .version8)
        try inspectStore(
            at: storeURL,
            model: targetModel
        ) { context in
            let request = NSFetchRequest<NSManagedObject>(
                entityName: "CDAsset"
            )
            let assets = try context.fetch(request)
            XCTAssertEqual(assets.count, 2)
            for asset in assets {
                XCTAssertEqual(
                    try self.stringArray(
                        in: asset,
                        key: "purchaseProviders"
                    ),
                    []
                )
            }
        }
    }

    func testSyncMigration_whenFinalReplacementFails_thenSourceFamilyAndRelationshipsRemainExact() throws {
        let sourceModel = try model(for: .version3)
        try createStore(at: storeURL, model: sourceModel) { context in
            try self.insertTransformableAndProtectedGraph(
                in: context,
                model: sourceModel
            )
        }
        try executeSQLite(
            "UPDATE ZCDCHAIN SET ZOPTIONS = X'00FF00'",
            at: storeURL
        )
        let before = try durableStoreFamilySnapshot(at: storeURL)
        let migrator = makeMigrator(
            storeReplacer: { _, _ in
                throw InjectedSubstrateStoreReplacementError.failure
            }
        )

        XCTAssertThrowsError(try migrator.migrate()) { error in
            guard
                let migrationError = error as? SubstrateStorageMigrationError,
                case .storeReplacementFailed = migrationError
            else {
                return XCTFail("Expected storeReplacementFailed, got \(error)")
            }
        }

        XCTAssertEqual(try durableStoreFamilySnapshot(at: storeURL), before)
        XCTAssertTrue(try recoveryDirectories().isEmpty)
        try assertSourceProtectedGraphIsExact(
            at: storeURL,
            model: sourceModel
        )
    }

    func testPerformMigration_whenProcessDiesAfterRemovingLiveMainStore_thenRelaunchRestoresAndMigratesProtectedGraph() throws {
        let sourceModel = try model(for: .version3)
        try createStore(at: storeURL, model: sourceModel) { context in
            try self.insertTransformableAndProtectedGraph(
                in: context,
                model: sourceModel
            )
        }
        let interruptedMigrator = makeMigrator(
            storeReplacer: { targetURL, _ in
                try FileManager.default.removeItem(at: targetURL)
                throw CrashConsistentStoreReplacementInterruption
                    .simulatedProcessDeath
            }
        )

        XCTAssertThrowsError(
            try interruptedMigrator.performMigration()
        ) { error in
            guard
                let migrationError =
                error as? SubstrateStorageMigrationError,
                case let .storeReplacementFailed(_, underlyingError) =
                migrationError,
                underlyingError
                    is CrashConsistentStoreReplacementInterruption
            else {
                return XCTFail(
                    "Expected interrupted store replacement, got \(error)"
                )
            }
        }
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: storeURL.path),
            "The fixture must reproduce the missing-main startup state"
        )

        let relaunchedMigrator = makeMigrator()
        try relaunchedMigrator.performMigration()

        try assertMigratedTransformableAndProtectedGraph(
            expectedDefaultedKeys: []
        )
        XCTAssertFalse(relaunchedMigrator.requiresMigration())
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: testDirectory
                    .appendingPathComponent(
                        ".FearlessStoreReplacement",
                        isDirectory: true
                    ).path
            )
        )
    }

    func testPerformMigration_whenStagedProtectedValuesAndSelectedNodeAreSwappedWithoutRowLoss_thenRejectsStageAndPreservesSource() throws {
        let sourceModel = try model(for: .version3)
        try createStore(at: storeURL, model: sourceModel) { context in
            try self.insertTransformableAndProtectedGraph(
                in: context,
                model: sourceModel
            )
        }
        let before = try durableStoreFamilySnapshot(at: storeURL)
        let migrator = makeMigrator(
            stagedStoreMutationHook: { stagedURL, targetModel in
                try self.mutateStagedProtectedDataWithoutChangingRowCounts(
                    at: stagedURL,
                    model: targetModel
                )
            }
        )

        XCTAssertThrowsError(try migrator.performMigration()) { error in
            guard
                let migrationError = error as? SubstrateStorageMigrationError,
                case .stagedStoreProtectedDataMismatch = migrationError
            else {
                return XCTFail(
                    "Expected stagedStoreProtectedDataMismatch, got \(error)"
                )
            }
        }

        XCTAssertEqual(try durableStoreFamilySnapshot(at: storeURL), before)
        try assertSourceProtectedGraphIsExact(
            at: storeURL,
            model: sourceModel
        )
    }

    func testPerformMigration_whenProtectedEntityExceedsRowLimit_thenFailsClosedBeforeMigration() throws {
        let sourceModel = try model(for: .version7)
        try createStore(at: storeURL, model: sourceModel) {
            context in
            for index in 0 ..< 2 {
                let contact = try self.insert(
                    entityName: "CDContact",
                    in: context,
                    model: sourceModel
                )
                contact.setValue(
                    "contact-\(index)",
                    forKey: "address"
                )
            }
        }
        let before = try durableStoreFamilySnapshot(at: storeURL)
        let migrator = makeMigrator(
            protectedDataInspectionLimits:
            makeProtectedDataLimits(maximumRowsPerEntity: 1)
        )

        XCTAssertThrowsError(try migrator.performMigration()) { error in
            guard
                let migrationError =
                    error as? SubstrateStorageMigrationError,
                case let .sourceStoreInspectionFailed(
                    failedURL,
                    underlyingError
                ) = migrationError,
                let inspectionError =
                    underlyingError as?
                    SubstrateProtectedDataInspectionError,
                case let .entityRowLimitExceeded(
                    entityName,
                    actual,
                    maximum
                ) = inspectionError
            else {
                return XCTFail(
                    "Expected entityRowLimitExceeded, got \(error)"
                )
            }

            XCTAssertEqual(failedURL, self.storeURL)
            XCTAssertEqual(entityName, "CDContact")
            XCTAssertEqual(actual, 2)
            XCTAssertEqual(maximum, 1)
        }
        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: storeURL),
            before
        )
    }

    func testPerformMigration_whenProtectedEntitiesExceedTotalRowLimit_thenFailsClosedBeforePaging() throws {
        let sourceModel = try model(for: .version7)
        try createStore(at: storeURL, model: sourceModel) {
            context in
            _ = try self.insert(
                entityName: "CDContact",
                in: context,
                model: sourceModel
            )
            _ = try self.insert(
                entityName: "CDContactItem",
                in: context,
                model: sourceModel
            )
        }
        let before = try durableStoreFamilySnapshot(at: storeURL)
        let migrator = makeMigrator(
            protectedDataInspectionLimits:
            makeProtectedDataLimits(maximumTotalRows: 1)
        )

        XCTAssertThrowsError(try migrator.performMigration()) { error in
            guard
                let migrationError =
                    error as? SubstrateStorageMigrationError,
                case let .sourceStoreInspectionFailed(
                    _,
                    underlyingError
                ) = migrationError,
                let inspectionError =
                    underlyingError as?
                    SubstrateProtectedDataInspectionError,
                case let .totalRowLimitExceeded(
                    actual,
                    maximum
                ) = inspectionError
            else {
                return XCTFail(
                    "Expected totalRowLimitExceeded, got \(error)"
                )
            }

            XCTAssertEqual(actual, 2)
            XCTAssertEqual(maximum, 1)
        }
        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: storeURL),
            before
        )
    }

    func testPerformMigration_whenChainRelationshipExceedsMemberLimit_thenFailsClosedBeforeDigestingTopology() throws {
        let sourceModel = try model(for: .version7)
        try createStore(at: storeURL, model: sourceModel) {
            context in
            try self.insertLegacyChainWithNodes(
                in: context,
                model: sourceModel
            )
        }
        let before = try durableStoreFamilySnapshot(at: storeURL)
        var relationshipCountFaultStates =
            [(String, Bool, Int)]()
        var materializedRelationships =
            [(String, String, Int)]()
        let migrator = makeMigrator(
            protectedDataInspectionLimits:
            makeProtectedDataLimits(
                maximumRelationshipMembers: 1
            ),
            protectedRelationshipCountDidFetch: {
                relationshipCountFaultStates.append(
                    (
                        $1,
                        $0.hasFault(
                            forRelationshipNamed: $1
                        ),
                        $2
                    )
                )
            },
            protectedRelationshipWillMaterialize: {
                materializedRelationships.append(($0, $1, $2))
            }
        )

        XCTAssertThrowsError(try migrator.performMigration()) { error in
            guard
                let migrationError =
                    error as? SubstrateStorageMigrationError,
                case let .sourceStoreInspectionFailed(
                    _,
                    underlyingError
                ) = migrationError,
                let inspectionError =
                    underlyingError as?
                    SubstrateProtectedDataInspectionError,
                case let .relationshipLimitExceeded(
                    entityName,
                    relationshipName,
                    actual,
                    maximum
                ) = inspectionError
            else {
                return XCTFail(
                    "Expected relationshipLimitExceeded, got \(error)"
                )
            }

            XCTAssertEqual(entityName, "CDChain")
            XCTAssertEqual(relationshipName, "nodes")
            XCTAssertEqual(actual, 2)
            XCTAssertEqual(maximum, 1)
        }
        XCTAssertEqual(
            relationshipCountFaultStates.map { $0.0 },
            ["nodes"]
        )
        XCTAssertTrue(
            relationshipCountFaultStates.allSatisfy { $0.1 },
            "The SQL count must leave the inverse relationship faulted"
        )
        XCTAssertEqual(
            relationshipCountFaultStates.map { $0.2 },
            [2]
        )
        XCTAssertTrue(
            materializedRelationships.isEmpty,
            "An over-limit relationship must be rejected before member copying"
        )
        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: storeURL),
            before
        )
    }

    func testPerformMigration_whenNoInverseRelationshipExceedsMemberLimit_thenRejectsWhileRelationshipRemainsFaulted() throws {
        let sourceModel = try model(for: .version7)
        try createStore(at: storeURL, model: sourceModel) {
            context in
            let graph = try self.insertChainWithDefaultNode(
                in: context,
                model: sourceModel
            )
            for index in 0 ..< 2 {
                let customNode = try self.insert(
                    entityName: "CDChainNode",
                    in: context,
                    model: sourceModel
                )
                customNode.setValue(
                    "Custom \(index)",
                    forKey: "name"
                )
                customNode.setValue(
                    try XCTUnwrap(
                        URL(
                            string:
                            "wss://custom-\(index).example.invalid"
                        )
                    ),
                    forKey: "url"
                )
                graph.chain.mutableSetValue(
                    forKey: "customNodes"
                ).add(customNode)
            }
        }
        let before = try durableStoreFamilySnapshot(at: storeURL)
        var relationshipCountFaultStates =
            [(String, Bool, Int)]()
        var materializedRelationships =
            [(String, String, Int)]()
        let migrator = makeMigrator(
            protectedDataInspectionLimits:
            makeProtectedDataLimits(
                maximumRelationshipMembers: 1
            ),
            protectedRelationshipCountDidFetch: {
                relationshipCountFaultStates.append(
                    (
                        $1,
                        $0.hasFault(
                            forRelationshipNamed: $1
                        ),
                        $2
                    )
                )
            },
            protectedRelationshipWillMaterialize: {
                materializedRelationships.append(($0, $1, $2))
            }
        )

        XCTAssertThrowsError(try migrator.performMigration()) {
            error in
            guard
                let migrationError =
                    error as? SubstrateStorageMigrationError,
                case let .sourceStoreInspectionFailed(
                    _,
                    underlyingError
                ) = migrationError,
                let inspectionError =
                    underlyingError as?
                    SubstrateProtectedDataInspectionError,
                case let .relationshipLimitExceeded(
                    entityName,
                    relationshipName,
                    actual,
                    maximum
                ) = inspectionError
            else {
                return XCTFail(
                    "Expected no-inverse relationship limit, got \(error)"
                )
            }

            XCTAssertEqual(entityName, "CDChain")
            XCTAssertEqual(relationshipName, "customNodes")
            XCTAssertEqual(actual, 2)
            XCTAssertEqual(maximum, 1)
        }
        XCTAssertEqual(
            relationshipCountFaultStates.map { $0.0 },
            ["nodes", "customNodes"]
        )
        XCTAssertTrue(
            relationshipCountFaultStates.allSatisfy { $0.1 },
            "Both relationship counts must leave their faults intact"
        )
        XCTAssertEqual(
            relationshipCountFaultStates.map { $0.2 },
            [1, 2]
        )
        XCTAssertTrue(
            materializedRelationships.isEmpty,
            "Both counts must be accepted before either relationship fires"
        )
        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: storeURL),
            before
        )
    }

    func testPerformMigration_whenAggregateRelationshipLimitIsExceeded_thenRejectsBeforeEitherRelationshipMaterializes() throws {
        let sourceModel = try model(for: .version7)
        try createStore(at: storeURL, model: sourceModel) {
            context in
            let graph = try self.insertChainWithDefaultNode(
                in: context,
                model: sourceModel
            )
            let customNode = try self.insert(
                entityName: "CDChainNode",
                in: context,
                model: sourceModel
            )
            customNode.setValue("Custom", forKey: "name")
            customNode.setValue(
                try XCTUnwrap(
                    URL(string: "wss://custom.example.invalid")
                ),
                forKey: "url"
            )
            graph.chain.mutableSetValue(
                forKey: "customNodes"
            ).add(customNode)
        }
        let before = try durableStoreFamilySnapshot(at: storeURL)
        var materializedRelationships =
            [(String, String, Int)]()
        let migrator = makeMigrator(
            protectedDataInspectionLimits:
            makeProtectedDataLimits(
                maximumRelationshipMembers: 1,
                maximumTotalRelationshipMembers: 1
            ),
            protectedRelationshipWillMaterialize: {
                materializedRelationships.append(($0, $1, $2))
            }
        )

        XCTAssertThrowsError(try migrator.performMigration()) {
            error in
            guard
                let migrationError =
                    error as? SubstrateStorageMigrationError,
                case let .sourceStoreInspectionFailed(
                    _,
                    underlyingError
                ) = migrationError,
                let inspectionError =
                    underlyingError as?
                    SubstrateProtectedDataInspectionError,
                case let .totalRelationshipLimitExceeded(
                    actual,
                    maximum
                ) = inspectionError
            else {
                return XCTFail(
                    "Expected aggregate relationship limit, got \(error)"
                )
            }

            XCTAssertEqual(actual, 2)
            XCTAssertEqual(maximum, 1)
        }
        XCTAssertTrue(
            materializedRelationships.isEmpty,
            "Aggregate counts must pass before either relationship fires"
        )
        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: storeURL),
            before
        )
    }

    func testPerformMigration_whenProtectedValueExceedsByteLimit_thenFailsClosedWithoutReplacingStore() throws {
        let sourceModel = try model(for: .version7)
        try createStore(at: storeURL, model: sourceModel) {
            context in
            let contact = try self.insert(
                entityName: "CDContact",
                in: context,
                model: sourceModel
            )
            contact.setValue("too-long", forKey: "name")
        }
        let before = try durableStoreFamilySnapshot(at: storeURL)
        let migrator = makeMigrator(
            protectedDataInspectionLimits:
            makeProtectedDataLimits(maximumValueByteCount: 4)
        )

        XCTAssertThrowsError(try migrator.performMigration()) { error in
            guard
                let migrationError =
                    error as? SubstrateStorageMigrationError,
                case let .sourceStoreInspectionFailed(
                    _,
                    underlyingError
                ) = migrationError,
                let inspectionError =
                    underlyingError as?
                    SubstrateProtectedDataInspectionError,
                case let .valueByteLimitExceeded(
                    entityName,
                    attributeName,
                    actual,
                    maximum
                ) = inspectionError
            else {
                return XCTFail(
                    "Expected valueByteLimitExceeded, got \(error)"
                )
            }

            XCTAssertEqual(entityName, "CDContact")
            XCTAssertEqual(attributeName, "name")
            XCTAssertEqual(actual, 8)
            XCTAssertEqual(maximum, 4)
        }
        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: storeURL),
            before
        )
    }

    func testPerformMigration_whenBoundedRelationshipMemberExceedsByteLimit_thenFailsBeforeReplacement() throws {
        let sourceModel = try model(for: .version7)
        try createStore(at: storeURL, model: sourceModel) {
            context in
            let (_, node) = try self.insertChainWithDefaultNode(
                in: context,
                model: sourceModel
            )
            node.setValue("too-long", forKey: "name")
        }
        let before = try durableStoreFamilySnapshot(at: storeURL)
        var replacementAttempted = false
        var materializedRelationships =
            [(String, String, Int)]()
        let migrator = makeMigrator(
            storeReplacer: { _, _ in
                replacementAttempted = true
            },
            protectedDataInspectionLimits:
            makeProtectedDataLimits(maximumValueByteCount: 4),
            protectedRelationshipWillMaterialize: {
                materializedRelationships.append(($0, $1, $2))
            }
        )

        XCTAssertThrowsError(try migrator.performMigration()) { error in
            guard
                let migrationError =
                    error as? SubstrateStorageMigrationError,
                case let .sourceStoreInspectionFailed(
                    _,
                    underlyingError
                ) = migrationError,
                let inspectionError =
                    underlyingError as?
                    SubstrateProtectedDataInspectionError,
                case let .valueByteLimitExceeded(
                    entityName,
                    attributeName,
                    actual,
                    maximum
                ) = inspectionError
            else {
                return XCTFail(
                    "Expected relationship-member byte rejection, got \(error)"
                )
            }

            XCTAssertEqual(entityName, "CDChainNode")
            XCTAssertEqual(attributeName, "name")
            XCTAssertEqual(actual, 8)
            XCTAssertEqual(maximum, 4)
        }
        XCTAssertTrue(
            materializedRelationships.contains {
                $0.0 == "CDChain" &&
                    $0.1 == "nodes" &&
                    $0.2 == 1
            }
        )
        XCTAssertFalse(replacementAttempted)
        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: storeURL),
            before
        )
    }

    func testPerformMigration_whenProtectedRowsSpanSingleItemPages_thenDigestPreservesEveryRecord() throws {
        let sourceModel = try model(for: .version7)
        try createStore(at: storeURL, model: sourceModel) {
            context in
            for index in 0 ..< 3 {
                let contact = try self.insert(
                    entityName: "CDContact",
                    in: context,
                    model: sourceModel
                )
                contact.setValue(
                    "address-\(index)",
                    forKey: "address"
                )
                contact.setValue(
                    "name-\(index)",
                    forKey: "name"
                )
            }
        }
        let migrator = makeMigrator(
            protectedDataInspectionLimits:
            makeProtectedDataLimits(fetchPageSize: 1)
        )

        try migrator.performMigration()

        XCTAssertEqual(
            try count(
                entityName: "CDContact",
                at: storeURL,
                model: try model(for: .version8)
            ),
            3
        )
    }

    func testPerformMigration_whenLegacyAssetHasNoSymbolAndWrapperHasNoAsset_thenPreservesGraph() throws {
        let sourceModel = try model(for: .version3)
        try createStore(at: storeURL, model: sourceModel) { context in
            try self.insertLegacyChainGraph(
                in: context,
                model: sourceModel,
                symbol: nil,
                includeNilAssetWrapper: true
            )
        }

        try makeMigrator().performMigration()

        let targetModel = try model(for: .version8)
        XCTAssertEqual(
            try count(entityName: "CDAsset", at: storeURL, model: targetModel),
            1
        )

        try inspectStore(at: storeURL, model: targetModel) { context in
            let chain = try XCTUnwrap(
                try context.fetch(
                    NSFetchRequest<NSManagedObject>(entityName: "CDChain")
                ).first
            )
            let assets = try XCTUnwrap(
                chain.value(forKey: "assets") as? Set<NSManagedObject>
            )
            let asset = try XCTUnwrap(assets.first)

            XCTAssertEqual(assets.count, 1)
            XCTAssertEqual(asset.value(forKey: "id") as? String, "migration-asset")
            XCTAssertNil(asset.value(forKey: "symbol"))
        }
    }

    func testChainV4Policy_whenSourceAssetHasNoDestinationAssociation_thenMigrationFails() throws {
        let sourceModel = try model(for: .version3)
        let destinationModel = try model(for: .version4)
        try createStore(at: storeURL, model: sourceModel) { context in
            try self.insertLegacyChainGraph(in: context, model: sourceModel)
        }

        let mappingURL = try XCTUnwrap(
            appBundle.url(
                forResource: "SubstrateV3toV4",
                withExtension: "cdm"
            )
        )
        let mappingModel = try XCTUnwrap(NSMappingModel(contentsOf: mappingURL))
        let assetMapping = try XCTUnwrap(
            mappingModel.entityMappings.first {
                $0.sourceEntityName == "CDAsset" &&
                    $0.destinationEntityName == "CDAsset"
            }
        )
        assetMapping.entityMigrationPolicyClassName = NSStringFromClass(
            DroppingAssetMigrationPolicy.self
        )

        let manager = NSMigrationManager(
            sourceModel: sourceModel,
            destinationModel: destinationModel
        )
        let destinationURL = testDirectory.appendingPathComponent(
            "MissingAssetAssociation.sqlite"
        )

        XCTAssertThrowsError(
            try manager.migrateStore(
                from: storeURL,
                sourceType: NSSQLiteStoreType,
                options: nil,
                with: mappingModel,
                toDestinationURL: destinationURL,
                destinationType: NSSQLiteStoreType,
                destinationOptions: nil
            )
        ) { error in
            XCTAssertTrue(
                self.flattenedErrorDescriptions(error).contains {
                    $0.contains("Can't find migrated CDAsset destination instance")
                },
                "Expected the missing destination association error, got \(error)"
            )
        }
    }

    func testPerformMigration_whenVersion3ContainsOrphanAsset_thenPreservesItUnattached() throws {
        let sourceModel = try model(for: .version3)
        try createStore(at: storeURL, model: sourceModel) { context in
            try self.insertLegacyChainGraph(in: context, model: sourceModel)
            try self.insertLegacyOrphanAsset(in: context, model: sourceModel)
        }

        try makeMigrator().performMigration()

        let targetModel = try model(for: .version8)
        try inspectStore(at: storeURL, model: targetModel) { context in
            let assets = try context.fetch(
                NSFetchRequest<NSManagedObject>(entityName: "CDAsset")
            )
            let chain = try XCTUnwrap(
                try context.fetch(
                    NSFetchRequest<NSManagedObject>(entityName: "CDChain")
                ).first
            )
            let attachedAssets = try XCTUnwrap(
                chain.value(forKey: "assets") as? Set<NSManagedObject>
            )
            let orphanAsset = try XCTUnwrap(
                assets.first {
                    $0.value(forKey: "id") as? String == "orphan-asset"
                }
            )

            XCTAssertEqual(assets.count, 2)
            XCTAssertEqual(attachedAssets.count, 1)
            XCTAssertFalse(attachedAssets.contains(orphanAsset))
            XCTAssertNil(orphanAsset.value(forKey: "chain"))
            XCTAssertEqual(orphanAsset.value(forKey: "symbol") as? String, "ORP")
        }
    }

    func testPerformMigration_whenRequiredCustomMappingIsMissing_thenThrowsBeforeCheckpoint() throws {
        let sourceModel = try model(for: .version3)
        try createStore(at: storeURL, model: sourceModel) { context in
            try self.insertRuntimeItem(
                identifier: "required-mapping",
                in: context,
                model: sourceModel
            )
        }
        let before = try durableStoreFamilySnapshot(at: storeURL)
        let modelOnlyBundle = try makeModelBundle()
        let migrator = makeMigrator(modelBundle: modelOnlyBundle)

        XCTAssertThrowsError(try migrator.performMigration()) { error in
            guard
                let migrationError = error as? SubstrateStorageMigrationError,
                case let .mappingUnavailable(source, destination, _) = migrationError
            else {
                return XCTFail("Expected mappingUnavailable, got \(error)")
            }

            XCTAssertEqual(source, .version3)
            XCTAssertEqual(destination, .version4)
        }

        XCTAssertEqual(try durableStoreFamilySnapshot(at: storeURL), before)
    }

    func testBundledRequiredCustomMappings_matchCurrentModelsAndPolicies() throws {
        let cases: [
            (
                source: SubstrateStorageVersion,
                destination: SubstrateStorageVersion,
                resourceName: String,
                policyClassName: String
            )
        ] = [
            (
                .version1,
                .version2,
                "SubstrateV2Mapping",
                NSStringFromClass(ChainSubstrateV2MigrationPolicy.self)
            ),
            (
                .version3,
                .version4,
                "SubstrateV3toV4",
                NSStringFromClass(ChainModelV4MigrationPolicy.self)
            )
        ]

        for testCase in cases {
            let sourceModel = try model(for: testCase.source)
            let destinationModel = try model(for: testCase.destination)
            let mappingURL = try XCTUnwrap(
                appBundle.url(
                    forResource: testCase.resourceName,
                    withExtension: "cdm"
                )
            )
            let namedMapping = try XCTUnwrap(NSMappingModel(contentsOf: mappingURL))
            let selectedMapping = NSMappingModel(
                from: [appBundle],
                forSourceModel: sourceModel,
                destinationModel: destinationModel
            )

            XCTAssertNotNil(
                selectedMapping,
                "\(testCase.resourceName) is not compatible with its current models"
            )

            for entityMapping in namedMapping.entityMappings {
                if let sourceEntityName = entityMapping.sourceEntityName {
                    XCTAssertEqual(
                        entityMapping.sourceEntityVersionHash,
                        sourceModel.entitiesByName[sourceEntityName]?.versionHash,
                        "\(testCase.resourceName) has a stale \(sourceEntityName) source hash"
                    )
                }

                if let destinationEntityName = entityMapping.destinationEntityName {
                    XCTAssertEqual(
                        entityMapping.destinationEntityVersionHash,
                        destinationModel.entitiesByName[destinationEntityName]?.versionHash,
                        "\(testCase.resourceName) has a stale \(destinationEntityName) destination hash"
                    )
                }
            }

            let chainMapping = try XCTUnwrap(
                namedMapping.entityMappings.first {
                    $0.sourceEntityName == "CDChain" &&
                        $0.destinationEntityName == "CDChain"
                }
            )
            XCTAssertEqual(
                chainMapping.entityMigrationPolicyClassName,
                testCase.policyClassName
            )
        }
    }

    func testSyncMigration_whenKnownStoreHasZeroProtectedFootprint_thenQuarantinesOnlySubstrateFamily() throws {
        let sourceModel = try model(for: .version3)
        try createStore(at: storeURL, model: sourceModel) { context in
            try self.insertRuntimeItem(
                identifier: "rebuildable-runtime",
                in: context,
                model: sourceModel
            )
            _ = try self.insertChainWithDefaultNode(
                in: context,
                model: sourceModel
            )
        }
        let substrateBefore = try durableStoreFamilySnapshot(at: storeURL)

        let userStoreURL = testDirectory.appendingPathComponent("UserDataModel.sqlite")
        let userWALURL = URL(fileURLWithPath: userStoreURL.path + "-wal")
        let userSHMURL = URL(fileURLWithPath: userStoreURL.path + "-shm")
        let userJournalURL = URL(fileURLWithPath: userStoreURL.path + "-journal")
        let userStoreBytes = Data("wallet-store-must-not-move".utf8)
        let userWALBytes = Data("wallet-wal-must-not-move".utf8)
        let userSHMBytes = Data("wallet-shm-must-not-move".utf8)
        let userJournalBytes = Data("wallet-journal-must-not-move".utf8)
        try userStoreBytes.write(to: userStoreURL, options: .atomic)
        try userWALBytes.write(to: userWALURL, options: .atomic)
        try userSHMBytes.write(to: userSHMURL, options: .atomic)
        try userJournalBytes.write(to: userJournalURL, options: .atomic)

        let modelOnlyBundle = try makeModelBundle()
        let migrator = makeMigrator(modelBundle: modelOnlyBundle)

        XCTAssertThrowsError(try migrator.performMigration()) { error in
            guard
                let migrationError = error as? SubstrateStorageMigrationError,
                case let .mappingUnavailable(source, destination, _) = migrationError
            else {
                return XCTFail("Expected mappingUnavailable, got \(error)")
            }

            XCTAssertEqual(source, .version3)
            XCTAssertEqual(destination, .version4)
        }

        try migrator.migrate()

        XCTAssertFalse(FileManager.default.fileExists(atPath: storeURL.path))
        XCTAssertFalse(migrator.requiresMigration())
        XCTAssertEqual(try Data(contentsOf: userStoreURL), userStoreBytes)
        XCTAssertEqual(try Data(contentsOf: userWALURL), userWALBytes)
        XCTAssertEqual(try Data(contentsOf: userSHMURL), userSHMBytes)
        XCTAssertEqual(try Data(contentsOf: userJournalURL), userJournalBytes)

        let recoveryDirectory = try XCTUnwrap(try recoveryDirectories().first)
        let recoveredStoreURL = recoveryDirectory.appendingPathComponent(
            storeURL.lastPathComponent
        )
        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: recoveredStoreURL),
            substrateBefore
        )

        try migrator.migrate()
        XCTAssertEqual(try recoveryDirectories(), [recoveryDirectory])
        XCTAssertEqual(try Data(contentsOf: userStoreURL), userStoreBytes)
        XCTAssertEqual(try Data(contentsOf: userWALURL), userWALBytes)
        XCTAssertEqual(try Data(contentsOf: userSHMURL), userSHMBytes)
        XCTAssertEqual(try Data(contentsOf: userJournalURL), userJournalBytes)
    }

    func testSyncMigration_whenCheckpointFailsWithZeroProtectedData_thenQuarantinesExactSourceFamily() throws {
        let sourceModel = try model(for: .version3)
        try createStore(at: storeURL, model: sourceModel) { context in
            try self.insertRuntimeItem(
                identifier: "checkpoint-rebuildable-runtime",
                in: context,
                model: sourceModel
            )
        }
        let before = try durableStoreFamilySnapshot(at: storeURL)
        let migrator = makeMigrator(
            checkpointStoreHook: { _, _ in
                throw InjectedSubstrateCheckpointError.failure
            }
        )

        try migrator.migrate()

        XCTAssertFalse(FileManager.default.fileExists(atPath: storeURL.path))
        let recoveryDirectory = try XCTUnwrap(try recoveryDirectories().first)
        let recoveredStoreURL = recoveryDirectory.appendingPathComponent(
            storeURL.lastPathComponent
        )
        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: recoveredStoreURL),
            before
        )
    }

    func testSyncMigration_whenCheckpointFailsWithProtectedData_thenBlocksRecoveryAndPreservesSource() throws {
        let sourceModel = try model(for: .version3)
        try createStore(at: storeURL, model: sourceModel) { context in
            let contact = try self.insert(
                entityName: "CDContact",
                in: context,
                model: sourceModel
            )
            contact.setValue("Checkpoint User", forKey: "name")
            contact.setValue("5CheckpointProtected", forKey: "address")
            contact.setValue("checkpoint-chain", forKey: "chainId")
        }
        let before = try durableStoreFamilySnapshot(at: storeURL)
        var checkpointCount = 0
        let migrator = makeMigrator(
            checkpointStoreHook: { _, _ in
                checkpointCount += 1
                throw InjectedSubstrateCheckpointError.failure
            }
        )

        XCTAssertThrowsError(try migrator.migrate()) { error in
            guard
                let migrationError = error as? SubstrateStorageMigrationError,
                case let .cacheRecoveryBlockedByProtectedData(
                    blockedURL,
                    originalError,
                    counts
                ) = migrationError
            else {
                return XCTFail("Expected cacheRecoveryBlockedByProtectedData, got \(error)")
            }

            XCTAssertEqual(blockedURL, self.storeURL)
            XCTAssertEqual(
                counts.filter { $0.value > 0 },
                ["CDContact": 1]
            )
            guard
                let originalMigrationError =
                    originalError as? SubstrateStorageMigrationError,
                case .walCheckpointFailed = originalMigrationError
            else {
                return XCTFail("Expected walCheckpointFailed, got \(originalError)")
            }
        }

        XCTAssertEqual(checkpointCount, 1)
        XCTAssertEqual(try durableStoreFamilySnapshot(at: storeURL), before)
        XCTAssertTrue(try recoveryDirectories().isEmpty)
    }

    func testSyncMigration_whenCheckpointFails_thenFinalRecoveryInspectionNeverCheckpointsAgain() throws {
        let sourceModel = try model(for: .version7)
        try createStore(at: storeURL, model: sourceModel) { context in
            try self.insertRuntimeItem(
                identifier: "single-checkpoint-runtime",
                in: context,
                model: sourceModel
            )
        }
        var checkpointCount = 0
        let migrator = makeMigrator(
            checkpointStoreHook: { _, _ in
                checkpointCount += 1
                throw InjectedSubstrateCheckpointError.failure
            }
        )

        try migrator.migrate()

        XCTAssertEqual(
            checkpointCount,
            1,
            "The final protected-data inspection must not re-enter checkpointing"
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: storeURL.path))
        XCTAssertEqual(try recoveryDirectories().count, 1)
    }

    func testCacheRecoveryTransaction_whenInterruptedAtEveryDurableBoundary_thenRelaunchConvergesExactly() throws {
        let boundaries: [SubstrateCacheRecoveryBoundary] = [
            .markerPersisted,
            .familyMemberMoved(""),
            .familyMemberMoved("-wal"),
            .familyMemberMoved("-shm"),
            .familyMemberMoved("-journal"),
            .markerRemoved
        ]

        for (index, boundary) in boundaries.enumerated() {
            let caseDirectory = testDirectory.appendingPathComponent(
                "interruption-\(index)",
                isDirectory: true
            )
            try FileManager.default.createDirectory(
                at: caseDirectory,
                withIntermediateDirectories: false
            )
            let caseStoreURL = caseDirectory.appendingPathComponent(
                storeURL.lastPathComponent
            )
            let expectedFamily = try writeSyntheticStoreFamily(
                at: caseStoreURL,
                discriminator: UInt8(index)
            )
            var interruptionWasInjected = false
            let interruptedTransaction =
                CrashConsistentSubstrateCacheRecovery(
                    storeURL: caseStoreURL,
                    fileManager: .default,
                    boundaryHook: { reachedBoundary in
                        guard
                            reachedBoundary == boundary,
                            !interruptionWasInjected
                        else {
                            return
                        }

                        interruptionWasInjected = true
                        throw SubstrateCacheRecoveryInterruption
                            .simulatedProcessDeath
                    }
                )

            XCTAssertThrowsError(
                try interruptedTransaction.quarantine(),
                "Expected simulated process death at \(boundary)"
            ) { error in
                guard error is SubstrateCacheRecoveryInterruption else {
                    return XCTFail(
                        "Expected cache-recovery interruption, got \(error)"
                    )
                }
            }
            XCTAssertTrue(interruptionWasInjected)

            let relaunchedTransaction =
                CrashConsistentSubstrateCacheRecovery(
                    storeURL: caseStoreURL,
                    fileManager: .default
                )
            _ = try relaunchedTransaction.reconcile()

            XCTAssertTrue(
                try durableStoreFamilySnapshot(
                    at: caseStoreURL
                ).isEmpty,
                "Live family survived relaunch after \(boundary)"
            )
            let recoveryDirectories = try contents(
                of: relaunchedTransaction.recoveryRootURL
            )
            let recoveryDirectory = try XCTUnwrap(
                recoveryDirectories.first
            )
            XCTAssertEqual(recoveryDirectories.count, 1)
            XCTAssertEqual(
                try durableStoreFamilySnapshot(
                    at: recoveryDirectory.appendingPathComponent(
                        caseStoreURL.lastPathComponent
                    )
                ),
                expectedFamily,
                "Quarantine changed bytes after \(boundary)"
            )
            XCTAssertFalse(
                FileManager.default.fileExists(
                    atPath: recoveryDirectory
                        .appendingPathComponent(
                            "recovery-transaction"
                        ).path
                )
            )

            XCTAssertNil(try relaunchedTransaction.reconcile())
            XCTAssertEqual(
                try contents(
                    of: relaunchedTransaction.recoveryRootURL
                ),
                recoveryDirectories
            )
        }
    }

    func testCacheRecoveryTransaction_whenPreparationIsMarkerlessOrOnlyPending_thenRelaunchCleansItWithoutMovingLiveFamily() throws {
        for containsPendingMarker in [false, true] {
            let caseDirectory = testDirectory.appendingPathComponent(
                containsPendingMarker ? "pending-marker" : "empty-marker",
                isDirectory: true
            )
            try FileManager.default.createDirectory(
                at: caseDirectory,
                withIntermediateDirectories: false
            )
            let caseStoreURL = caseDirectory.appendingPathComponent(
                storeURL.lastPathComponent
            )
            let expectedFamily = try writeSyntheticStoreFamily(
                at: caseStoreURL,
                discriminator: containsPendingMarker ? 0xB1 : 0xB0
            )
            let transaction = CrashConsistentSubstrateCacheRecovery(
                storeURL: caseStoreURL,
                fileManager: .default
            )
            let preparationURL = transaction.recoveryRootURL
                .appendingPathComponent(
                    UUID().uuidString,
                    isDirectory: true
                )
            try FileManager.default.createDirectory(
                at: preparationURL,
                withIntermediateDirectories: true
            )
            if containsPendingMarker {
                try Data("partial marker".utf8).write(
                    to: preparationURL.appendingPathComponent(
                        "recovery-transaction.pending"
                    )
                )
            }

            XCTAssertNil(try transaction.reconcile())
            XCTAssertEqual(
                try durableStoreFamilySnapshot(at: caseStoreURL),
                expectedFamily
            )
            XCTAssertFalse(
                FileManager.default.fileExists(
                    atPath: transaction.recoveryRootURL.path
                )
            )
        }
    }

    func testPerformMigrationWithRecovery_whenCacheQuarantineLostMainStore_thenReconcilesBeforeLiveStoreSafetyCheck() throws {
        let sourceModel = try model(for: .version3)
        try createStore(at: storeURL, model: sourceModel) { context in
            try self.insertRuntimeItem(
                identifier: "interrupted-recovery-runtime",
                in: context,
                model: sourceModel
            )
        }
        try Data("recovery-wal".utf8).write(
            to: URL(fileURLWithPath: storeURL.path + "-wal")
        )
        try Data("recovery-shm".utf8).write(
            to: URL(fileURLWithPath: storeURL.path + "-shm")
        )
        let before = try durableStoreFamilySnapshot(at: storeURL)
        let interruptedTransaction =
            CrashConsistentSubstrateCacheRecovery(
                storeURL: storeURL,
                fileManager: .default,
                boundaryHook: { boundary in
                    guard boundary == .familyMemberMoved("") else {
                        return
                    }
                    throw SubstrateCacheRecoveryInterruption
                        .simulatedProcessDeath
                }
            )

        XCTAssertThrowsError(
            try interruptedTransaction.quarantine()
        )
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: storeURL.path)
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: storeURL.path + "-wal"
            )
        )

        let migrator = makeMigrator()
        XCTAssertNil(try migrator.performMigrationWithRecovery())
        XCTAssertTrue(
            try durableStoreFamilySnapshot(at: storeURL).isEmpty
        )
        let recoveryDirectory = try XCTUnwrap(
            try recoveryDirectories().first
        )
        XCTAssertEqual(
            try durableStoreFamilySnapshot(
                at: recoveryDirectory.appendingPathComponent(
                    storeURL.lastPathComponent
                )
            ),
            before
        )
    }

    func testPerformMigration_whenDeployedLegacyRecoveryMovedRealSQLiteMain_thenRestoresBeforeStoreSafetyAndPreservesRowsAndWAL() throws {
        let currentModel = try model(for: .version8)
        try createStore(at: storeURL, model: currentModel) {
            context in
            try self.insertRuntimeItem(
                identifier: "legacy-real-sqlite-runtime",
                in: context,
                model: currentModel
            )
        }
        try installRealSQLiteFamilyWithUncheckpointedWAL(
            at: storeURL
        )
        let before = try durableStoreFamilySnapshot(at: storeURL)
        XCTAssertNotNil(before[storeURL.lastPathComponent + "-wal"])
        XCTAssertNotNil(before[storeURL.lastPathComponent + "-shm"])

        let recoveryRootURL = testDirectory.appendingPathComponent(
            "SubstrateStoreRecovery",
            isDirectory: true
        )
        let legacyArchiveURL = recoveryRootURL.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: legacyArchiveURL,
            withIntermediateDirectories: true
        )
        try FileManager.default.moveItem(
            at: storeURL,
            to: legacyArchiveURL.appendingPathComponent(
                storeURL.lastPathComponent
            )
        )
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: storeURL.path)
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: storeURL.path + "-wal"
            )
        )

        try makeMigrator().performMigration()

        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: storeURL),
            before
        )
        XCTAssertEqual(
            try Data(
                contentsOf: legacyArchiveURL.appendingPathComponent(
                    storeURL.lastPathComponent
                )
            ),
            before[storeURL.lastPathComponent]
        )
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: legacyArchiveURL.appendingPathComponent(
                    "recovery-transaction"
                ).path
            )
        )
        XCTAssertEqual(
            try count(
                entityName: "CDRuntimeMetadataItem",
                at: storeURL,
                model: currentModel
            ),
            1
        )
        XCTAssertEqual(
            try sqliteInteger(
                "SELECT COUNT(*) FROM ZFEARLESSRECOVERYPROBE",
                at: storeURL
            ),
            1
        )
    }

    func testCacheRecoveryTransaction_whenActiveTreeContainsUnknownFile_thenFailsClosedWithoutMovingFamily() throws {
        let expectedFamily = try writeSyntheticStoreFamily(
            at: storeURL,
            discriminator: 0xC1
        )
        let transactionDirectory = try interruptCacheRecovery(
            at: .markerPersisted
        )
        let unexpectedURL = transactionDirectory
            .appendingPathComponent("unexpected")
        let unexpectedData = Data("must remain".utf8)
        try unexpectedData.write(to: unexpectedURL)

        let relaunchedTransaction =
            CrashConsistentSubstrateCacheRecovery(
                storeURL: storeURL,
                fileManager: .default
            )
        XCTAssertThrowsError(try relaunchedTransaction.reconcile()) {
            error in
            guard
                let transactionError =
                    error as? SubstrateCacheRecoveryTransactionError,
                case .unsafeDirectory = transactionError
            else {
                return XCTFail("Expected unsafeDirectory, got \(error)")
            }
        }

        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: storeURL),
            expectedFamily
        )
        XCTAssertEqual(try Data(contentsOf: unexpectedURL), unexpectedData)
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: transactionDirectory
                    .appendingPathComponent(
                        "recovery-transaction"
                    ).path
            )
        )
    }

    func testCacheRecoveryTransaction_whenLiveFamilyChangesAfterMarker_thenFailsClosedWithoutMovingAnything() throws {
        _ = try writeSyntheticStoreFamily(
            at: storeURL,
            discriminator: 0xC2
        )
        let transactionDirectory = try interruptCacheRecovery(
            at: .markerPersisted
        )
        let changedData = Data("externally changed main store".utf8)
        try changedData.write(to: storeURL)

        let relaunchedTransaction =
            CrashConsistentSubstrateCacheRecovery(
                storeURL: storeURL,
                fileManager: .default
            )
        XCTAssertThrowsError(try relaunchedTransaction.reconcile()) {
            error in
            guard
                let transactionError =
                    error as? SubstrateCacheRecoveryTransactionError,
                case .familyMismatch = transactionError
            else {
                return XCTFail("Expected familyMismatch, got \(error)")
            }
        }

        XCTAssertEqual(try Data(contentsOf: storeURL), changedData)
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: storeURL.path + "-wal"
            )
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: transactionDirectory
                    .appendingPathComponent(
                        "recovery-transaction"
                    ).path
            )
        )
    }

    func testCacheRecoveryTransaction_whenMovedMemberChanges_thenFailsClosedAndKeepsDurableMarker() throws {
        _ = try writeSyntheticStoreFamily(
            at: storeURL,
            discriminator: 0xC3
        )
        let transactionDirectory = try interruptCacheRecovery(
            at: .familyMemberMoved("")
        )
        let quarantinedStoreURL = transactionDirectory
            .appendingPathComponent(storeURL.lastPathComponent)
        let changedData = Data("changed quarantine member".utf8)
        try changedData.write(to: quarantinedStoreURL)

        let relaunchedTransaction =
            CrashConsistentSubstrateCacheRecovery(
                storeURL: storeURL,
                fileManager: .default
            )
        XCTAssertThrowsError(try relaunchedTransaction.reconcile()) {
            error in
            guard
                let transactionError =
                    error as? SubstrateCacheRecoveryTransactionError,
                case .familyMismatch = transactionError
            else {
                return XCTFail("Expected familyMismatch, got \(error)")
            }
        }

        XCTAssertEqual(
            try Data(contentsOf: quarantinedStoreURL),
            changedData
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: storeURL.path + "-wal"
            )
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: transactionDirectory
                    .appendingPathComponent(
                        "recovery-transaction"
                    ).path
            )
        )
    }

    func testCacheRecoveryTransaction_whenSourceContainsSymlinkOrHardlink_thenRejectsBeforeCreatingMarker() throws {
        let outsideURL = testDirectory.appendingPathComponent("outside")
        let outsideData = Data("outside-must-remain".utf8)
        try outsideData.write(to: outsideURL)

        let symlinkDirectory = testDirectory.appendingPathComponent(
            "symlink-family",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: symlinkDirectory,
            withIntermediateDirectories: false
        )
        let symlinkStoreURL = symlinkDirectory.appendingPathComponent(
            storeURL.lastPathComponent
        )
        try Data("main".utf8).write(to: symlinkStoreURL)
        try FileManager.default.createSymbolicLink(
            atPath: symlinkStoreURL.path + "-wal",
            withDestinationPath: outsideURL.path
        )

        let symlinkTransaction =
            CrashConsistentSubstrateCacheRecovery(
                storeURL: symlinkStoreURL,
                fileManager: .default
            )
        XCTAssertThrowsError(try symlinkTransaction.quarantine()) {
            error in
            guard
                let transactionError =
                    error as? SubstrateCacheRecoveryTransactionError,
                case .unsafeFile = transactionError
            else {
                return XCTFail("Expected unsafeFile, got \(error)")
            }
        }
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: symlinkTransaction.recoveryRootURL.path
            )
        )

        let hardlinkDirectory = testDirectory.appendingPathComponent(
            "hardlink-family",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: hardlinkDirectory,
            withIntermediateDirectories: false
        )
        let hardlinkStoreURL = hardlinkDirectory.appendingPathComponent(
            storeURL.lastPathComponent
        )
        try Data("hardlinked".utf8).write(to: hardlinkStoreURL)
        try FileManager.default.linkItem(
            at: hardlinkStoreURL,
            to: URL(fileURLWithPath: hardlinkStoreURL.path + "-wal")
        )

        let hardlinkTransaction =
            CrashConsistentSubstrateCacheRecovery(
                storeURL: hardlinkStoreURL,
                fileManager: .default
            )
        XCTAssertThrowsError(try hardlinkTransaction.quarantine()) {
            error in
            guard
                let transactionError =
                    error as? SubstrateCacheRecoveryTransactionError,
                case .unsafeFile = transactionError
            else {
                return XCTFail("Expected unsafeFile, got \(error)")
            }
        }
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: hardlinkTransaction.recoveryRootURL.path
            )
        )
        XCTAssertEqual(try Data(contentsOf: outsideURL), outsideData)
    }

    func testCacheRecoveryTransaction_whenMarkerIsNoncanonicalOrOversized_thenFailsClosedAndPreservesLiveFamily() throws {
        for markerMutation in ["noncanonical", "oversized"] {
            let caseDirectory = testDirectory.appendingPathComponent(
                markerMutation,
                isDirectory: true
            )
            try FileManager.default.createDirectory(
                at: caseDirectory,
                withIntermediateDirectories: false
            )
            let caseStoreURL = caseDirectory.appendingPathComponent(
                storeURL.lastPathComponent
            )
            let expectedFamily = try writeSyntheticStoreFamily(
                at: caseStoreURL,
                discriminator:
                markerMutation == "noncanonical" ? 0xD1 : 0xD2
            )
            let transactionDirectory = try interruptCacheRecovery(
                storeURL: caseStoreURL,
                at: .markerPersisted
            )
            let markerURL = transactionDirectory.appendingPathComponent(
                "recovery-transaction"
            )
            if markerMutation == "noncanonical" {
                var marker = try Data(contentsOf: markerURL)
                marker.append(Data("\n".utf8))
                try marker.write(to: markerURL)
            } else {
                try Data(repeating: 0x41, count: 4 * 1024 + 1)
                    .write(to: markerURL)
            }

            let relaunchedTransaction =
                CrashConsistentSubstrateCacheRecovery(
                    storeURL: caseStoreURL,
                    fileManager: .default
                )
            XCTAssertThrowsError(
                try relaunchedTransaction.reconcile()
            ) { error in
                guard
                    let transactionError =
                        error as?
                        SubstrateCacheRecoveryTransactionError
                else {
                    return XCTFail(
                        "Expected recovery transaction error, got \(error)"
                    )
                }

                if markerMutation == "noncanonical" {
                    guard case .invalidMarker = transactionError else {
                        return XCTFail(
                            "Expected invalidMarker, got \(error)"
                        )
                    }
                } else {
                    guard case .markerTooLarge = transactionError else {
                        return XCTFail(
                            "Expected markerTooLarge, got \(error)"
                        )
                    }
                }
            }
            XCTAssertEqual(
                try durableStoreFamilySnapshot(at: caseStoreURL),
                expectedFamily
            )
        }
    }

    func testCacheRecoveryTransaction_whenLegacyMarkerlessMoveStoppedAtEveryBoundary_thenAdoptsDurablyAndConverges() throws {
        let suffixes = ["", "-wal", "-shm", "-journal"]

        for movedMemberCount in 1 ... suffixes.count {
            let caseDirectory = testDirectory.appendingPathComponent(
                "legacy-boundary-\(movedMemberCount)",
                isDirectory: true
            )
            try FileManager.default.createDirectory(
                at: caseDirectory,
                withIntermediateDirectories: false
            )
            let caseStoreURL = caseDirectory.appendingPathComponent(
                storeURL.lastPathComponent
            )
            let expectedFamily = try writeSyntheticStoreFamily(
                at: caseStoreURL,
                discriminator: UInt8(0xE0 + movedMemberCount)
            )
            let transaction = CrashConsistentSubstrateCacheRecovery(
                storeURL: caseStoreURL,
                fileManager: .default
            )
            let legacyArchiveURL = transaction.recoveryRootURL
                .appendingPathComponent(
                    UUID().uuidString,
                    isDirectory: true
                )
            try FileManager.default.createDirectory(
                at: legacyArchiveURL,
                withIntermediateDirectories: true
            )

            for suffix in suffixes.prefix(movedMemberCount) {
                let sourceURL = URL(
                    fileURLWithPath: caseStoreURL.path + suffix
                )
                try FileManager.default.moveItem(
                    at: sourceURL,
                    to: legacyArchiveURL.appendingPathComponent(
                        sourceURL.lastPathComponent
                    )
                )
            }

            _ = try transaction.reconcile()

            let archivedStoreURL = legacyArchiveURL
                .appendingPathComponent(
                    caseStoreURL.lastPathComponent
                )
            if movedMemberCount == suffixes.count {
                XCTAssertTrue(
                    try durableStoreFamilySnapshot(
                        at: caseStoreURL
                    ).isEmpty
                )
                XCTAssertEqual(
                    try durableStoreFamilySnapshot(
                        at: archivedStoreURL
                    ),
                    expectedFamily
                )
            } else {
                XCTAssertEqual(
                    try durableStoreFamilySnapshot(
                        at: caseStoreURL
                    ),
                    expectedFamily,
                    "Legacy split \(movedMemberCount) was not restored"
                )
                XCTAssertEqual(
                    Set(
                        try durableStoreFamilySnapshot(
                            at: archivedStoreURL
                        ).keys
                    ),
                    Set(
                        suffixes.prefix(movedMemberCount).map {
                            caseStoreURL.lastPathComponent + $0
                        }
                    )
                )
            }
            XCTAssertFalse(
                FileManager.default.fileExists(
                    atPath: legacyArchiveURL
                        .appendingPathComponent(
                            "recovery-transaction"
                        ).path
                )
            )
            XCTAssertNil(try transaction.reconcile())
        }
    }

    func testCacheRecoveryTransaction_whenLegacyAdoptionMarkerWriteWasInterrupted_thenRemovesOnlyPendingMarkerAndConverges() throws {
        let expectedFamily = try writeSyntheticStoreFamily(
            at: storeURL,
            discriminator: 0xE9
        )
        let transaction = CrashConsistentSubstrateCacheRecovery(
            storeURL: storeURL,
            fileManager: .default
        )
        let legacyArchiveURL = transaction.recoveryRootURL
            .appendingPathComponent(
                UUID().uuidString,
                isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: legacyArchiveURL,
            withIntermediateDirectories: true
        )
        let mainSourceURL = storeURL
        try FileManager.default.moveItem(
            at: mainSourceURL,
            to: legacyArchiveURL.appendingPathComponent(
                mainSourceURL.lastPathComponent
            )
        )
        try Data("partial durable adoption marker".utf8).write(
            to: legacyArchiveURL.appendingPathComponent(
                "recovery-transaction.pending"
            )
        )

        _ = try transaction.reconcile()

        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: storeURL),
            expectedFamily
        )
        XCTAssertEqual(
            Set(
                try durableStoreFamilySnapshot(
                    at: legacyArchiveURL.appendingPathComponent(
                        storeURL.lastPathComponent
                    )
                ).keys
            ),
            [storeURL.lastPathComponent]
        )
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: legacyArchiveURL
                    .appendingPathComponent(
                        "recovery-transaction.pending"
                    ).path
            )
        )
    }

    func testCacheRecoveryTransaction_whenLegacyRestorationIsInterruptedAtEveryDurableBoundary_thenRelaunchConverges() throws {
        let boundaries: [SubstrateCacheRecoveryBoundary] = [
            .markerPersisted,
            .legacyFamilyMemberRestored(""),
            .legacyFamilyMemberRestored("-wal"),
            .markerRemoved
        ]

        for (index, boundary) in boundaries.enumerated() {
            let caseDirectory = testDirectory.appendingPathComponent(
                "legacy-restore-interruption-\(index)",
                isDirectory: true
            )
            try FileManager.default.createDirectory(
                at: caseDirectory,
                withIntermediateDirectories: false
            )
            let caseStoreURL = caseDirectory.appendingPathComponent(
                storeURL.lastPathComponent
            )
            let expectedFamily = try writeSyntheticStoreFamily(
                at: caseStoreURL,
                discriminator: UInt8(0xF0 + index)
            )
            let recoveryRootURL = caseDirectory.appendingPathComponent(
                "SubstrateStoreRecovery",
                isDirectory: true
            )
            let archiveURL = recoveryRootURL.appendingPathComponent(
                UUID().uuidString,
                isDirectory: true
            )
            try FileManager.default.createDirectory(
                at: archiveURL,
                withIntermediateDirectories: true
            )
            for suffix in ["", "-wal"] {
                let sourceURL = URL(
                    fileURLWithPath: caseStoreURL.path + suffix
                )
                try FileManager.default.moveItem(
                    at: sourceURL,
                    to: archiveURL.appendingPathComponent(
                        sourceURL.lastPathComponent
                    )
                )
            }

            var interruptionWasInjected = false
            let interruptedTransaction =
                CrashConsistentSubstrateCacheRecovery(
                    storeURL: caseStoreURL,
                    fileManager: .default,
                    boundaryHook: { reachedBoundary in
                        guard
                            reachedBoundary == boundary,
                            !interruptionWasInjected
                        else {
                            return
                        }
                        interruptionWasInjected = true
                        throw SubstrateCacheRecoveryInterruption
                            .simulatedProcessDeath
                    }
                )
            XCTAssertThrowsError(
                try interruptedTransaction.reconcile()
            ) { error in
                guard error is SubstrateCacheRecoveryInterruption else {
                    return XCTFail(
                        "Expected cache-recovery interruption, got \(error)"
                    )
                }
            }
            XCTAssertTrue(interruptionWasInjected)

            let relaunchedTransaction =
                CrashConsistentSubstrateCacheRecovery(
                    storeURL: caseStoreURL,
                    fileManager: .default
                )
            _ = try relaunchedTransaction.reconcile()
            XCTAssertEqual(
                try durableStoreFamilySnapshot(at: caseStoreURL),
                expectedFamily,
                "Legacy restoration changed bytes after \(boundary)"
            )
            XCTAssertEqual(
                Set(
                    try durableStoreFamilySnapshot(
                        at: archiveURL.appendingPathComponent(
                            caseStoreURL.lastPathComponent
                        )
                    ).keys
                ),
                [
                    caseStoreURL.lastPathComponent,
                    caseStoreURL.lastPathComponent + "-wal"
                ]
            )
            XCTAssertFalse(
                FileManager.default.fileExists(
                    atPath: archiveURL.appendingPathComponent(
                        "recovery-transaction"
                    ).path
                )
            )
            XCTAssertNil(try relaunchedTransaction.reconcile())
        }
    }

    func testCacheRecoveryTransaction_whenLegacyTemporaryFileSynchronizationFails_thenRelaunchResynchronizesBeforeInstall() throws {
        let expectedFamily = try writeSyntheticStoreFamily(
            at: storeURL,
            discriminator: 0xF8
        )
        let recoveryRootURL = testDirectory.appendingPathComponent(
            "SubstrateStoreRecovery",
            isDirectory: true
        )
        let archiveURL = recoveryRootURL.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: archiveURL,
            withIntermediateDirectories: true
        )
        try FileManager.default.moveItem(
            at: storeURL,
            to: archiveURL.appendingPathComponent(
                storeURL.lastPathComponent
            )
        )
        var synchronizationFailureWasInjected = false
        let interruptedTransaction =
            CrashConsistentSubstrateCacheRecovery(
                storeURL: storeURL,
                fileManager: .default,
                restorationTemporaryFileSynchronizationHook: {
                    _ in
                    guard !synchronizationFailureWasInjected else {
                        return
                    }
                    synchronizationFailureWasInjected = true
                    throw CocoaError(.fileWriteUnknown)
                }
            )

        XCTAssertThrowsError(
            try interruptedTransaction.reconcile()
        )
        XCTAssertTrue(synchronizationFailureWasInjected)
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: storeURL.path)
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: archiveURL.appendingPathComponent(
                    "main.cache-recovery-restore.pending"
                ).path
            )
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: archiveURL.appendingPathComponent(
                    "recovery-transaction"
                ).path
            )
        )

        let relaunchedTransaction =
            CrashConsistentSubstrateCacheRecovery(
                storeURL: storeURL,
                fileManager: .default
            )
        _ = try relaunchedTransaction.reconcile()
        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: storeURL),
            expectedFamily
        )
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: archiveURL.appendingPathComponent(
                    "main.cache-recovery-restore.pending"
                ).path
            )
        )
    }

    func testCacheRecoveryTransaction_whenFinalQuarantineDirectorySynchronizationFails_thenRetryResynchronizesBothDirectoriesBeforeCommit() throws {
        let expectedFamily = try writeSyntheticStoreFamily(
            at: storeURL,
            discriminator: 0xF9
        )
        let suffixes = ["", "-wal", "-shm", "-journal"]
        let databaseDirectoryURL = storeURL.deletingLastPathComponent()
            .standardizedFileURL
        var synchronizationFailureWasInjected = false
        var failedTransactionDirectoryURL: URL?
        let interruptedTransaction =
            CrashConsistentSubstrateCacheRecovery(
                storeURL: storeURL,
                fileManager: .default,
                directorySynchronizationHook: { directoryURL in
                    guard
                        !synchronizationFailureWasInjected,
                        suffixes.allSatisfy({ suffix in
                            let liveURL = URL(
                                fileURLWithPath: self.storeURL.path + suffix
                            )
                            let archivedURL = directoryURL
                                .appendingPathComponent(
                                    self.storeURL.lastPathComponent + suffix
                                )
                            return !FileManager.default.fileExists(
                                atPath: liveURL.path
                            ) && FileManager.default.fileExists(
                                atPath: archivedURL.path
                            )
                        })
                    else {
                        return
                    }

                    synchronizationFailureWasInjected = true
                    failedTransactionDirectoryURL =
                        directoryURL.standardizedFileURL
                    throw CocoaError(.fileWriteUnknown)
                }
            )

        XCTAssertThrowsError(try interruptedTransaction.quarantine()) {
            error in
            guard
                let transactionError =
                    error as? SubstrateCacheRecoveryTransactionError,
                case let .directorySynchronizationFailed(
                    failedURL,
                    _
                ) = transactionError
            else {
                return XCTFail(
                    "Expected directorySynchronizationFailed, got \(error)"
                )
            }
            XCTAssertEqual(
                failedURL.standardizedFileURL,
                failedTransactionDirectoryURL
            )
        }
        XCTAssertTrue(synchronizationFailureWasInjected)
        let transactionDirectoryURL = try XCTUnwrap(
            failedTransactionDirectoryURL
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: transactionDirectoryURL.appendingPathComponent(
                    "recovery-transaction"
                ).path
            )
        )
        XCTAssertTrue(
            try durableStoreFamilySnapshot(at: storeURL).isEmpty
        )

        var retrySynchronizationURLs: [URL] = []
        let relaunchedTransaction =
            CrashConsistentSubstrateCacheRecovery(
                storeURL: storeURL,
                fileManager: .default,
                directorySynchronizationHook: { directoryURL in
                    retrySynchronizationURLs.append(
                        directoryURL.standardizedFileURL
                    )
                }
            )
        _ = try relaunchedTransaction.reconcile()

        XCTAssertEqual(
            retrySynchronizationURLs,
            [
                transactionDirectoryURL,
                databaseDirectoryURL,
                transactionDirectoryURL
            ],
            "Retry must sync destination then source before marker removal"
        )
        XCTAssertEqual(
            try durableStoreFamilySnapshot(
                at: transactionDirectoryURL.appendingPathComponent(
                    storeURL.lastPathComponent
                )
            ),
            expectedFamily
        )
        XCTAssertTrue(
            try durableStoreFamilySnapshot(at: storeURL).isEmpty
        )
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: transactionDirectoryURL.appendingPathComponent(
                    "recovery-transaction"
                ).path
            )
        )
    }

    func testCacheRecoveryTransaction_whenFinalLegacyRestoreDirectorySynchronizationFails_thenRetryResynchronizesBothDirectoriesBeforeCommit() throws {
        let expectedFamily = try writeSyntheticStoreFamily(
            at: storeURL,
            discriminator: 0xFA
        )
        let suffixes = ["", "-wal", "-shm", "-journal"]
        let databaseDirectoryURL = storeURL.deletingLastPathComponent()
            .standardizedFileURL
        let archiveURL = testDirectory.appendingPathComponent(
            "SubstrateStoreRecovery",
            isDirectory: true
        ).appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: archiveURL,
            withIntermediateDirectories: true
        )
        for suffix in ["", "-wal"] {
            let sourceURL = URL(
                fileURLWithPath: storeURL.path + suffix
            )
            try FileManager.default.moveItem(
                at: sourceURL,
                to: archiveURL.appendingPathComponent(
                    sourceURL.lastPathComponent
                )
            )
        }

        var synchronizationFailureWasInjected = false
        let interruptedTransaction =
            CrashConsistentSubstrateCacheRecovery(
                storeURL: storeURL,
                fileManager: .default,
                directorySynchronizationHook: { directoryURL in
                    guard
                        !synchronizationFailureWasInjected,
                        directoryURL.standardizedFileURL ==
                        databaseDirectoryURL,
                        suffixes.allSatisfy({ suffix in
                            FileManager.default.fileExists(
                                atPath: self.storeURL.path + suffix
                            )
                        })
                    else {
                        return
                    }

                    synchronizationFailureWasInjected = true
                    throw CocoaError(.fileWriteUnknown)
                }
            )

        XCTAssertThrowsError(try interruptedTransaction.reconcile()) {
            error in
            guard
                let transactionError =
                    error as? SubstrateCacheRecoveryTransactionError,
                case let .directorySynchronizationFailed(
                    failedURL,
                    _
                ) = transactionError
            else {
                return XCTFail(
                    "Expected directorySynchronizationFailed, got \(error)"
                )
            }
            XCTAssertEqual(
                failedURL.standardizedFileURL,
                databaseDirectoryURL
            )
        }
        XCTAssertTrue(synchronizationFailureWasInjected)
        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: storeURL),
            expectedFamily
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: archiveURL.appendingPathComponent(
                    "recovery-transaction"
                ).path
            )
        )

        var retrySynchronizationURLs: [URL] = []
        let relaunchedTransaction =
            CrashConsistentSubstrateCacheRecovery(
                storeURL: storeURL,
                fileManager: .default,
                directorySynchronizationHook: { directoryURL in
                    retrySynchronizationURLs.append(
                        directoryURL.standardizedFileURL
                    )
                }
            )
        _ = try relaunchedTransaction.reconcile()

        XCTAssertEqual(
            retrySynchronizationURLs,
            [
                databaseDirectoryURL,
                archiveURL.standardizedFileURL,
                archiveURL.standardizedFileURL
            ],
            "Retry must sync destination then source before marker removal"
        )
        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: storeURL),
            expectedFamily
        )
        XCTAssertEqual(
            Set(
                try durableStoreFamilySnapshot(
                    at: archiveURL.appendingPathComponent(
                        storeURL.lastPathComponent
                    )
                ).keys
            ),
            [
                storeURL.lastPathComponent,
                storeURL.lastPathComponent + "-wal"
            ]
        )
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: archiveURL.appendingPathComponent(
                    "recovery-transaction"
                ).path
            )
        )
    }

    func testRequiresMigration_whenCacheRecoveryMarkerIsPendingBeforeFirstMove_thenReturnsTrueForCurrentStore() throws {
        let currentModel = try model(for: .version8)
        try createStore(at: storeURL, model: currentModel) { context in
            try self.insertRuntimeItem(
                identifier: "pending-cache-recovery",
                in: context,
                model: currentModel
            )
        }
        let transaction = CrashConsistentSubstrateCacheRecovery(
            storeURL: storeURL,
            fileManager: .default,
            boundaryHook: { boundary in
                guard boundary == .markerPersisted else {
                    return
                }
                throw SubstrateCacheRecoveryInterruption
                    .simulatedProcessDeath
            }
        )
        XCTAssertThrowsError(try transaction.quarantine())

        XCTAssertTrue(makeMigrator().requiresMigration())
    }

    func testCacheRecoveryTransaction_whenCompletedLegacyArchiveExistsBesideRebuiltLiveStore_thenLeavesBothUntouched() throws {
        let liveFamily = try writeSyntheticStoreFamily(
            at: storeURL,
            discriminator: 0xEA
        )
        let transaction = CrashConsistentSubstrateCacheRecovery(
            storeURL: storeURL,
            fileManager: .default
        )
        let completedArchiveURL = transaction.recoveryRootURL
            .appendingPathComponent(
                UUID().uuidString,
                isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: completedArchiveURL,
            withIntermediateDirectories: true
        )
        let archivedStoreURL = completedArchiveURL
            .appendingPathComponent(storeURL.lastPathComponent)
        let archivedFamily = try writeSyntheticStoreFamily(
            at: archivedStoreURL,
            discriminator: 0xEB
        )

        XCTAssertNil(try transaction.reconcile())

        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: storeURL),
            liveFamily
        )
        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: archivedStoreURL),
            archivedFamily
        )
    }

    func testCacheRecoveryRetention_whenQuarantineCompletes_thenExcludesRootAndArchiveFromBackup() throws {
        let expectedFamily = try writeSyntheticStoreFamily(
            at: storeURL,
            discriminator: 0xA0
        )
        let transaction = CrashConsistentSubstrateCacheRecovery(
            storeURL: storeURL,
            fileManager: .default
        )

        let archiveURL = try XCTUnwrap(transaction.quarantine())

        XCTAssertEqual(
            try durableStoreFamilySnapshot(
                at: archiveURL.appendingPathComponent(
                    storeURL.lastPathComponent
                )
            ),
            expectedFamily
        )
        XCTAssertEqual(
            try transaction.recoveryRootURL.resourceValues(
                forKeys: [.isExcludedFromBackupKey]
            ).isExcludedFromBackup,
            true
        )
        XCTAssertEqual(
            try archiveURL.resourceValues(
                forKeys: [.isExcludedFromBackupKey]
            ).isExcludedFromBackup,
            true
        )
    }

    func testCacheRecoveryRetention_whenBackupExclusionFails_thenPreservesLiveFamilyBeforeMarker() throws {
        let expectedFamily = try writeSyntheticStoreFamily(
            at: storeURL,
            discriminator: 0xA4
        )
        let transaction = CrashConsistentSubstrateCacheRecovery(
            storeURL: storeURL,
            fileManager: .default,
            backupExclusionHook: { url in
                guard
                    url.lastPathComponent !=
                    "SubstrateStoreRecovery"
                else {
                    return
                }
                throw InjectedSubstrateBackupExclusionError.failure
            }
        )

        XCTAssertThrowsError(try transaction.quarantine()) { error in
            guard
                let transactionError =
                    error as? SubstrateCacheRecoveryTransactionError,
                case .backupExclusionFailed = transactionError
            else {
                return XCTFail(
                    "Expected backupExclusionFailed, got \(error)"
                )
            }
        }

        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: storeURL),
            expectedFamily
        )
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: transaction.recoveryRootURL.path
            )
        )
    }

    func testCacheRecoveryRetention_whenCountLimitExceeded_thenDeletesOnlyOldestCompleteFamily() throws {
        let liveFamily = try writeSyntheticStoreFamily(
            at: storeURL,
            discriminator: 0xA8
        )
        let transaction = CrashConsistentSubstrateCacheRecovery(
            storeURL: storeURL,
            fileManager: .default,
            backupExclusionHook: { _ in },
            retainedArchiveCount: 2,
            retainedArchiveByteCount: .max
        )
        let oldest = try writeCompletedRecoveryArchive(
            for: transaction,
            identifier: "00000000-0000-0000-0000-000000000001",
            discriminator: 0xB0,
            completionDate: Date(timeIntervalSince1970: 1)
        )
        let middle = try writeCompletedRecoveryArchive(
            for: transaction,
            identifier: "00000000-0000-0000-0000-000000000002",
            discriminator: 0xB4,
            completionDate: Date(timeIntervalSince1970: 2)
        )
        let newest = try writeCompletedRecoveryArchive(
            for: transaction,
            identifier: "00000000-0000-0000-0000-000000000003",
            discriminator: 0xB8,
            completionDate: Date(timeIntervalSince1970: 3)
        )

        XCTAssertNil(try transaction.reconcile())

        XCTAssertFalse(
            FileManager.default.fileExists(atPath: oldest.url.path)
        )
        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: middle.storeURL),
            middle.family
        )
        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: newest.storeURL),
            newest.family
        )
        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: storeURL),
            liveFamily
        )
    }

    func testCacheRecoveryRetention_whenByteBudgetCannotHoldArchive_thenDeletesWholeFamilyAndPreservesLiveStore() throws {
        let liveFamily = try writeSyntheticStoreFamily(
            at: storeURL,
            discriminator: 0xBC
        )
        let transaction = CrashConsistentSubstrateCacheRecovery(
            storeURL: storeURL,
            fileManager: .default,
            backupExclusionHook: { _ in },
            retainedArchiveCount: 10,
            retainedArchiveByteCount: 1
        )
        let archive = try writeCompletedRecoveryArchive(
            for: transaction,
            identifier: "00000000-0000-0000-0000-000000000004",
            discriminator: 0xC0,
            completionDate: Date(timeIntervalSince1970: 4)
        )

        XCTAssertNil(try transaction.reconcile())

        XCTAssertFalse(
            FileManager.default.fileExists(atPath: archive.url.path)
        )
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: transaction.recoveryRootURL.path
            )
        )
        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: storeURL),
            liveFamily
        )
    }

    func testCacheRecoveryRetention_whenAnyArchiveTreeIsUnrecognized_thenFailsClosedBeforeDeletingValidArchive() throws {
        let liveFamily = try writeSyntheticStoreFamily(
            at: storeURL,
            discriminator: 0xC4
        )
        let transaction = CrashConsistentSubstrateCacheRecovery(
            storeURL: storeURL,
            fileManager: .default,
            backupExclusionHook: { _ in },
            retainedArchiveCount: 0,
            retainedArchiveByteCount: 0
        )
        let validArchive = try writeCompletedRecoveryArchive(
            for: transaction,
            identifier: "00000000-0000-0000-0000-000000000005",
            discriminator: 0xC8,
            completionDate: Date(timeIntervalSince1970: 5)
        )
        let hostileArchive = try writeCompletedRecoveryArchive(
            for: transaction,
            identifier: "00000000-0000-0000-0000-000000000006",
            discriminator: 0xCC,
            completionDate: Date(timeIntervalSince1970: 6)
        )
        let hostileURL = hostileArchive.url.appendingPathComponent(
            "unrecognized-user-file"
        )
        let hostileData = Data("must-not-be-deleted".utf8)
        try hostileData.write(to: hostileURL)

        XCTAssertThrowsError(try transaction.reconcile()) { error in
            guard
                let transactionError =
                    error as? SubstrateCacheRecoveryTransactionError,
                case .unsafeDirectory = transactionError
            else {
                return XCTFail(
                    "Expected unsafeDirectory, got \(error)"
                )
            }
        }

        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: validArchive.storeURL),
            validArchive.family
        )
        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: hostileArchive.storeURL),
            hostileArchive.family
        )
        XCTAssertEqual(try Data(contentsOf: hostileURL), hostileData)
        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: storeURL),
            liveFamily
        )
    }

    func testCacheRecoveryRetention_whenArchiveMemberHardlinksLiveStore_thenFailsClosedWithoutUnlinkingEitherPath() throws {
        let liveFamily = try writeSyntheticStoreFamily(
            at: storeURL,
            discriminator: 0xD0
        )
        let transaction = CrashConsistentSubstrateCacheRecovery(
            storeURL: storeURL,
            fileManager: .default,
            backupExclusionHook: { _ in },
            retainedArchiveCount: 0,
            retainedArchiveByteCount: 0
        )
        let archive = try writeCompletedRecoveryArchive(
            for: transaction,
            identifier: "00000000-0000-0000-0000-000000000007",
            discriminator: 0xD4,
            completionDate: Date(timeIntervalSince1970: 7)
        )
        try FileManager.default.removeItem(at: archive.storeURL)
        try FileManager.default.linkItem(
            at: storeURL,
            to: archive.storeURL
        )

        XCTAssertThrowsError(try transaction.reconcile()) { error in
            guard
                let transactionError =
                    error as? SubstrateCacheRecoveryTransactionError,
                case .unsafeFile = transactionError
            else {
                return XCTFail(
                    "Expected unsafeFile, got \(error)"
                )
            }
        }

        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: storeURL),
            liveFamily
        )
        XCTAssertEqual(
            try Data(contentsOf: archive.storeURL),
            try Data(contentsOf: storeURL)
        )
    }

    func testCacheRecoveryRetention_whenDeletionIsInterruptedAtEveryDurableBoundary_thenRelaunchConvergesWithoutTouchingNewestOrLiveFamily() throws {
        let oldestIdentifier =
            "00000000-0000-0000-0000-000000000008"
        let boundaries: [SubstrateCacheRecoveryBoundary] = [
            .retentionMarkerPersisted(oldestIdentifier),
            .retentionFamilyMemberRemoved(oldestIdentifier, ""),
            .retentionFamilyMemberRemoved(oldestIdentifier, "-wal"),
            .retentionFamilyMemberRemoved(oldestIdentifier, "-shm"),
            .retentionFamilyMemberRemoved(
                oldestIdentifier,
                "-journal"
            ),
            .retentionMarkerRemoved(oldestIdentifier),
            .retentionArchiveRemoved(oldestIdentifier)
        ]

        for (index, boundary) in boundaries.enumerated() {
            let caseDirectory = testDirectory.appendingPathComponent(
                "retention-interruption-\(index)",
                isDirectory: true
            )
            try FileManager.default.createDirectory(
                at: caseDirectory,
                withIntermediateDirectories: false
            )
            let caseStoreURL = caseDirectory.appendingPathComponent(
                storeURL.lastPathComponent
            )
            let liveFamily = try writeSyntheticStoreFamily(
                at: caseStoreURL,
                discriminator: UInt8(0xD8 + index)
            )
            var interruptionWasInjected = false
            let interruptedTransaction =
                CrashConsistentSubstrateCacheRecovery(
                    storeURL: caseStoreURL,
                    fileManager: .default,
                    boundaryHook: { reachedBoundary in
                        guard
                            reachedBoundary == boundary,
                            !interruptionWasInjected
                        else {
                            return
                        }
                        interruptionWasInjected = true
                        throw SubstrateCacheRecoveryInterruption
                            .simulatedProcessDeath
                    },
                    backupExclusionHook: { _ in },
                    retainedArchiveCount: 1,
                    retainedArchiveByteCount: .max
                )
            let oldest = try writeCompletedRecoveryArchive(
                for: interruptedTransaction,
                identifier: oldestIdentifier,
                discriminator: UInt8(0xE0 + index),
                completionDate: Date(timeIntervalSince1970: 8)
            )
            let newest = try writeCompletedRecoveryArchive(
                for: interruptedTransaction,
                identifier:
                "00000000-0000-0000-0000-000000000009",
                discriminator: UInt8(0xE8 + index),
                completionDate: Date(timeIntervalSince1970: 9)
            )

            XCTAssertThrowsError(
                try interruptedTransaction.reconcile()
            ) { error in
                guard error is SubstrateCacheRecoveryInterruption else {
                    return XCTFail(
                        "Expected retention interruption, got \(error)"
                    )
                }
            }
            XCTAssertTrue(interruptionWasInjected)

            let relaunchedTransaction =
                CrashConsistentSubstrateCacheRecovery(
                    storeURL: caseStoreURL,
                    fileManager: .default,
                    backupExclusionHook: { _ in },
                    retainedArchiveCount: 1,
                    retainedArchiveByteCount: .max
                )
            XCTAssertNil(try relaunchedTransaction.reconcile())

            XCTAssertFalse(
                FileManager.default.fileExists(atPath: oldest.url.path),
                "Oldest archive survived \(boundary)"
            )
            XCTAssertEqual(
                try durableStoreFamilySnapshot(at: newest.storeURL),
                newest.family,
                "Newest archive changed after \(boundary)"
            )
            XCTAssertEqual(
                try durableStoreFamilySnapshot(at: caseStoreURL),
                liveFamily,
                "Live family changed after \(boundary)"
            )
            XCTAssertEqual(
                try contents(
                    of: relaunchedTransaction.recoveryRootURL
                ),
                [newest.url]
            )
        }
    }

    func testCacheRecoveryTransaction_whenLegacySplitHasMultipleCandidates_thenFailsClosedWithoutChoosingArchive() throws {
        let expectedFamily = try writeSyntheticStoreFamily(
            at: storeURL,
            discriminator: 0xEC
        )
        let mainData = try Data(contentsOf: storeURL)
        try FileManager.default.removeItem(at: storeURL)
        let transaction = CrashConsistentSubstrateCacheRecovery(
            storeURL: storeURL,
            fileManager: .default
        )
        var archiveURLs: [URL] = []

        for _ in 0 ..< 2 {
            let archiveURL = transaction.recoveryRootURL
                .appendingPathComponent(
                    UUID().uuidString,
                    isDirectory: true
                )
            try FileManager.default.createDirectory(
                at: archiveURL,
                withIntermediateDirectories: true
            )
            try mainData.write(
                to: archiveURL.appendingPathComponent(
                    storeURL.lastPathComponent
                )
            )
            archiveURLs.append(archiveURL)
        }
        let liveRemainder = try durableStoreFamilySnapshot(at: storeURL)

        XCTAssertThrowsError(try transaction.reconcile()) { error in
            guard
                let transactionError =
                    error as? SubstrateCacheRecoveryTransactionError,
                case .multiplePendingTransactions = transactionError
            else {
                return XCTFail(
                    "Expected multiplePendingTransactions, got \(error)"
                )
            }
        }

        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: storeURL),
            liveRemainder
        )
        for archiveURL in archiveURLs {
            XCTAssertEqual(
                try Data(
                    contentsOf: archiveURL.appendingPathComponent(
                        storeURL.lastPathComponent
                    )
                ),
                mainData
            )
            XCTAssertFalse(
                FileManager.default.fileExists(
                    atPath: archiveURL.appendingPathComponent(
                        "recovery-transaction"
                    ).path
                )
            )
        }
        XCTAssertEqual(
            Set(expectedFamily.keys),
            Set(liveRemainder.keys).union(
                [storeURL.lastPathComponent]
            )
        )
    }

    func testCacheRecoveryTransaction_whenLegacySplitIsTamperedOrOverlapping_thenFailsClosed() throws {
        for variant in ["unknown-file", "overlapping-member"] {
            let caseDirectory = testDirectory.appendingPathComponent(
                variant,
                isDirectory: true
            )
            try FileManager.default.createDirectory(
                at: caseDirectory,
                withIntermediateDirectories: false
            )
            let caseStoreURL = caseDirectory.appendingPathComponent(
                storeURL.lastPathComponent
            )
            _ = try writeSyntheticStoreFamily(
                at: caseStoreURL,
                discriminator:
                variant == "unknown-file" ? 0xED : 0xEE
            )
            let mainData = try Data(contentsOf: caseStoreURL)
            try FileManager.default.removeItem(at: caseStoreURL)
            let transaction = CrashConsistentSubstrateCacheRecovery(
                storeURL: caseStoreURL,
                fileManager: .default
            )
            let archiveURL = transaction.recoveryRootURL
                .appendingPathComponent(
                    UUID().uuidString,
                    isDirectory: true
                )
            try FileManager.default.createDirectory(
                at: archiveURL,
                withIntermediateDirectories: true
            )
            try mainData.write(
                to: archiveURL.appendingPathComponent(
                    caseStoreURL.lastPathComponent
                )
            )

            if variant == "unknown-file" {
                try Data("tampered".utf8).write(
                    to: archiveURL.appendingPathComponent(
                        "unexpected"
                    )
                )
            } else {
                let liveWALURL = URL(
                    fileURLWithPath: caseStoreURL.path + "-wal"
                )
                try Data(contentsOf: liveWALURL).write(
                    to: archiveURL.appendingPathComponent(
                        liveWALURL.lastPathComponent
                    )
                )
            }
            let liveBefore = try durableStoreFamilySnapshot(
                at: caseStoreURL
            )
            let archiveBefore = try contentsSnapshot(
                of: archiveURL
            )

            XCTAssertThrowsError(try transaction.reconcile()) {
                error in
                guard
                    let transactionError =
                        error as?
                        SubstrateCacheRecoveryTransactionError,
                    case .familyMismatch = transactionError
                else {
                    return XCTFail(
                        "Expected familyMismatch, got \(error)"
                    )
                }
            }

            XCTAssertEqual(
                try durableStoreFamilySnapshot(at: caseStoreURL),
                liveBefore
            )
            XCTAssertEqual(
                try contentsSnapshot(of: archiveURL),
                archiveBefore
            )
        }
    }

    func testSyncMigration_whenKnownStoreHasContact_thenBlocksRecovery() throws {
        try assertProtectedDataBlocksRecovery(expectedCategory: "CDContact") { context, model in
            let contact = try self.insert(entityName: "CDContact", in: context, model: model)
            contact.setValue("Alice", forKey: "name")
            contact.setValue("5ProtectedContact", forKey: "address")
            contact.setValue("protected-chain", forKey: "chainId")
        }
    }

    func testSyncMigration_whenKnownStoreHasContactItem_thenBlocksRecovery() throws {
        try assertProtectedDataBlocksRecovery(expectedCategory: "CDContactItem") { context, model in
            let contact = try self.insert(entityName: "CDContactItem", in: context, model: model)
            contact.setValue("wallet-peer", forKey: "identifier")
            contact.setValue("5Peer", forKey: "peerAddress")
            contact.setValue("Peer", forKey: "peerName")
            contact.setValue("5Wallet", forKey: "targetAddress")
            contact.setValue(Int64(1_700_000_000), forKey: "updatedAt")
        }
    }

    func testSyncMigration_whenKnownStoreHasTransactionHistory_thenBlocksRecovery() throws {
        try assertProtectedDataBlocksRecovery(
            expectedCategory: "CDTransactionHistoryItem"
        ) { context, model in
            let transaction = try self.insert(
                entityName: "CDTransactionHistoryItem",
                in: context,
                model: model
            )
            transaction.setValue("0xprotected", forKey: "identifier")
            transaction.setValue("5Sender", forKey: "sender")
            transaction.setValue("5Receiver", forKey: "receiver")
            transaction.setValue(Int16(0), forKey: "status")
            transaction.setValue(Int64(1_700_000_000), forKey: "timestamp")
            transaction.setValue("1", forKey: "fee")
            transaction.setValue("Balances", forKey: "moduleName")
            transaction.setValue("transfer", forKey: "callName")
        }
    }

    func testSyncMigration_whenKnownStoreHasCustomNode_thenBlocksRecovery() throws {
        try assertProtectedDataBlocksRecovery(
            expectedCategory: "CDChain.customNodes"
        ) { context, model in
            let graph = try self.insertChainWithDefaultNode(
                in: context,
                model: model
            )
            let customNode = try self.insert(
                entityName: "CDChainNode",
                in: context,
                model: model
            )
            customNode.setValue("My RPC", forKey: "name")
            customNode.setValue(
                try XCTUnwrap(URL(string: "wss://custom.example.invalid")),
                forKey: "url"
            )
            graph.chain.mutableSetValue(forKey: "customNodes").add(customNode)
        }
    }

    func testSyncMigration_whenKnownStoreHasSelectedDefaultNode_thenBlocksRecovery() throws {
        try assertProtectedDataBlocksRecovery(
            expectedCategory: "CDChain.selectedNode"
        ) { context, model in
            let graph = try self.insertChainWithDefaultNode(
                in: context,
                model: model
            )
            graph.chain.setValue(graph.node, forKey: "selectedNode")
        }
    }

    func testSyncMigration_whenKnownStoreHasOrphanNode_thenBlocksRecovery() throws {
        try assertProtectedDataBlocksRecovery(
            expectedCategory: "CDChainNode.orphan"
        ) { context, model in
            let orphanNode = try self.insert(
                entityName: "CDChainNode",
                in: context,
                model: model
            )
            orphanNode.setValue("Unattached RPC", forKey: "name")
            orphanNode.setValue(
                try XCTUnwrap(URL(string: "wss://orphan.example.invalid")),
                forKey: "url"
            )
        }
    }

    func testCallbackMigration_whenStoreIsCorrupt_thenDoesNotCompleteOrQuarantine() throws {
        try Data("still-not-a-core-data-store".utf8).write(to: storeURL, options: .atomic)
        let before = try durableStoreFamilySnapshot(at: storeURL)
        let migrator = makeMigrator()
        let completionExpectation = expectation(
            description: "callback must not complete after fail-closed migration"
        )
        completionExpectation.isInverted = true

        migrator.migrate {
            completionExpectation.fulfill()
        }

        wait(for: [completionExpectation], timeout: 0.25)
        XCTAssertEqual(try durableStoreFamilySnapshot(at: storeURL), before)
        XCTAssertTrue(try recoveryDirectories().isEmpty)
    }

    private func writeSyntheticStoreFamily(
        at syntheticStoreURL: URL,
        discriminator: UInt8
    ) throws -> [String: Data] {
        let suffixes = ["", "-wal", "-shm", "-journal"]
        var expected: [String: Data] = [:]

        for (index, suffix) in suffixes.enumerated() {
            let byte = discriminator &+ UInt8(index)
            let data = Data(
                repeating: byte,
                count: 37 + index * 19
            )
            let url = URL(
                fileURLWithPath: syntheticStoreURL.path + suffix
            )
            try data.write(to: url)
            expected[url.lastPathComponent] = data
        }

        return expected
    }

    private func writeCompletedRecoveryArchive(
        for transaction: CrashConsistentSubstrateCacheRecovery,
        identifier: String,
        discriminator: UInt8,
        completionDate: Date
    ) throws -> (
        url: URL,
        storeURL: URL,
        family: [String: Data]
    ) {
        if !FileManager.default.fileExists(
            atPath: transaction.recoveryRootURL.path
        ) {
            try FileManager.default.createDirectory(
                at: transaction.recoveryRootURL,
                withIntermediateDirectories: false
            )
        }

        let archiveURL = transaction.recoveryRootURL
            .appendingPathComponent(
                identifier,
                isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: archiveURL,
            withIntermediateDirectories: false
        )
        let archivedStoreURL = archiveURL.appendingPathComponent(
            transaction.storeURL.lastPathComponent
        )
        let family = try writeSyntheticStoreFamily(
            at: archivedStoreURL,
            discriminator: discriminator
        )
        try FileManager.default.setAttributes(
            [.modificationDate: completionDate],
            ofItemAtPath: archiveURL.path
        )

        return (
            url: archiveURL,
            storeURL: archivedStoreURL,
            family: family
        )
    }

    private func interruptCacheRecovery(
        storeURL interruptedStoreURL: URL? = nil,
        at boundary: SubstrateCacheRecoveryBoundary
    ) throws -> URL {
        let interruptedStoreURL = interruptedStoreURL ?? storeURL
        let transaction = CrashConsistentSubstrateCacheRecovery(
            storeURL: interruptedStoreURL,
            fileManager: .default,
            boundaryHook: { reachedBoundary in
                guard reachedBoundary == boundary else {
                    return
                }
                throw SubstrateCacheRecoveryInterruption
                    .simulatedProcessDeath
            }
        )

        XCTAssertThrowsError(try transaction.quarantine()) { error in
            guard error is SubstrateCacheRecoveryInterruption else {
                return XCTFail(
                    "Expected cache-recovery interruption, got \(error)"
                )
            }
        }

        return try XCTUnwrap(
            try contents(of: transaction.recoveryRootURL).first
        )
    }

    private func contents(of directoryURL: URL) throws -> [URL] {
        guard FileManager.default.fileExists(
            atPath: directoryURL.path
        ) else {
            return []
        }

        return try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        ).sorted {
            $0.lastPathComponent < $1.lastPathComponent
        }
    }

    private func contentsSnapshot(
        of directoryURL: URL
    ) throws -> [String: Data] {
        try Dictionary(
            uniqueKeysWithValues: contents(of: directoryURL).map {
                url in
                (url.lastPathComponent, try Data(contentsOf: url))
            }
        )
    }

    private func assertProtectedDataBlocksRecovery(
        expectedCategory: String,
        populate: (NSManagedObjectContext, NSManagedObjectModel) throws -> Void
    ) throws {
        let sourceModel = try model(for: .version3)
        try createStore(at: storeURL, model: sourceModel) { context in
            try populate(context, sourceModel)
        }
        let before = try durableStoreFamilySnapshot(at: storeURL)
        let modelOnlyBundle = try makeModelBundle()
        let migrator = makeMigrator(modelBundle: modelOnlyBundle)

        for _ in 0 ..< 2 {
            XCTAssertThrowsError(try migrator.migrate()) { error in
                guard
                    let migrationError = error as? SubstrateStorageMigrationError,
                    case let .cacheRecoveryBlockedByProtectedData(
                        blockedURL,
                        originalError,
                        counts
                    ) = migrationError
                else {
                    return XCTFail("Expected cacheRecoveryBlockedByProtectedData, got \(error)")
                }

                XCTAssertEqual(blockedURL, self.storeURL)
                XCTAssertEqual(
                    counts.filter { $0.value > 0 },
                    [expectedCategory: 1]
                )

                guard
                    let originalMigrationError = originalError as? SubstrateStorageMigrationError,
                    case let .mappingUnavailable(source, destination, _) =
                    originalMigrationError
                else {
                    return XCTFail("Expected mappingUnavailable, got \(originalError)")
                }

                XCTAssertEqual(source, .version3)
                XCTAssertEqual(destination, .version4)
            }

            XCTAssertTrue(migrator.requiresMigration())
            XCTAssertEqual(try durableStoreFamilySnapshot(at: storeURL), before)
            XCTAssertTrue(try recoveryDirectories().isEmpty)
        }
    }

    private func insert(
        entityName: String,
        in context: NSManagedObjectContext,
        model: NSManagedObjectModel
    ) throws -> NSManagedObject {
        let entity = try XCTUnwrap(model.entitiesByName[entityName])
        return NSManagedObject(entity: entity, insertInto: context)
    }

    private func insertStartupPayloadEntity(
        entityName: String,
        attributeName: String,
        payload: String,
        attachNodeAsCustomNode: Bool = false,
        in context: NSManagedObjectContext,
        model: NSManagedObjectModel
    ) throws {
        if entityName == "CDChainNode", attachNodeAsCustomNode {
            let graph = try insertChainWithDefaultNode(
                in: context,
                model: model
            )
            let customNode = try insert(
                entityName: entityName,
                in: context,
                model: model
            )
            customNode.setValue(
                try XCTUnwrap(
                    URL(string: "wss://custom.example.invalid")
                ),
                forKey: "url"
            )
            customNode.setValue(payload, forKey: attributeName)
            graph.chain.mutableSetValue(
                forKey: "customNodes"
            ).add(customNode)
            return
        }

        let object = try insert(
            entityName: entityName,
            in: context,
            model: model
        )
        switch entityName {
        case "CDAsset":
            object.setValue("a", forKey: "id")
            object.setValue(Int16(1), forKey: "precision")
        case "CDChainNode":
            object.setValue("n", forKey: "name")
            object.setValue(
                try XCTUnwrap(
                    URL(string: "wss://node.example.invalid")
                ),
                forKey: "url"
            )
        case "CDPriceData":
            object.setValue("c", forKey: "currencyId")
            object.setValue("1", forKey: "price")
            object.setValue("i", forKey: "priceId")
        case "CDChainXcmConfig",
             "CDExternalApi",
             "CDPriceProvider",
             "CDXcmAvailableAsset",
             "CDXcmAvailableDestination":
            break
        default:
            XCTFail(
                "Unsupported startup child fixture \(entityName)"
            )
            return
        }
        object.setValue(payload, forKey: attributeName)
    }

    private func assertStartupChildValueLimitExceeded(
        entityName: String,
        attributeName: String,
        attachNodeAsCustomNode: Bool = false,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let maximum: UInt64 = 1_024
        let actual = maximum + 1
        let currentModel = try model(for: .version8)
        try createStore(at: storeURL, model: currentModel) {
            context in
            try self.insertStartupPayloadEntity(
                entityName: entityName,
                attributeName: attributeName,
                payload: String(
                    repeating: "x",
                    count: Int(actual)
                ),
                attachNodeAsCustomNode:
                attachNodeAsCustomNode,
                in: context,
                model: currentModel
            )
        }
        let before = try durableStoreFamilySnapshot(at: storeURL)
        var stagedHookCalled = false
        var replacementCalled = false
        let migrator = makeMigrator(
            storeReplacer: { _, _ in
                replacementCalled = true
            },
            stagedStoreMutationHook: { _, _ in
                stagedHookCalled = true
            },
            protectedDataInspectionLimits:
            makeProtectedDataLimits(
                maximumStartupChildValueByteCount: maximum
            )
        )

        XCTAssertTrue(
            migrator.requiresMigration(),
            file: file,
            line: line
        )
        XCTAssertThrowsError(
            try migrator.performMigration(),
            file: file,
            line: line
        ) { error in
            guard
                let migrationError =
                    error as? SubstrateStorageMigrationError,
                case let .sourceStoreInspectionFailed(
                    failedURL,
                    underlyingError
                ) = migrationError,
                case let .startupChildValueByteLimitExceeded(
                    actualEntityName,
                    actualAttributeName,
                    valueByteCount,
                    maximumByteCount
                ) =
                    underlyingError as?
                    SubstrateProtectedDataInspectionError
            else {
                return XCTFail(
                    "Expected startup child value limit, got \(error)",
                    file: file,
                    line: line
                )
            }

            XCTAssertEqual(
                failedURL,
                self.storeURL,
                file: file,
                line: line
            )
            XCTAssertEqual(
                actualEntityName,
                entityName,
                file: file,
                line: line
            )
            XCTAssertEqual(
                actualAttributeName,
                attributeName,
                file: file,
                line: line
            )
            XCTAssertEqual(
                valueByteCount,
                actual,
                file: file,
                line: line
            )
            XCTAssertEqual(
                maximumByteCount,
                maximum,
                file: file,
                line: line
            )
        }
        XCTAssertFalse(
            stagedHookCalled,
            file: file,
            line: line
        )
        XCTAssertFalse(
            replacementCalled,
            file: file,
            line: line
        )
        XCTAssertEqual(
            try durableStoreFamilySnapshot(at: storeURL),
            before,
            file: file,
            line: line
        )
    }

    private func insertChainWithDefaultNode(
        in context: NSManagedObjectContext,
        model: NSManagedObjectModel
    ) throws -> (chain: NSManagedObject, node: NSManagedObject) {
        let chain = try insert(entityName: "CDChain", in: context, model: model)
        chain.setValue("protected-chain", forKey: "chainId")
        chain.setValue("Protected Chain", forKey: "name")

        let node = try insert(entityName: "CDChainNode", in: context, model: model)
        node.setValue("Default RPC", forKey: "name")
        node.setValue(
            try XCTUnwrap(URL(string: "wss://default.example.invalid")),
            forKey: "url"
        )
        node.setValue(chain, forKey: "chain")

        return (chain, node)
    }

    private func makeMigrator(
        targetVersion: SubstrateStorageVersion = .version8,
        modelBundle: Bundle? = nil,
        storeURL: URL? = nil,
        fileManager: FileManager = .default,
        storeReplacer: @escaping (
            URL,
            URL
        ) throws -> Void = { targetURL, sourceURL in
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
    ) -> SubstrateStorageMigrator {
        SubstrateStorageMigrator(
            targetVersion: targetVersion,
            storeURL: storeURL ?? self.storeURL,
            modelDirectory: SubstrateStorageParams.modelDirectory,
            fileManager: fileManager,
            modelBundle: modelBundle ?? appBundle,
            storeReplacer: storeReplacer,
            stagedStoreMutationHook: stagedStoreMutationHook,
            checkpointStoreHook: checkpointStoreHook,
            privateSourceCopyLimits: privateSourceCopyLimits,
            privateSourceAvailableCapacityProvider:
            privateSourceAvailableCapacityProvider,
            protectedDataInspectionLimits:
            protectedDataInspectionLimits,
            transformableObjectIDPageDidFetch:
            transformableObjectIDPageDidFetch,
            protectedRelationshipCountDidFetch:
            protectedRelationshipCountDidFetch,
            protectedRelationshipWillMaterialize:
            protectedRelationshipWillMaterialize
        )
    }

    private func makeProtectedDataLimits(
        fetchPageSize: Int = 16,
        maximumRowsPerEntity: Int = 100,
        maximumTotalRows: Int = 500,
        maximumStartupRootRowsPerEntity: Int = 4_096,
        maximumStartupRootPayloadByteCount: UInt64 =
            256 * 1024 * 1024,
        maximumStartupChildValueByteCount: UInt64 =
            256 * 1024,
        maximumStartupChildPayloadByteCount: UInt64 =
            256 * 1024 * 1024,
        maximumRelationshipMembers: Int = 100,
        maximumTotalRelationshipMembers: Int = 500,
        maximumTransformableElements: Int = 100,
        maximumTransformableArchiveByteCount: Int = 8_192,
        maximumValueByteCount: Int = 1_024,
        maximumRecordByteCount: Int = 8_192
    ) -> SubstrateProtectedDataInspectionLimits {
        SubstrateProtectedDataInspectionLimits(
            fetchPageSize: fetchPageSize,
            maximumRowsPerEntity: maximumRowsPerEntity,
            maximumTotalRows: maximumTotalRows,
            maximumStartupRootRowsPerEntity:
            maximumStartupRootRowsPerEntity,
            maximumStartupRootPayloadByteCount:
            maximumStartupRootPayloadByteCount,
            maximumStartupChildValueByteCount:
            maximumStartupChildValueByteCount,
            maximumStartupChildPayloadByteCount:
            maximumStartupChildPayloadByteCount,
            maximumRelationshipMembers:
            maximumRelationshipMembers,
            maximumTotalRelationshipMembers:
            maximumTotalRelationshipMembers,
            maximumTransformableElements:
            maximumTransformableElements,
            maximumTransformableArchiveByteCount:
            maximumTransformableArchiveByteCount,
            maximumValueByteCount: maximumValueByteCount,
            maximumRecordByteCount: maximumRecordByteCount
        )
    }

    private func model(
        for version: SubstrateStorageVersion,
        in bundle: Bundle? = nil
    ) throws -> NSManagedObjectModel {
        let bundle = bundle ?? appBundle
        let modelURL = bundle.url(
            forResource: version.rawValue,
            withExtension: "omo",
            subdirectory: SubstrateStorageParams.modelDirectory
        ) ?? bundle.url(
            forResource: version.rawValue,
            withExtension: "mom",
            subdirectory: SubstrateStorageParams.modelDirectory
        )

        return try XCTUnwrap(
            modelURL.flatMap(NSManagedObjectModel.init(contentsOf:)),
            "Unable to load \(version.rawValue) from \(bundle.bundleURL.path)"
        )
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

    @discardableResult
    private func insertRuntimeItem(
        identifier: String,
        in context: NSManagedObjectContext,
        model: NSManagedObjectModel
    ) throws -> NSManagedObject {
        let entity = try XCTUnwrap(model.entitiesByName["CDRuntimeMetadataItem"])
        let item = NSManagedObject(entity: entity, insertInto: context)
        item.setValue(identifier, forKey: "identifier")
        item.setValue(Int32(1), forKey: "version")
        item.setValue(Int32(1), forKey: "txVersion")
        return item
    }

    private func insertChainStorageItem(
        identifier: String,
        in context: NSManagedObjectContext,
        model: NSManagedObjectModel
    ) throws {
        let entity = try XCTUnwrap(model.entitiesByName["CDChainStorageItem"])
        let item = NSManagedObject(entity: entity, insertInto: context)
        item.setValue(identifier, forKey: "identifier")
        item.setValue(Data([0x00, 0x80, 0xFF]), forKey: "data")
    }

    @discardableResult
    private func insertMigrationAsset(
        identifier: String,
        in context: NSManagedObjectContext,
        model: NSManagedObjectModel
    ) throws -> NSManagedObject {
        let entity = try XCTUnwrap(model.entitiesByName["CDAsset"])
        let asset = NSManagedObject(entity: entity, insertInto: context)
        asset.setValue(identifier, forKey: "id")
        asset.setValue(Int16(18), forKey: "precision")

        if entity.attributesByName["chainId"] != nil {
            asset.setValue("migration-fixture-chain", forKey: "chainId")
        }

        if entity.attributesByName["symbol"] != nil {
            asset.setValue("FIX", forKey: "symbol")
        }

        return asset
    }

    private func createVersion7AssetStore(
        purchaseProviders: [String]
    ) throws {
        let sourceModel = try model(for: .version7)
        try createStore(at: storeURL, model: sourceModel) {
            context in
            let asset = try self.insertMigrationAsset(
                identifier: "bounded-transformable-asset",
                in: context,
                model: sourceModel
            )
            asset.setValue(
                NSArray(array: purchaseProviders),
                forKey: "purchaseProviders"
            )
        }
    }

    private func createCurrentTransformableAndProtectedGraph() throws {
        let currentModel = try model(for: .version8)
        try createStore(at: storeURL, model: currentModel) {
            context in
            let graph = try self.insertChainWithDefaultNode(
                in: context,
                model: currentModel
            )
            graph.chain.setValue(
                NSArray(object: "safe-option"),
                forKey: "options"
            )

            let customNode = try self.insert(
                entityName: "CDChainNode",
                in: context,
                model: currentModel
            )
            customNode.setValue("Custom RPC", forKey: "name")
            customNode.setValue(
                try XCTUnwrap(
                    URL(string: "wss://current-custom.example.invalid")
                ),
                forKey: "url"
            )
            graph.chain.mutableSetValue(
                forKey: "customNodes"
            ).add(customNode)
            graph.chain.setValue(
                customNode,
                forKey: "selectedNode"
            )

            let asset = try self.insertMigrationAsset(
                identifier: "current-transformable-asset",
                in: context,
                model: currentModel
            )
            asset.setValue(
                NSArray(object: "safe-provider"),
                forKey: "purchaseProviders"
            )
            asset.setValue(graph.chain, forKey: "chain")
        }
    }

    private func createCurrentStartupRelationshipGraph() throws {
        let currentModel = try model(for: .version8)
        try createStore(at: storeURL, model: currentModel) {
            context in
            try self.insertRuntimeItem(
                identifier: "startup-runtime",
                in: context,
                model: currentModel
            )
            let graph = try self.insertChainWithDefaultNode(
                in: context,
                model: currentModel
            )

            let customNode = try self.insert(
                entityName: "CDChainNode",
                in: context,
                model: currentModel
            )
            customNode.setValue("Startup Custom RPC", forKey: "name")
            customNode.setValue(
                try XCTUnwrap(
                    URL(string: "wss://startup-custom.example.invalid")
                ),
                forKey: "url"
            )
            graph.chain.mutableSetValue(
                forKey: "customNodes"
            ).add(customNode)

            let asset = try self.insertMigrationAsset(
                identifier: "startup-asset",
                in: context,
                model: currentModel
            )
            asset.setValue(graph.chain, forKey: "chain")
            try self.insertPriceData(
                count: 1,
                for: asset,
                in: context,
                model: currentModel
            )

            let explorer = try self.insert(
                entityName: "CDExternalApi",
                in: context,
                model: currentModel
            )
            explorer.setValue("subscan", forKey: "type")
            explorer.setValue(
                "https://explorer.example.invalid",
                forKey: "url"
            )
            explorer.setValue(graph.chain, forKey: "chain")

            try self.insertXcmRelationshipGraph(
                for: graph.chain,
                in: context,
                model: currentModel
            )
        }
    }

    private func insertPriceData(
        count: Int,
        for asset: NSManagedObject,
        in context: NSManagedObjectContext,
        model: NSManagedObjectModel
    ) throws {
        for index in 0 ..< count {
            let priceData = try insert(
                entityName: "CDPriceData",
                in: context,
                model: model
            )
            priceData.setValue(
                "currency-\(index)",
                forKey: "currencyId"
            )
            priceData.setValue("1.0", forKey: "price")
            priceData.setValue(
                "price-\(index)",
                forKey: "priceId"
            )
            priceData.setValue(asset, forKey: "asset")
        }
    }

    private func insertXcmRelationshipGraph(
        for chain: NSManagedObject? = nil,
        in context: NSManagedObjectContext,
        model: NSManagedObjectModel
    ) throws {
        let config = try insert(
            entityName: "CDChainXcmConfig",
            in: context,
            model: model
        )
        if let chain {
            config.setValue(chain, forKey: "chain")
        }

        let availableAsset = try insert(
            entityName: "CDXcmAvailableAsset",
            in: context,
            model: model
        )
        availableAsset.setValue(
            "xcm-asset",
            forKey: "id"
        )
        config.mutableSetValue(
            forKey: "availableAssets"
        ).add(availableAsset)

        let destination = try insert(
            entityName: "CDXcmAvailableDestination",
            in: context,
            model: model
        )
        destination.setValue(
            "destination-chain",
            forKey: "chainId"
        )
        destination.setValue(config, forKey: "config")
        destination.mutableSetValue(
            forKey: "assets"
        ).add(availableAsset)
    }

    private func addPriceDataToSingleAsset(
        count: Int,
        at url: URL,
        model: NSManagedObjectModel
    ) throws {
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
        var mutationError: Error?
        context.performAndWait {
            do {
                let asset = try self.fetchSingleObject(
                    entityName: "CDAsset",
                    context: context
                )
                try self.insertPriceData(
                    count: count,
                    for: asset,
                    in: context,
                    model: model
                )
                try context.save()
            } catch {
                mutationError = error
            }
        }

        if let mutationError {
            throw mutationError
        }
    }

    private func assertCurrentTransformableAndProtectedGraph(
        expectedOptions: [String],
        expectedPurchaseProviders: [String]?
    ) throws {
        let currentModel = try model(for: .version8)
        try inspectStore(at: storeURL, model: currentModel) {
            context in
            let chain = try self.fetchSingleObject(
                entityName: "CDChain",
                context: context
            )
            XCTAssertEqual(
                try self.stringArray(in: chain, key: "options"),
                expectedOptions
            )

            let defaultNodes = self.relationshipObjects(
                in: chain,
                key: "nodes"
            )
            let customNodes = self.relationshipObjects(
                in: chain,
                key: "customNodes"
            )
            let selectedNode = try XCTUnwrap(
                chain.value(forKey: "selectedNode")
                    as? NSManagedObject
            )
            XCTAssertEqual(defaultNodes.count, 1)
            XCTAssertEqual(customNodes.count, 1)
            XCTAssertEqual(
                selectedNode.value(forKey: "url") as? URL,
                URL(string: "wss://current-custom.example.invalid")
            )
            XCTAssertEqual(
                customNodes.first,
                selectedNode
            )

            let asset = try self.fetchSingleObject(
                entityName: "CDAsset",
                context: context
            )
            XCTAssertEqual(
                try self.stringArray(
                    in: asset,
                    key: "purchaseProviders"
                ),
                expectedPurchaseProviders
            )
            XCTAssertEqual(
                asset.value(forKey: "chain") as? NSManagedObject,
                chain
            )
        }
    }

    private func migratedAssetPurchaseProviders() throws -> [String]? {
        let targetModel = try model(for: .version8)
        var purchaseProviders: [String]?
        try inspectStore(at: storeURL, model: targetModel) {
            context in
            let asset = try self.fetchSingleObject(
                entityName: "CDAsset",
                context: context
            )
            purchaseProviders = try self.stringArray(
                in: asset,
                key: "purchaseProviders"
            )
        }
        return purchaseProviders
    }

    private func insertLegacyChainWithNodes(
        in context: NSManagedObjectContext,
        model: NSManagedObjectModel
    ) throws {
        let chainEntity = try XCTUnwrap(model.entitiesByName["CDChain"])
        let nodeEntity = try XCTUnwrap(model.entitiesByName["CDChainNode"])

        let chain = NSManagedObject(entity: chainEntity, insertInto: context)
        chain.setValue("migration-chain", forKey: "chainId")
        chain.setValue("Migration Chain", forKey: "name")
        chain.setValue(URL(string: "https://example.invalid/icon.png"), forKey: "icon")

        let lastNode = NSManagedObject(entity: nodeEntity, insertInto: context)
        lastNode.setValue("Zulu Node", forKey: "name")
        lastNode.setValue(URL(string: "wss://zulu.example.invalid"), forKey: "url")
        lastNode.setValue(chain, forKey: "chain")

        let firstNode = NSManagedObject(entity: nodeEntity, insertInto: context)
        firstNode.setValue("Alpha Node", forKey: "name")
        firstNode.setValue(URL(string: "wss://alpha.example.invalid"), forKey: "url")
        firstNode.setValue(chain, forKey: "chain")
    }

    private func insertLegacyChainGraph(
        in context: NSManagedObjectContext,
        model: NSManagedObjectModel,
        symbol: String? = "MIG",
        includeNilAssetWrapper: Bool = false
    ) throws {
        let chainEntity = try XCTUnwrap(model.entitiesByName["CDChain"])
        let nodeEntity = try XCTUnwrap(model.entitiesByName["CDChainNode"])
        let assetEntity = try XCTUnwrap(model.entitiesByName["CDAsset"])
        let chainAssetEntity = try XCTUnwrap(model.entitiesByName["CDChainAsset"])

        let chain = NSManagedObject(entity: chainEntity, insertInto: context)
        chain.setValue("migration-chain", forKey: "chainId")
        chain.setValue("Migration Chain", forKey: "name")
        chain.setValue(URL(string: "https://example.invalid/icon.png"), forKey: "icon")

        let node = NSManagedObject(entity: nodeEntity, insertInto: context)
        node.setValue("Migration Node", forKey: "name")
        node.setValue(URL(string: "wss://example.invalid"), forKey: "url")
        node.setValue(chain, forKey: "chain")

        let asset = NSManagedObject(entity: assetEntity, insertInto: context)
        asset.setValue("migration-chain", forKey: "chainId")
        asset.setValue("migration-asset", forKey: "id")
        asset.setValue(Int16(18), forKey: "precision")
        asset.setValue(symbol, forKey: "symbol")

        let chainAsset = NSManagedObject(
            entity: chainAssetEntity,
            insertInto: context
        )
        chainAsset.setValue("migration-asset", forKey: "assetId")
        chainAsset.setValue(true, forKey: "isNative")
        chainAsset.setValue(false, forKey: "isUtility")
        chainAsset.setValue("normal", forKey: "type")
        chainAsset.setValue(asset, forKey: "asset")
        chainAsset.setValue(chain, forKey: "chain")

        if includeNilAssetWrapper {
            let nilAssetWrapper = NSManagedObject(
                entity: chainAssetEntity,
                insertInto: context
            )
            nilAssetWrapper.setValue("missing-asset", forKey: "assetId")
            nilAssetWrapper.setValue(chain, forKey: "chain")
        }
    }

    private func insertLegacyOrphanAsset(
        in context: NSManagedObjectContext,
        model: NSManagedObjectModel
    ) throws {
        let assetEntity = try XCTUnwrap(model.entitiesByName["CDAsset"])
        let asset = NSManagedObject(entity: assetEntity, insertInto: context)
        asset.setValue("orphan-chain", forKey: "chainId")
        asset.setValue("orphan-asset", forKey: "id")
        asset.setValue(Int16(12), forKey: "precision")
        asset.setValue("ORP", forKey: "symbol")
    }

    private func assertAdversarialTransformableMigration(
        sourceVersion: SubstrateStorageVersion,
        updateSQL: String,
        expectedDefaultedKeys: Set<String>
    ) throws {
        let sourceModel = try model(for: sourceVersion)
        try createStore(at: storeURL, model: sourceModel) { context in
            try self.insertTransformableAndProtectedGraph(
                in: context,
                model: sourceModel
            )
        }
        try executeSQLite(updateSQL, at: storeURL)

        try makeMigrator().performMigration()

        try assertMigratedTransformableAndProtectedGraph(
            expectedDefaultedKeys: expectedDefaultedKeys
        )
    }

    private func insertTransformableAndProtectedGraph(
        in context: NSManagedObjectContext,
        model: NSManagedObjectModel
    ) throws {
        let chain = try insert(
            entityName: "CDChain",
            in: context,
            model: model
        )
        chain.setValue("protected-transformable-chain", forKey: "chainId")
        chain.setValue("Protected Transformable Chain", forKey: "name")
        chain.setValue(
            NSArray(object: "chain-option"),
            forKey: "options"
        )

        let defaultNode = try insert(
            entityName: "CDChainNode",
            in: context,
            model: model
        )
        defaultNode.setValue("Default Node", forKey: "name")
        defaultNode.setValue(
            try XCTUnwrap(URL(string: "wss://default-node.example.invalid")),
            forKey: "url"
        )
        defaultNode.setValue("default-key", forKey: "apiKeyName")
        defaultNode.setValue("default-query", forKey: "apiQueryName")
        defaultNode.setValue(chain, forKey: "chain")

        let customNode = try insert(
            entityName: "CDChainNode",
            in: context,
            model: model
        )
        customNode.setValue("Custom Node", forKey: "name")
        customNode.setValue(
            try XCTUnwrap(URL(string: "wss://custom-node.example.invalid")),
            forKey: "url"
        )
        customNode.setValue("custom-key", forKey: "apiKeyName")
        customNode.setValue("custom-query", forKey: "apiQueryName")
        chain.mutableSetValue(forKey: "customNodes").add(customNode)
        chain.setValue(customNode, forKey: "selectedNode")

        let asset = try insert(
            entityName: "CDAsset",
            in: context,
            model: model
        )
        asset.setValue("protected-asset", forKey: "id")
        asset.setValue(Int16(12), forKey: "precision")
        if asset.entity.attributesByName["chainId"] != nil {
            asset.setValue(
                "protected-transformable-chain",
                forKey: "chainId"
            )
        }
        if asset.entity.attributesByName["symbol"] != nil {
            asset.setValue("SAFE", forKey: "symbol")
        }

        if model.entitiesByName["CDChainAsset"] != nil {
            let wrapper = try insert(
                entityName: "CDChainAsset",
                in: context,
                model: model
            )
            wrapper.setValue("protected-asset", forKey: "assetId")
            wrapper.setValue(true, forKey: "isNative")
            wrapper.setValue(false, forKey: "isUtility")
            wrapper.setValue("normal", forKey: "type")
            wrapper.setValue(
                NSArray(object: "provider-a"),
                forKey: "purchaseProviders"
            )
            wrapper.setValue(asset, forKey: "asset")
            wrapper.setValue(chain, forKey: "chain")
        } else {
            asset.setValue(
                NSArray(object: "provider-a"),
                forKey: "purchaseProviders"
            )
            chain.mutableSetValue(forKey: "assets").add(asset)
        }

        let explorer = try insert(
            entityName: "CDExternalApi",
            in: context,
            model: model
        )
        explorer.setValue("subscan", forKey: "type")
        explorer.setValue("https://explorer.example.invalid", forKey: "url")
        explorer.setValue(
            NSArray(object: "explorer-type"),
            forKey: "types"
        )
        explorer.setValue(chain, forKey: "chain")

        let polkaswap = try insert(
            entityName: "CDPolkaswapRemoteSettings",
            in: context,
            model: model
        )
        polkaswap.setValue("protected-v1", forKey: "version")
        polkaswap.setValue(
            NSArray(object: "source-a"),
            forKey: "availableSources"
        )
        polkaswap.setValue(
            NSArray(object: "smart-a"),
            forKey: "forceSmartIds"
        )
        polkaswap.setValue(NSSet(), forKey: "availableDexIds")

        let xcmConfig = try insert(
            entityName: "CDChainXcmConfig",
            in: context,
            model: model
        )
        xcmConfig.setValue("v3", forKey: "xcmVersion")
        xcmConfig.setValue(
            NSArray(object: "XCM-A"),
            forKey: "availableAssets"
        )
        xcmConfig.setValue(chain, forKey: "chain")

        let xcmDestination = try insert(
            entityName: "CDXcmAvailableDestination",
            in: context,
            model: model
        )
        xcmDestination.setValue(
            "destination-chain",
            forKey: "chainId"
        )
        xcmDestination.setValue(
            NSArray(object: "XCM-B"),
            forKey: "assets"
        )
        xcmDestination.setValue(xcmConfig, forKey: "config")

        let contact = try insert(
            entityName: "CDContact",
            in: context,
            model: model
        )
        contact.setValue("Protected Contact", forKey: "name")
        contact.setValue("contact-address", forKey: "address")
        contact.setValue(
            "protected-transformable-chain",
            forKey: "chainId"
        )

        let contactItem = try insert(
            entityName: "CDContactItem",
            in: context,
            model: model
        )
        contactItem.setValue("contact-item", forKey: "identifier")
        contactItem.setValue("peer-address", forKey: "peerAddress")
        contactItem.setValue("Peer Name", forKey: "peerName")
        contactItem.setValue("target-address", forKey: "targetAddress")
        contactItem.setValue(Int64(1_234_567), forKey: "updatedAt")

        let history = try insert(
            entityName: "CDTransactionHistoryItem",
            in: context,
            model: model
        )
        history.setValue("balances", forKey: "moduleName")
        history.setValue("transfer", forKey: "callName")
        history.setValue("history-id", forKey: "identifier")
        history.setValue("sender-address", forKey: "sender")
        history.setValue("receiver-address", forKey: "receiver")
        history.setValue("10", forKey: "fee")
        history.setValue(Data([0x01, 0x02, 0xFF]), forKey: "call")
        history.setValue(Int64(42), forKey: "blockNumber")
        history.setValue(Int64(1_234_568), forKey: "timestamp")
        history.setValue(Int16(7), forKey: "txIndex")
        history.setValue(Int16(1), forKey: "status")
    }

    private func assertMigratedTransformableAndProtectedGraph(
        expectedDefaultedKeys: Set<String>
    ) throws {
        let targetModel = try model(for: .version8)
        try inspectStore(at: storeURL, model: targetModel) { context in
            let chain = try self.fetchSingleObject(
                entityName: "CDChain",
                context: context
            )
            XCTAssertEqual(
                try self.stringArray(in: chain, key: "options"),
                expectedDefaultedKeys.contains("CDChain.options")
                    ? []
                    : ["chain-option"]
            )

            let defaultNodes = self.relationshipObjects(
                in: chain,
                key: "nodes"
            )
            let customNodes = self.relationshipObjects(
                in: chain,
                key: "customNodes"
            )
            let selectedNode = try XCTUnwrap(
                chain.value(forKey: "selectedNode") as? NSManagedObject
            )
            XCTAssertEqual(defaultNodes.count, 1)
            XCTAssertEqual(customNodes.count, 1)
            XCTAssertEqual(
                defaultNodes.first?.value(forKey: "name") as? String,
                "Default Node"
            )
            XCTAssertEqual(
                customNodes.first?.value(forKey: "name") as? String,
                "Custom Node"
            )
            XCTAssertEqual(
                selectedNode.value(forKey: "url") as? URL,
                URL(string: "wss://custom-node.example.invalid")
            )

            let asset = try XCTUnwrap(
                self.relationshipObjects(in: chain, key: "assets").first
            )
            XCTAssertEqual(
                try self.stringArray(
                    in: asset,
                    key: "purchaseProviders"
                ),
                expectedDefaultedKeys.contains(
                    "CDChainAsset.purchaseProviders"
                ) || expectedDefaultedKeys.contains(
                    "CDAsset.purchaseProviders"
                )
                    ? []
                    : ["provider-a"]
            )

            let explorer = try XCTUnwrap(
                self.relationshipObjects(
                    in: chain,
                    key: "explorers"
                ).first
            )
            XCTAssertEqual(
                try self.stringArray(in: explorer, key: "types"),
                expectedDefaultedKeys.contains("CDExternalApi.types")
                    ? []
                    : ["explorer-type"]
            )

            let polkaswap = try self.fetchSingleObject(
                entityName: "CDPolkaswapRemoteSettings",
                context: context
            )
            XCTAssertEqual(
                try self.stringArray(
                    in: polkaswap,
                    key: "availableSources"
                ),
                expectedDefaultedKeys.contains(
                    "CDPolkaswapRemoteSettings.availableSources"
                )
                    ? []
                    : ["source-a"]
            )
            XCTAssertEqual(
                try self.stringArray(
                    in: polkaswap,
                    key: "forceSmartIds"
                ),
                expectedDefaultedKeys.contains(
                    "CDPolkaswapRemoteSettings.forceSmartIds"
                )
                    ? []
                    : ["smart-a"]
            )

            let xcmConfig = try XCTUnwrap(
                chain.value(forKey: "xcmConfig") as? NSManagedObject
            )
            let configSymbols = self.relationshipObjects(
                in: xcmConfig,
                key: "availableAssets"
            ).compactMap { $0.value(forKey: "symbol") as? String }.sorted()
            XCTAssertEqual(
                configSymbols,
                expectedDefaultedKeys.contains(
                    "CDChainXcmConfig.availableAssets"
                )
                    ? []
                    : ["XCM-A"]
            )

            let destination = try XCTUnwrap(
                self.relationshipObjects(
                    in: xcmConfig,
                    key: "availableDestinations"
                ).first
            )
            let destinationSymbols = self.relationshipObjects(
                in: destination,
                key: "assets"
            ).compactMap { $0.value(forKey: "symbol") as? String }.sorted()
            XCTAssertEqual(
                destinationSymbols,
                expectedDefaultedKeys.contains(
                    "CDXcmAvailableDestination.assets"
                )
                    ? []
                    : ["XCM-B"]
            )

            let contact = try self.fetchSingleObject(
                entityName: "CDContact",
                context: context
            )
            XCTAssertEqual(
                contact.value(forKey: "name") as? String,
                "Protected Contact"
            )
            XCTAssertEqual(
                contact.value(forKey: "address") as? String,
                "contact-address"
            )

            let contactItem = try self.fetchSingleObject(
                entityName: "CDContactItem",
                context: context
            )
            XCTAssertEqual(
                contactItem.value(forKey: "peerName") as? String,
                "Peer Name"
            )
            XCTAssertEqual(
                contactItem.value(forKey: "targetAddress") as? String,
                "target-address"
            )

            let history = try self.fetchSingleObject(
                entityName: "CDTransactionHistoryItem",
                context: context
            )
            XCTAssertEqual(
                history.value(forKey: "identifier") as? String,
                "history-id"
            )
            XCTAssertEqual(
                history.value(forKey: "call") as? Data,
                Data([0x01, 0x02, 0xFF])
            )
        }
    }

    private func assertSourceProtectedGraphIsExact(
        at url: URL,
        model: NSManagedObjectModel
    ) throws {
        // This assertion intentionally verifies only the protected graph. The
        // caller has already compared every installed family byte. Inspect a
        // disposable copy after neutralizing the deliberately corrupt cache
        // transformable so Core Data cannot fault that unrelated column while
        // traversing relationships.
        let inspectionRootURL = testDirectory.appendingPathComponent(
            "ProtectedGraphInspection-\(UUID().uuidString)",
            isDirectory: true
        )
        let inspectionStoreURL = inspectionRootURL.appendingPathComponent(
            url.lastPathComponent
        )
        try FileManager.default.createDirectory(
            at: inspectionRootURL,
            withIntermediateDirectories: false
        )
        defer {
            try? FileManager.default.removeItem(at: inspectionRootURL)
        }

        for suffix in ["", "-wal", "-journal"] {
            let sourceURL = URL(
                fileURLWithPath: url.path + suffix
            )
            guard FileManager.default.fileExists(
                atPath: sourceURL.path
            ) else {
                continue
            }
            try FileManager.default.copyItem(
                at: sourceURL,
                to: URL(
                    fileURLWithPath: inspectionStoreURL.path + suffix
                )
            )
        }
        try executeSQLite(
            "UPDATE ZCDCHAIN SET ZOPTIONS = NULL",
            at: inspectionStoreURL
        )

        try inspectStore(at: inspectionStoreURL, model: model) { context in
            let chain = try self.fetchSingleObject(
                entityName: "CDChain",
                context: context
            )
            let defaultNodes = self.relationshipObjects(
                in: chain,
                key: "nodes"
            )
            let customNodes = self.relationshipObjects(
                in: chain,
                key: "customNodes"
            )
            XCTAssertEqual(defaultNodes.count, 1)
            XCTAssertEqual(customNodes.count, 1)
            XCTAssertEqual(
                defaultNodes.first?.value(forKey: "name") as? String,
                "Default Node"
            )
            XCTAssertEqual(
                customNodes.first?.value(forKey: "name") as? String,
                "Custom Node"
            )
            XCTAssertEqual(
                (chain.value(forKey: "selectedNode") as? NSManagedObject)?
                    .value(forKey: "name") as? String,
                "Custom Node"
            )

            let contact = try self.fetchSingleObject(
                entityName: "CDContact",
                context: context
            )
            XCTAssertEqual(
                contact.value(forKey: "name") as? String,
                "Protected Contact"
            )
            let history = try self.fetchSingleObject(
                entityName: "CDTransactionHistoryItem",
                context: context
            )
            XCTAssertEqual(
                history.value(forKey: "identifier") as? String,
                "history-id"
            )
        }
    }

    private func mutateStagedProtectedDataWithoutChangingRowCounts(
        at url: URL,
        model: NSManagedObjectModel
    ) throws {
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
        var mutationError: Error?
        context.performAndWait {
            do {
                let contact = try self.fetchSingleObject(
                    entityName: "CDContact",
                    context: context
                )
                contact.setValue(
                    "Same Count, Different Contact",
                    forKey: "name"
                )

                let chain = try self.fetchSingleObject(
                    entityName: "CDChain",
                    context: context
                )
                let defaultNode = try XCTUnwrap(
                    self.relationshipObjects(
                        in: chain,
                        key: "nodes"
                    ).first
                )
                chain.setValue(defaultNode, forKey: "selectedNode")
                try context.save()
            } catch {
                mutationError = error
            }
        }

        if let mutationError {
            throw mutationError
        }
    }

    private func fetchSingleObject(
        entityName: String,
        context: NSManagedObjectContext
    ) throws -> NSManagedObject {
        let request = NSFetchRequest<NSManagedObject>(
            entityName: entityName
        )
        request.fetchLimit = 2
        request.includesPendingChanges = false
        request.includesSubentities = false
        let objects = try context.fetch(request)
        XCTAssertEqual(objects.count, 1)
        return try XCTUnwrap(objects.first)
    }

    private func relationshipObjects(
        in object: NSManagedObject,
        key: String
    ) -> [NSManagedObject] {
        if let objects = object.value(forKey: key) as? Set<NSManagedObject> {
            return Array(objects)
        }
        if let objects = object.value(forKey: key) as? NSSet {
            return objects.compactMap { $0 as? NSManagedObject }
        }
        return []
    }

    private func stringArray(
        in object: NSManagedObject,
        key: String
    ) throws -> [String]? {
        try SafeTransformableValueReader.read(
            from: object,
            key: key
        )
    }

    private func hex(_ data: Data) -> String {
        data.map { String(format: "%02X", $0) }.joined()
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

    private func count(
        entityName: String,
        at url: URL,
        model: NSManagedObjectModel
    ) throws -> Int {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let store = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: url,
            options: [
                NSMigratePersistentStoresAutomaticallyOption: false,
                NSInferMappingModelAutomaticallyOption: false
            ]
        )
        defer {
            try? coordinator.remove(store)
        }

        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator

        var result: Result<Int, Error>!
        context.performAndWait {
            result = Result {
                let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                return try context.count(for: request)
            }
        }

        return try result.get()
    }

    private func isStore(
        at url: URL,
        compatibleWith model: NSManagedObjectModel,
        version: SubstrateStorageVersion
    ) throws -> Bool {
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType,
            at: url,
            options: nil
        )

        return model.isConfiguration(
            withName: version.rawValue,
            compatibleWithStoreMetadata: metadata
        )
    }

    private func flattenedErrorDescriptions(_ error: Error) -> [String] {
        let nsError = error as NSError
        var descriptions = [nsError.localizedDescription]

        if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            descriptions.append(contentsOf: flattenedErrorDescriptions(underlyingError))
        }

        if let detailedErrors = nsError.userInfo[NSDetailedErrorsKey] as? [Error] {
            for detailedError in detailedErrors {
                descriptions.append(contentsOf: flattenedErrorDescriptions(detailedError))
            }
        }

        return descriptions
    }

    private func makeUnknownModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        let entity = NSEntityDescription()
        entity.name = "UnknownSubstrateCache"
        entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

        let identifier = NSAttributeDescription()
        identifier.name = "identifier"
        identifier.attributeType = .stringAttributeType
        identifier.isOptional = true
        entity.properties = [identifier]
        model.entities = [entity]

        return model
    }

    private func makeModelBundle(
        omitting omittedVersion: SubstrateStorageVersion? = nil
    ) throws -> Bundle {
        let bundleURL = testDirectory.appendingPathComponent(
            "SubstrateModels-\(UUID().uuidString).bundle",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: bundleURL,
            withIntermediateDirectories: true
        )

        let infoPlist: [String: Any] = [
            "CFBundleIdentifier": "jp.co.soramitsu.fearlesswallet.tests.substrate-models.\(UUID().uuidString)",
            "CFBundleName": "SubstrateModels",
            "CFBundlePackageType": "BNDL",
            "CFBundleVersion": "1"
        ]
        let infoData = try PropertyListSerialization.data(
            fromPropertyList: infoPlist,
            format: .xml,
            options: 0
        )
        try infoData.write(to: bundleURL.appendingPathComponent("Info.plist"))

        let sourceModelDirectory = try XCTUnwrap(
            appBundle.url(
                forResource: "SubstrateDataModel",
                withExtension: "momd"
            )
        )
        let destinationModelDirectory = bundleURL.appendingPathComponent(
            SubstrateStorageParams.modelDirectory,
            isDirectory: true
        )
        try FileManager.default.copyItem(
            at: sourceModelDirectory,
            to: destinationModelDirectory
        )

        if let omittedVersion {
            for fileExtension in ["omo", "mom"] {
                let omittedModelURL = destinationModelDirectory.appendingPathComponent(
                    "\(omittedVersion.rawValue).\(fileExtension)"
                )
                if FileManager.default.fileExists(atPath: omittedModelURL.path) {
                    try FileManager.default.removeItem(at: omittedModelURL)
                }
            }
        }

        return try XCTUnwrap(Bundle(url: bundleURL))
    }

    private func durableStoreFamilySnapshot(at url: URL) throws -> [String: Data] {
        let fileNames = try FileManager.default.contentsOfDirectory(
            atPath: url.deletingLastPathComponent().path
        ).filter {
            $0.hasPrefix(url.lastPathComponent)
        }

        return try Dictionary(
            uniqueKeysWithValues: fileNames.map { fileName in
                let fileURL = url.deletingLastPathComponent().appendingPathComponent(fileName)
                return (fileName, try Data(contentsOf: fileURL))
            }
        )
    }

    private func installRealSQLiteFamilyWithUncheckpointedWAL(
        at url: URL
    ) throws {
        let snapshotDirectoryURL = testDirectory.appendingPathComponent(
            "RealSQLiteWALSnapshot-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: snapshotDirectoryURL,
            withIntermediateDirectories: false
        )
        defer {
            try? FileManager.default.removeItem(
                at: snapshotDirectoryURL
            )
        }

        var database: OpaquePointer?
        let openResult = sqlite3_open_v2(
            url.path,
            &database,
            SQLITE_OPEN_READWRITE,
            nil
        )
        guard openResult == SQLITE_OK, let database else {
            defer {
                if let database {
                    sqlite3_close(database)
                }
            }
            throw NSError(
                domain: "SubstrateStorageMigrationSafetyTests.SQLite",
                code: Int(openResult),
                userInfo: [
                    NSLocalizedDescriptionKey:
                    "Unable to open real SQLite WAL fixture"
                ]
            )
        }

        do {
            try executeSQLite(
                """
                PRAGMA journal_mode=WAL;
                PRAGMA wal_autocheckpoint=0;
                CREATE TABLE IF NOT EXISTS ZFEARLESSRECOVERYPROBE (
                    ZVALUE INTEGER NOT NULL
                );
                BEGIN IMMEDIATE;
                INSERT INTO ZFEARLESSRECOVERYPROBE (ZVALUE) VALUES (1);
                COMMIT;
                """,
                database: database
            )

            for suffix in ["", "-wal", "-shm", "-journal"] {
                let sourceURL = URL(
                    fileURLWithPath: url.path + suffix
                )
                guard FileManager.default.fileExists(
                    atPath: sourceURL.path
                ) else {
                    continue
                }
                try FileManager.default.copyItem(
                    at: sourceURL,
                    to: snapshotDirectoryURL.appendingPathComponent(
                        sourceURL.lastPathComponent
                    )
                )
            }
        } catch {
            sqlite3_close(database)
            throw error
        }
        sqlite3_close(database)

        for suffix in ["", "-wal", "-shm", "-journal"] {
            let familyURL = URL(
                fileURLWithPath: url.path + suffix
            )
            if FileManager.default.fileExists(
                atPath: familyURL.path
            ) {
                try FileManager.default.removeItem(at: familyURL)
            }

            let snapshotURL = snapshotDirectoryURL
                .appendingPathComponent(
                    familyURL.lastPathComponent
                )
            if FileManager.default.fileExists(
                atPath: snapshotURL.path
            ) {
                try FileManager.default.copyItem(
                    at: snapshotURL,
                    to: familyURL
                )
            }
        }
    }

    private func sqliteInteger(
        _ sql: String,
        at url: URL
    ) throws -> Int64 {
        var database: OpaquePointer?
        let openResult = sqlite3_open_v2(
            url.path,
            &database,
            SQLITE_OPEN_READONLY,
            nil
        )
        guard openResult == SQLITE_OK, let database else {
            defer {
                if let database {
                    sqlite3_close(database)
                }
            }
            throw NSError(
                domain: "SubstrateStorageMigrationSafetyTests.SQLite",
                code: Int(openResult),
                userInfo: [
                    NSLocalizedDescriptionKey:
                    "Unable to open SQLite integer query"
                ]
            )
        }
        defer {
            sqlite3_close(database)
        }

        var statement: OpaquePointer?
        let prepareResult = sqlite3_prepare_v2(
            database,
            sql,
            -1,
            &statement,
            nil
        )
        guard prepareResult == SQLITE_OK, let statement else {
            throw NSError(
                domain: "SubstrateStorageMigrationSafetyTests.SQLite",
                code: Int(prepareResult),
                userInfo: [
                    NSLocalizedDescriptionKey:
                    "Unable to prepare SQLite integer query"
                ]
            )
        }
        defer {
            sqlite3_finalize(statement)
        }

        let stepResult = sqlite3_step(statement)
        guard stepResult == SQLITE_ROW else {
            throw NSError(
                domain: "SubstrateStorageMigrationSafetyTests.SQLite",
                code: Int(stepResult),
                userInfo: [
                    NSLocalizedDescriptionKey:
                    "SQLite integer query returned no row"
                ]
            )
        }

        return sqlite3_column_int64(statement, 0)
    }

    private func executeSQLite(
        _ sql: String,
        database: OpaquePointer
    ) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?
        let executionResult = sqlite3_exec(
            database,
            sql,
            nil,
            nil,
            &errorMessage
        )
        defer {
            sqlite3_free(errorMessage)
        }

        guard executionResult == SQLITE_OK else {
            let message = errorMessage
                .map { String(cString: $0) } ??
                "unknown SQLite execution error"
            throw NSError(
                domain: "SubstrateStorageMigrationSafetyTests.SQLite",
                code: Int(executionResult),
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }
    }

    private func executeSQLite(_ sql: String, at url: URL) throws {
        var database: OpaquePointer?
        let openResult = sqlite3_open_v2(
            url.path,
            &database,
            SQLITE_OPEN_READWRITE,
            nil
        )

        guard openResult == SQLITE_OK, let database else {
            defer {
                if let database {
                    sqlite3_close(database)
                }
            }

            let message = database
                .flatMap(sqlite3_errmsg)
                .map { String(cString: $0) } ?? "unknown SQLite open error"
            throw NSError(
                domain: "SubstrateStorageMigrationSafetyTests.SQLite",
                code: Int(openResult),
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }
        defer {
            sqlite3_close(database)
        }

        try executeSQLite(sql, database: database)
    }

    private func recoveryDirectories() throws -> [URL] {
        let recoveryRoot = testDirectory.appendingPathComponent(
            "SubstrateStoreRecovery",
            isDirectory: true
        )
        guard FileManager.default.fileExists(atPath: recoveryRoot.path) else {
            return []
        }

        return try FileManager.default.contentsOfDirectory(
            at: recoveryRoot,
            includingPropertiesForKeys: nil
        ).sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}

@objc(FearlessTestsDroppingAssetMigrationPolicy)
private final class DroppingAssetMigrationPolicy: NSEntityMigrationPolicy {
    override func createDestinationInstances(
        forSource _: NSManagedObject,
        in _: NSEntityMapping,
        manager _: NSMigrationManager
    ) throws {}
}

private class TemporaryStoreFootprintFileManager: FileManager {
    private var sourceRoots = Set<URL>()

    private(set) var maximumTemporaryMainStoreCount = 0
    private(set) var temporaryMainStoreCountsBeforeRemoval: [Int] = []
    private(set) var removedTemporaryMainStoreCount = 0
    private(set) var copiedSharedMemorySidecar = false

    var temporaryRootsAreClean: Bool {
        sourceRoots.allSatisfy {
            !FileManager.default.fileExists(atPath: $0.path)
        }
    }

    override init() {
        super.init()
    }

    required init?(coder _: NSCoder) {
        nil
    }

    override func createDirectory(
        at url: URL,
        withIntermediateDirectories createIntermediates: Bool,
        attributes: [FileAttributeKey: Any]? = nil
    ) throws {
        try super.createDirectory(
            at: url,
            withIntermediateDirectories: createIntermediates,
            attributes: attributes
        )

        if url.lastPathComponent.hasPrefix("SubstrateStorageSource-") {
            sourceRoots.insert(url.standardizedFileURL)
        }

        sampleTemporaryStoreCount()
    }

    override func copyItem(at sourceURL: URL, to destinationURL: URL) throws {
        try super.copyItem(at: sourceURL, to: destinationURL)

        if
            trackedSourceRoot(containing: destinationURL) != nil,
            sourceURL.lastPathComponent.hasSuffix("-shm")
        {
            copiedSharedMemorySidecar = true
        }

        sampleTemporaryStoreCount()
    }

    override func removeItem(at url: URL) throws {
        let removesTemporaryMainStore = isTrackedTemporaryMainStore(url)

        if removesTemporaryMainStore {
            sampleTemporaryStoreCount()
            temporaryMainStoreCountsBeforeRemoval.append(
                temporaryMainStoreCount()
            )
        }

        try super.removeItem(at: url)

        if removesTemporaryMainStore {
            removedTemporaryMainStoreCount += 1
        }

        sampleTemporaryStoreCount()
    }

    func isTrackedTemporaryMainStore(_ url: URL) -> Bool {
        trackedSourceRoot(containing: url) != nil &&
            url.pathExtension == "sqlite"
    }

    private func trackedSourceRoot(containing url: URL) -> URL? {
        let standardizedPath = url.standardizedFileURL.path

        return sourceRoots.first { root in
            standardizedPath == root.path ||
                standardizedPath.hasPrefix(root.path + "/")
        }
    }

    private func sampleTemporaryStoreCount() {
        maximumTemporaryMainStoreCount = max(
            maximumTemporaryMainStoreCount,
            temporaryMainStoreCount()
        )
    }

    private func temporaryMainStoreCount() -> Int {
        sourceRoots.reduce(into: 0) { count, root in
            guard
                FileManager.default.fileExists(atPath: root.path),
                let enumerator = FileManager.default.enumerator(
                    at: root,
                    includingPropertiesForKeys: nil
                )
            else {
                return
            }

            while let fileURL = enumerator.nextObject() as? URL {
                if fileURL.pathExtension == "sqlite" {
                    count += 1
                }
            }
        }
    }
}

private final class FailingTemporaryStoreCleanupFileManager:
    TemporaryStoreFootprintFileManager
{
    private(set) var didInjectCleanupFailure = false

    override func removeItem(at url: URL) throws {
        if !didInjectCleanupFailure, isTrackedTemporaryMainStore(url) {
            didInjectCleanupFailure = true
            throw InjectedSubstrateTemporaryCleanupError.failure
        }

        try super.removeItem(at: url)
    }
}

private enum InjectedSubstrateStoreReplacementError: Error {
    case failure
}

private enum InjectedSubstrateCheckpointError: Error {
    case failure
}

private enum InjectedSubstrateTemporaryCleanupError: Error {
    case failure
}

private enum InjectedSubstrateBackupExclusionError: Error {
    case failure
}

@objc(FearlessTestsDisallowedSubstrateTransformablePayload)
private final class DisallowedSubstrateTransformablePayload: NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool {
        true
    }

    let value: String

    init(value: String) {
        self.value = value
        super.init()
    }

    required init?(coder: NSCoder) {
        guard let value = coder.decodeObject(
            of: NSString.self,
            forKey: "value"
        ) as? String else {
            return nil
        }

        self.value = value
        super.init()
    }

    func encode(with coder: NSCoder) {
        coder.encode(value as NSString, forKey: "value")
    }
}
