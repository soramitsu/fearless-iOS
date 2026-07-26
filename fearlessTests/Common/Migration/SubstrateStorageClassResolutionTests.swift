import CoreData
import CryptoKit
import RobinHood
import SSFModels
import XCTest
@testable import fearless

#if canImport(SSFAssetManagmentStorage)
    import SSFAssetManagmentStorage
    private typealias TestCDScamInfo = SSFAssetManagmentStorage.CDScamInfo
#else
    private typealias TestCDScamInfo = fearless.SSFAssetManagmentStorageStub.CDScamInfo
#endif

final class SubstrateStorageClassResolutionTests: XCTestCase {
    private struct EntityClassExpectation {
        let entityName: String
        let managedObjectClass: NSManagedObject.Type
    }

    private struct RuntimeProjection: Codable {
        let chain: String
        let version: UInt32
        let txVersion: UInt32
        let metadataDigest: Data

        var sortKey: [String] {
            [
                chain,
                String(version),
                String(txVersion),
                metadataDigest.base64EncodedString()
            ]
        }
    }

    private struct NodeProjection: Codable {
        let url: String
        let name: String
        let apiQueryName: String?
        let apiKeyName: String?

        var sortKey: [String] {
            [
                url,
                name,
                apiQueryName ?? "",
                apiKeyName ?? ""
            ]
        }
    }

    private struct ChainProjection: Codable {
        let chainId: String
        let name: String
        let disabled: Bool
        let assetIds: [String]
        let nodes: [NodeProjection]
        let customNodes: [NodeProjection]
        let selectedNode: NodeProjection?

        var sortKey: [String] {
            [chainId, name]
        }
    }

    private struct RepositoryProjection: Codable {
        let runtimes: [RuntimeProjection]
        let chains: [ChainProjection]
    }

    private struct RepositoryAggregate: Equatable {
        let runtimeCount: Int
        let chainCount: Int
        let enabledChainCount: Int
        let assetCount: Int
        let nodeCount: Int
        let defaultNodeRelationshipCount: Int
        let customNodeRelationshipCount: Int
        let selectedNodeRelationshipCount: Int
        let standaloneSelectedNodeCount: Int
        let fingerprint: Data
    }

    private let expectedEntityVersionHashes = [
        "CDAsset": "OaCdB9COHi79/aWro7D/NMuFpNBI0ZFzrprILS+KmP8=",
        "CDChain": "xuYLmoPjdtSUBxBnb6XTrlVhylYyXA8GEw4KmzL1b+I=",
        "CDChainNode": "ss/vV1rML8kMdjwg0WBlnN+nUfbimb+iS858b2UC5co=",
        "CDChainStorageItem": "tl1izvM2Yua6zVUkbOKhur324LSAxJOj9/M+5iRiFa4=",
        "CDChainXcmConfig": "0HjIIf+quGUJQ/o84PdC5mHNcC86v1mrG2sBdayWiso=",
        "CDContact": "DXCWS/mWPGoVysoTZy+8QKx6H5KWgV7GhaJRQRHUE3c=",
        "CDContactItem": "a1f9E6n04Dw2O8avnrKh71ChA215v4tanvXG60z6M3k=",
        "CDExternalApi": "n4a9GYGVRmIwWteJEbC7nUd8PyzyJ7xd+AvVlG2BGvw=",
        "CDPhishingItem": "rLQn++gZqmY/EmPOCkDFxCvVXhp2Hs+ZYah6D4p9JIk=",
        "CDPolkaswapDex": "jU4M5szChWjMy/D1+IUOp1fz4qD5u4oehrmgVQ3Wel8=",
        "CDPolkaswapRemoteSettings": "EwsBHlXIiySVJAormij6pHo0OtZz4gJLtHcCV8od1+k=",
        "CDPriceData": "63ioMabYdLDL8vNP5aK563PaV6dPU9qUvjzPxD7aOPU=",
        "CDPriceProvider": "zOsAxjSu9EHzLSO95UpY38tE4XkbWUwDExKBjlM26jA=",
        "CDRuntimeMetadataItem": "lmOvdNZxh3zLwJN+6ZlUcLvB9HRBv9PYHbJt4QE07oY=",
        "CDScamInfo": "pjD63BxcBAQfhasAHmj+ew7KQncf9FU1ftTpGKFEcsw=",
        "CDStashItem": "DmeVbIKcFdGMSBvSoYHdRuDBurJHUWE2vAWz1Hbgl34=",
        "CDTransactionHistoryItem": "5kc1p0hvfdoQDmabJaZ9pIRWCJa40tpLtCvwVjtnPdU=",
        "CDXcmAvailableAsset": "JKPl407BzEYe3ztSezxPOv9Z9WAhoGsJlevWpgPn7Es=",
        "CDXcmAvailableDestination": "yD9mzh4EBjT1sFrqYgDIDNUlrUyxQJ81S4GZXpIZi74="
    ]

    private var appBundle: Bundle {
        Bundle(for: SubstrateDataStorageFacade.self)
    }

    private var fallbackEntityClasses: [EntityClassExpectation] {
        [
            EntityClassExpectation(entityName: "CDAsset", managedObjectClass: fearless.CDAsset.self),
            EntityClassExpectation(entityName: "CDChain", managedObjectClass: fearless.CDChain.self),
            EntityClassExpectation(entityName: "CDChainNode", managedObjectClass: fearless.CDChainNode.self),
            EntityClassExpectation(
                entityName: "CDChainStorageItem",
                managedObjectClass: fearless.CDChainStorageItem.self
            ),
            EntityClassExpectation(
                entityName: "CDChainXcmConfig",
                managedObjectClass: fearless.CDChainXcmConfig.self
            ),
            EntityClassExpectation(entityName: "CDContact", managedObjectClass: fearless.CDContact.self),
            EntityClassExpectation(
                entityName: "CDContactItem",
                managedObjectClass: fearless.CDContactItem.self
            ),
            EntityClassExpectation(
                entityName: "CDExternalApi",
                managedObjectClass: fearless.CDExternalApi.self
            ),
            EntityClassExpectation(
                entityName: "CDPhishingItem",
                managedObjectClass: fearless.CDPhishingItem.self
            ),
            EntityClassExpectation(
                entityName: "CDPolkaswapDex",
                managedObjectClass: polkaswapDexClass
            ),
            EntityClassExpectation(
                entityName: "CDPolkaswapRemoteSettings",
                managedObjectClass: fearless.CDPolkaswapRemoteSettings.self
            ),
            EntityClassExpectation(
                entityName: "CDPriceData",
                managedObjectClass: fearless.CDPriceData.self
            ),
            EntityClassExpectation(
                entityName: "CDPriceProvider",
                managedObjectClass: fearless.CDPriceProvider.self
            ),
            EntityClassExpectation(
                entityName: "CDRuntimeMetadataItem",
                managedObjectClass: fearless.CDRuntimeMetadataItem.self
            ),
            EntityClassExpectation(entityName: "CDScamInfo", managedObjectClass: scamInfoClass),
            EntityClassExpectation(
                entityName: "CDStashItem",
                managedObjectClass: fearless.CDStashItem.self
            ),
            EntityClassExpectation(
                entityName: "CDXcmAvailableAsset",
                managedObjectClass: fearless.CDXcmAvailableAsset.self
            ),
            EntityClassExpectation(
                entityName: "CDXcmAvailableDestination",
                managedObjectClass: fearless.CDXcmAvailableDestination.self
            )
        ]
    }

    private var expectedEntityClasses: [EntityClassExpectation] {
        fallbackEntityClasses + [
            EntityClassExpectation(
                entityName: "CDTransactionHistoryItem",
                managedObjectClass: fearless.CDTransactionHistoryItem.self
            )
        ]
    }

    private var polkaswapDexClass: NSManagedObject.Type {
        #if canImport(SSFAssetManagmentStorage)
            SSFAssetManagmentStorage.CDPolkaswapDex.self
        #else
            fearless.SSFAssetManagmentStorageStub.CDPolkaswapDex.self
        #endif
    }

    private var scamInfoClass: NSManagedObject.Type {
        #if canImport(SSFAssetManagmentStorage)
            SSFAssetManagmentStorage.CDScamInfo.self
        #else
            fearless.SSFAssetManagmentStorageStub.CDScamInfo.self
        #endif
    }

    func testBundledV8Model_whenLoaded_thenEveryEntityResolvesToExactRuntimeClass() throws {
        let model = try loadBundledV8Model()

        XCTAssertEqual(fallbackEntityClasses.count, 18)
        XCTAssertEqual(
            Set(model.entitiesByName.keys),
            Set(expectedEntityClasses.map(\.entityName))
        )

        for expectation in expectedEntityClasses {
            let entity = try XCTUnwrap(model.entitiesByName[expectation.entityName])
            let className = try XCTUnwrap(entity.managedObjectClassName)
            let resolvedClass = try XCTUnwrap(
                NSClassFromString(className) as? NSManagedObject.Type,
                "\(className) must resolve to an NSManagedObject subclass"
            )

            XCTAssertEqual(
                className,
                NSStringFromClass(expectation.managedObjectClass),
                "\(expectation.entityName) does not use the expected Objective-C runtime name"
            )
            XCTAssertEqual(
                ObjectIdentifier(resolvedClass),
                ObjectIdentifier(expectation.managedObjectClass),
                "\(expectation.entityName) resolves to a different class than its app alias"
            )
        }
    }

    func testBundledV8Model_whenObjectsInsertedAndFetched_thenUsesExactRuntimeClasses() throws {
        let model = try loadBundledV8Model()
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try coordinator.addPersistentStore(
            ofType: NSInMemoryStoreType,
            configurationName: nil,
            at: nil
        )

        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator

        try performAndWait(in: context) {
            for expectation in self.expectedEntityClasses {
                let insertedObject = NSEntityDescription.insertNewObject(
                    forEntityName: expectation.entityName,
                    into: context
                )

                self.assertExactClass(
                    of: insertedObject,
                    is: expectation.managedObjectClass,
                    entityName: expectation.entityName
                )

                let request = NSFetchRequest<NSManagedObject>(entityName: expectation.entityName)
                let fetchedObjects = try context.fetch(request)
                let fetchedObject = try XCTUnwrap(
                    fetchedObjects.first { $0 === insertedObject },
                    "Inserted \(expectation.entityName) was not returned by its fetch"
                )

                self.assertExactClass(
                    of: fetchedObject,
                    is: expectation.managedObjectClass,
                    entityName: expectation.entityName
                )
            }

            context.rollback()
        }
    }

    func testRuntimeMetadata_whenPersisted_thenCodableMapperRoundTripsBoundaryVersions() throws {
        let model = try loadBundledV8Model()
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try coordinator.addPersistentStore(
            ofType: NSInMemoryStoreType,
            configurationName: nil,
            at: nil
        )

        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator

        let expectedItem = fearless.RuntimeMetadataItem(
            chain: "class-resolution-regression",
            version: UInt32.max,
            txVersion: UInt32(Int32.max) + 1,
            metadata: Data([0x00, 0x7F, 0x80, 0xFF])
        )
        let mapper = fearless.RuntimeMetadataMapper()

        try performAndWait(in: context) {
            let insertedObject = try XCTUnwrap(
                NSEntityDescription.insertNewObject(
                    forEntityName: "CDRuntimeMetadataItem",
                    into: context
                ) as? fearless.CDRuntimeMetadataItem
            )

            try mapper.populate(entity: insertedObject, from: expectedItem, using: context)
            try context.save()
            context.reset()

            let request = NSFetchRequest<fearless.CDRuntimeMetadataItem>(
                entityName: "CDRuntimeMetadataItem"
            )
            let persistedObject = try XCTUnwrap(context.fetch(request).first)

            self.assertExactClass(
                of: persistedObject,
                is: fearless.CDRuntimeMetadataItem.self,
                entityName: "CDRuntimeMetadataItem"
            )
            XCTAssertEqual(try mapper.transform(entity: persistedObject), expectedItem)
        }
    }

    func testRuntimeMetadataStartupMapper_whenGetterRaises_thenReturnsSanitizedSwiftError() {
        let entityDescription = NSEntityDescription()
        entityDescription.name =
            "RuntimeMetadataGetterExceptionFixture"
        entityDescription.managedObjectClassName =
            NSStringFromClass(
                fearless.CDRuntimeMetadataItem.self
            )
        entityDescription.properties = []
        let entity = fearless.CDRuntimeMetadataItem(
            entity: entityDescription,
            insertInto: nil
        )
        let mapper: AnyCoreDataMapper<
            fearless.RuntimeMetadataItem,
            fearless.CDRuntimeMetadataItem
        > = AnyCoreDataMapper(
            fearless.RuntimeMetadataMapper()
        )

        XCTAssertThrowsError(
            try mapper.transform(entity: entity)
        ) { error in
            XCTAssertEqual(
                error as? SafeTransformableValueReaderError,
                .objectiveCException
            )
        }
    }

    func testRuntimeMetadataStartupMapper_whenSetterRaises_thenReturnsSanitizedSwiftError() {
        let entityDescription = NSEntityDescription()
        entityDescription.name =
            "RuntimeMetadataSetterExceptionFixture"
        entityDescription.managedObjectClassName =
            NSStringFromClass(
                fearless.CDRuntimeMetadataItem.self
            )
        entityDescription.properties = []
        let entity = fearless.CDRuntimeMetadataItem(
            entity: entityDescription,
            insertInto: nil
        )
        let mapper = fearless.RuntimeMetadataMapper()
        let model = fearless.RuntimeMetadataItem(
            chain: "setter-exception",
            version: 1,
            txVersion: 2,
            metadata: Data([0x01])
        )

        XCTAssertThrowsError(
            try mapper.populate(
                entity: entity,
                from: model,
                using: NSManagedObjectContext(
                    concurrencyType:
                    .mainQueueConcurrencyType
                )
            )
        ) { error in
            XCTAssertEqual(
                error as? SafeTransformableValueReaderError,
                .objectiveCException
            )
        }
    }

    func testFallbackCodableEntities_whenPersisted_thenTypedAccessorsAndMappersRoundTrip() throws {
        let context = try makeInMemoryContext()

        let chainStorage = ChainStorageItem(
            identifier: "chain-storage-🧪",
            data: Data([0x00, 0x7F, 0x80, 0xFF])
        )
        XCTAssertEqual(
            try roundTrip(
                chainStorage,
                entityName: "CDChainStorageItem",
                entityClass: fearless.CDChainStorageItem.self,
                in: context
            ),
            chainStorage
        )

        let stash = StashItem(
            stash: "stash-address-α",
            controller: "controller-address-β"
        )
        XCTAssertEqual(
            try roundTrip(
                stash,
                entityName: "CDStashItem",
                entityClass: fearless.CDStashItem.self,
                in: context
            ),
            stash
        )

        let phishing = PhishingItem(
            source: "https://security.example.invalid/list.json",
            publicKey: "0xPHISHING-PUBLIC-KEY"
        )
        let decodedPhishing = try roundTrip(
            phishing,
            entityName: "CDPhishingItem",
            entityClass: fearless.CDPhishingItem.self,
            in: context
        )
        XCTAssertEqual(decodedPhishing.identifier, phishing.identifier)
        XCTAssertEqual(decodedPhishing.source, phishing.source)
        XCTAssertEqual(decodedPhishing.publicKey, phishing.publicKey)

        let scam = ScamInfo(
            name: "Unicode scam 🚫",
            address: "0x0000000000000000000000000000000000000001",
            type: .lowScore,
            subtype: "adversarial-subtype"
        )
        XCTAssertEqual(
            try roundTrip(
                scam,
                entityName: "CDScamInfo",
                entityClass: TestCDScamInfo.self,
                in: context
            ),
            scam
        )

        let contact = Contact(
            name: "Alice 🧪",
            address: "1zugcac3aa3e6b4b32c48d0843ff91c7d6b07f9df4dbe3546b1bc472d29d6e56",
            chainId: "0x91b171bb158e2d3848fa23a9f1c25182"
        )
        XCTAssertEqual(
            try roundTrip(
                contact,
                entityName: "CDContact",
                entityClass: fearless.CDContact.self,
                in: context
            ),
            contact
        )

        let contactItem = ContactItem(
            peerAddress: "peer-address-\u{0000}-boundary",
            peerName: "Peer 🧪",
            targetAddress: "target-address",
            updatedAt: Int64.max
        )
        let decodedContactItem = try roundTrip(
            contactItem,
            entityName: "CDContactItem",
            entityClass: fearless.CDContactItem.self,
            in: context
        )
        XCTAssertEqual(decodedContactItem.identifier, contactItem.identifier)
        XCTAssertEqual(decodedContactItem.peerAddress, contactItem.peerAddress)
        XCTAssertEqual(decodedContactItem.peerName, contactItem.peerName)
        XCTAssertEqual(decodedContactItem.targetAddress, contactItem.targetAddress)
        XCTAssertEqual(decodedContactItem.updatedAt, contactItem.updatedAt)
    }

    func testFallbackCodableEntities_whenRequiredFieldsAreMissing_thenMappersRejectRows() throws {
        let context = try makeInMemoryContext()

        try performAndWait(in: context) {
            self.assertMalformedRowRejected(
                ChainStorageItem.self,
                entityName: "CDChainStorageItem",
                entityClass: fearless.CDChainStorageItem.self,
                in: context
            )
            self.assertMalformedRowRejected(
                StashItem.self,
                entityName: "CDStashItem",
                entityClass: fearless.CDStashItem.self,
                in: context
            )
            self.assertMalformedRowRejected(
                PhishingItem.self,
                entityName: "CDPhishingItem",
                entityClass: fearless.CDPhishingItem.self,
                in: context
            )
            self.assertMalformedRowRejected(
                ScamInfo.self,
                entityName: "CDScamInfo",
                entityClass: TestCDScamInfo.self,
                in: context
            )
            self.assertMalformedRowRejected(
                Contact.self,
                entityName: "CDContact",
                entityClass: fearless.CDContact.self,
                in: context
            )
            self.assertMalformedRowRejected(
                ContactItem.self,
                entityName: "CDContactItem",
                entityClass: fearless.CDContactItem.self,
                in: context
            )

            let invalidScam = try XCTUnwrap(
                NSEntityDescription.insertNewObject(
                    forEntityName: "CDScamInfo",
                    into: context
                ) as? TestCDScamInfo
            )
            invalidScam.setValue("name", forKey: "name")
            invalidScam.setValue("address", forKey: "address")
            invalidScam.setValue("not-a-valid-scam-type", forKey: "type")
            invalidScam.setValue("subtype", forKey: "subtype")

            let scamMapper = CodableCoreDataMapper<ScamInfo, TestCDScamInfo>()
            XCTAssertThrowsError(try scamMapper.transform(entity: invalidScam))

            context.rollback()
        }
    }

    func testBundledV8Model_whenStoreCreated_thenSchemaFingerprintsAndCompatibilityStayCanonical() throws {
        let model = try loadBundledV8Model()
        let hashesBeforeOpening = versionHashes(for: model)
        XCTAssertEqual(hashesBeforeOpening, expectedEntityVersionHashes)

        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SubstrateStorageClassResolutionTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directoryURL)
        }

        let storeURL = directoryURL.appendingPathComponent("SubstrateDataModel.sqlite")
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let store = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: [
                NSMigratePersistentStoresAutomaticallyOption: false,
                NSInferMappingModelAutomaticallyOption: false
            ]
        )
        try coordinator.remove(store)

        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType,
            at: storeURL,
            options: nil
        )

        XCTAssertEqual(versionHashes(for: model), hashesBeforeOpening)
        XCTAssertTrue(
            model.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
        )
        XCTAssertTrue(
            model.isConfiguration(
                withName: SubstrateStorageVersion.version8.rawValue,
                compatibleWithStoreMetadata: metadata
            )
        )
        XCTAssertEqual(
            metadata["NSStoreModelVersionChecksumKey"] as? String,
            "uCEwjJUN79CeWqRxzEihB72qcWaHALPET4ZxwIj+0zs="
        )
    }

    func testCopiedPhoneV8Store_whenAvailable_thenAllRowsHaveExpectedClassesAndStoreIsUnchanged() throws {
        let fixtureURL = copiedPhoneStoreFixtureURL()
        guard FileManager.default.fileExists(atPath: fixtureURL.path) else {
            throw XCTSkip("Optional copied-phone Substrate store fixture is unavailable")
        }

        let sourceFingerprintsBefore = try storeFingerprints(at: fixtureURL)
        let testStoreURL = try copyStoreFixtureToTemporaryDirectory(fixtureURL)
        defer {
            try? FileManager.default.removeItem(at: testStoreURL.deletingLastPathComponent())
        }

        let testStoreDigestBefore = try digest(of: testStoreURL)
        let metadataBefore = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType,
            at: testStoreURL,
            options: nil
        )
        let model = try loadBundledV8Model()

        XCTAssertTrue(
            model.isConfiguration(
                withName: SubstrateStorageVersion.version8.rawValue,
                compatibleWithStoreMetadata: metadataBefore
            )
        )

        let countsBefore = try inspectReadOnlyStore(
            at: testStoreURL,
            model: model,
            fetchEveryObject: true
        )
        let countsAfter = try inspectReadOnlyStore(
            at: testStoreURL,
            model: try loadBundledV8Model(),
            fetchEveryObject: false
        )
        let metadataAfter = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType,
            at: testStoreURL,
            options: nil
        )

        XCTAssertEqual(countsAfter, countsBefore)
        XCTAssertGreaterThan(countsBefore["CDRuntimeMetadataItem"] ?? 0, 0)
        XCTAssertEqual(
            metadataVersionHashes(metadataAfter),
            metadataVersionHashes(metadataBefore)
        )
        XCTAssertEqual(try digest(of: testStoreURL), testStoreDigestBefore)
        XCTAssertEqual(try storeFingerprints(at: fixtureURL), sourceFingerprintsBefore)
    }

    func testCopiedPhoneV8Store_whenFetchedThroughProductionRepositories_thenMapsEveryRuntimeAndChain() throws {
        let fixtureURL = copiedPhoneStoreFixtureURL()
        guard FileManager.default.fileExists(atPath: fixtureURL.path) else {
            throw XCTSkip("Optional copied-phone Substrate store fixture is unavailable")
        }

        let sourceFingerprintsBefore = try storeFingerprints(at: fixtureURL)
        let testStoreURL = try copyStoreFixtureToTemporaryDirectory(fixtureURL)
        defer {
            try? FileManager.default.removeItem(at: testStoreURL.deletingLastPathComponent())
        }
        let persistedAggregate = try inspectPersistedRepositoryAggregate(
            at: testStoreURL,
            model: try loadBundledV8Model()
        )

        let modelURL = try XCTUnwrap(
            appBundle.url(
                forResource: "SubstrateDataModel",
                withExtension: "momd"
            )
        )
        let settings = CoreDataPersistentSettings(
            databaseDirectory: testStoreURL.deletingLastPathComponent(),
            databaseName: testStoreURL.lastPathComponent,
            incompatibleModelStrategy: .ignore,
            options: [
                NSReadOnlyPersistentStoreOption: true,
                NSMigratePersistentStoresAutomaticallyOption: false,
                NSInferMappingModelAutomaticallyOption: false
            ]
        )
        let service = CoreDataService(
            configuration: CoreDataServiceConfiguration(
                modelURL: modelURL,
                storageType: .persistent(settings: settings)
            )
        )
        defer {
            try? service.close()
        }

        let runtimeRepository = CoreDataRepository<
            fearless.RuntimeMetadataItem,
            fearless.CDRuntimeMetadataItem
        >(
            databaseService: service,
            mapper: AnyCoreDataMapper(
                CodableCoreDataMapper<
                    fearless.RuntimeMetadataItem,
                    fearless.CDRuntimeMetadataItem
                >()
            )
        )
        let chainRepository = CoreDataRepository<ChainModel, fearless.CDChain>(
            databaseService: service,
            mapper: AnyCoreDataMapper(ChainModelMapper())
        )
        let operationQueue = OperationQueue()

        let runtimeOperation = runtimeRepository.fetchAllOperation(
            with: RepositoryFetchOptions()
        )
        operationQueue.addOperations([runtimeOperation], waitUntilFinished: true)
        let runtimes = try runtimeOperation.extractResultData(
            throwing: BaseOperationError.parentOperationCancelled
        )

        let chainOperation = chainRepository.fetchAllOperation(
            with: RepositoryFetchOptions()
        )
        operationQueue.addOperations([chainOperation], waitUntilFinished: true)
        let chains = try chainOperation.extractResultData(
            throwing: BaseOperationError.parentOperationCancelled
        )

        XCTAssertEqual(runtimes.count, 60)
        XCTAssertEqual(chains.count, 116)
        assertMappedRepositoryInvariants(runtimes: runtimes, chains: chains)

        let mappedAggregate = try repositoryAggregate(
            runtimes: runtimes.map(runtimeProjection),
            chains: chains.map(chainProjection),
            nodeCount: Set(
                chains.flatMap { allNodes(in: $0) }.map { $0.url.absoluteString }
            ).count,
            assetCount: chains.reduce(0) { $0 + $1.assets.count }
        )

        XCTAssertEqual(
            mappedAggregate,
            persistedAggregate,
            "Mapped repository aggregate differs from the disposable store without exposing row values"
        )
        XCTAssertEqual(try storeFingerprints(at: fixtureURL), sourceFingerprintsBefore)
    }

    private func inspectPersistedRepositoryAggregate(
        at storeURL: URL,
        model: NSManagedObjectModel
    ) throws -> RepositoryAggregate {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let store = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
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

        var aggregate: RepositoryAggregate?
        try performAndWait(in: context) {
            let runtimeRequest = NSFetchRequest<fearless.CDRuntimeMetadataItem>(
                entityName: "CDRuntimeMetadataItem"
            )
            let chainRequest = NSFetchRequest<fearless.CDChain>(entityName: "CDChain")
            let nodeRequest = NSFetchRequest<fearless.CDChainNode>(entityName: "CDChainNode")
            let assetRequest = NSFetchRequest<fearless.CDAsset>(entityName: "CDAsset")

            aggregate = try self.repositoryAggregate(
                runtimes: context.fetch(runtimeRequest).map(self.runtimeProjection),
                chains: context.fetch(chainRequest).map(self.chainProjection),
                nodeCount: context.count(for: nodeRequest),
                assetCount: context.count(for: assetRequest)
            )
        }

        return try XCTUnwrap(aggregate)
    }

    private func assertMappedRepositoryInvariants(
        runtimes: [fearless.RuntimeMetadataItem],
        chains: [ChainModel],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let sortedRuntimes = runtimes.sorted {
            runtimeProjection($0).sortKey.lexicographicallyPrecedes(
                runtimeProjection($1).sortKey
            )
        }
        let runtimeIdentifiers = sortedRuntimes.map(\.chain)

        XCTAssertEqual(
            Set(runtimeIdentifiers).count,
            runtimeIdentifiers.count,
            "Mapped runtime identifiers must be unique",
            file: file,
            line: line
        )

        for (runtimeIndex, runtime) in sortedRuntimes.enumerated() {
            let canonicalIdentifier = runtime.chain.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            XCTAssertTrue(
                !canonicalIdentifier.isEmpty && canonicalIdentifier == runtime.chain,
                "Mapped runtime \(runtimeIndex) has a noncanonical identifier",
                file: file,
                line: line
            )
            XCTAssertFalse(
                runtime.metadata.isEmpty,
                "Mapped runtime \(runtimeIndex) has empty metadata",
                file: file,
                line: line
            )
        }

        let sortedChains = chains.sorted {
            chainProjection($0).sortKey.lexicographicallyPrecedes(
                chainProjection($1).sortKey
            )
        }
        let chainIdentifiers = sortedChains.map(\.chainId)

        XCTAssertEqual(
            Set(chainIdentifiers).count,
            chainIdentifiers.count,
            "Mapped chain identifiers must be unique",
            file: file,
            line: line
        )

        for (chainIndex, chain) in sortedChains.enumerated() {
            let canonicalIdentifier = chain.chainId.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            XCTAssertTrue(
                !canonicalIdentifier.isEmpty && canonicalIdentifier == chain.chainId,
                "Mapped chain \(chainIndex) has a noncanonical identifier",
                file: file,
                line: line
            )
            XCTAssertFalse(
                chain.chainId.hasPrefix(
                    ChainModelMapper.quarantinedChainIdentifierPrefix
                ),
                "Mapped chain \(chainIndex) unexpectedly contains a quarantine identifier",
                file: file,
                line: line
            )
            XCTAssertTrue(
                !chain.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                "Mapped chain \(chainIndex) has an empty name",
                file: file,
                line: line
            )
            XCTAssertFalse(
                chain.name == ChainModelMapper.quarantinedChainName,
                "Mapped chain \(chainIndex) unexpectedly contains a quarantine name",
                file: file,
                line: line
            )

            let assetIdentifiers = chain.assets.map(\.id)
            XCTAssertEqual(
                Set(assetIdentifiers).count,
                assetIdentifiers.count,
                "Mapped chain \(chainIndex) contains duplicate asset identifiers",
                file: file,
                line: line
            )
            for (assetIndex, assetIdentifier) in assetIdentifiers.enumerated() {
                XCTAssertFalse(
                    assetIdentifier.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty,
                    "Mapped chain \(chainIndex) asset \(assetIndex) has an empty identifier",
                    file: file,
                    line: line
                )
            }

            let defaultNodes = Array(chain.nodes)
            let customNodes = Array(chain.customNodes ?? [])
            let selectedNodes = [chain.selectedNode].compactMap { $0 }
            let nodeGroups = [defaultNodes, customNodes, selectedNodes]

            for (groupIndex, nodes) in nodeGroups.enumerated() {
                for (nodeIndex, node) in nodes.enumerated() {
                    XCTAssertTrue(
                        ChainModelMapper.isUsableNodeURL(node.url),
                        "Mapped chain \(chainIndex) node \(groupIndex):\(nodeIndex) has an unusable URL",
                        file: file,
                        line: line
                    )
                    XCTAssertTrue(
                        ChainModelMapper.isNodeCompatibleWithRuntime(
                            node,
                            for: chain
                        ),
                        "Mapped chain \(chainIndex) node \(groupIndex):\(nodeIndex) is runtime-incompatible",
                        file: file,
                        line: line
                    )
                    XCTAssertFalse(
                        node.name.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty,
                        "Mapped chain \(chainIndex) node \(groupIndex):\(nodeIndex) has an empty name",
                        file: file,
                        line: line
                    )
                }
            }

            XCTAssertTrue(
                chain.disabled || chain.selectedNode != nil || chain.nodes.isNotEmpty,
                "Enabled mapped chain \(chainIndex) has no runtime endpoint",
                file: file,
                line: line
            )
        }
    }

    private func repositoryAggregate(
        runtimes: [RuntimeProjection],
        chains: [ChainProjection],
        nodeCount: Int,
        assetCount: Int
    ) throws -> RepositoryAggregate {
        let canonicalRuntimes = runtimes.sorted {
            $0.sortKey.lexicographicallyPrecedes($1.sortKey)
        }
        let canonicalChains = chains
            .map { chain in
                ChainProjection(
                    chainId: chain.chainId,
                    name: chain.name,
                    disabled: chain.disabled,
                    assetIds: chain.assetIds.sorted(),
                    nodes: chain.nodes.sorted {
                        $0.sortKey.lexicographicallyPrecedes($1.sortKey)
                    },
                    customNodes: chain.customNodes.sorted {
                        $0.sortKey.lexicographicallyPrecedes($1.sortKey)
                    },
                    selectedNode: chain.selectedNode
                )
            }
            .sorted {
                $0.sortKey.lexicographicallyPrecedes($1.sortKey)
            }

        let projection = RepositoryProjection(
            runtimes: canonicalRuntimes,
            chains: canonicalChains
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let encodedProjection = try encoder.encode(projection)

        let defaultNodeRelationshipCount = canonicalChains.reduce(0) {
            $0 + $1.nodes.count
        }
        let customNodeRelationshipCount = canonicalChains.reduce(0) {
            $0 + $1.customNodes.count
        }
        let selectedNodeRelationshipCount = canonicalChains.reduce(0) {
            $0 + ($1.selectedNode == nil ? 0 : 1)
        }
        let standaloneSelectedNodeCount = canonicalChains.reduce(0) { count, chain in
            guard let selectedNode = chain.selectedNode else {
                return count
            }

            let relatedURLs = Set(
                (chain.nodes + chain.customNodes).map(\.url)
            )
            return count + (relatedURLs.contains(selectedNode.url) ? 0 : 1)
        }

        return RepositoryAggregate(
            runtimeCount: canonicalRuntimes.count,
            chainCount: canonicalChains.count,
            enabledChainCount: canonicalChains.filter { !$0.disabled }.count,
            assetCount: assetCount,
            nodeCount: nodeCount,
            defaultNodeRelationshipCount: defaultNodeRelationshipCount,
            customNodeRelationshipCount: customNodeRelationshipCount,
            selectedNodeRelationshipCount: selectedNodeRelationshipCount,
            standaloneSelectedNodeCount: standaloneSelectedNodeCount,
            fingerprint: Data(SHA256.hash(data: encodedProjection))
        )
    }

    private func runtimeProjection(
        _ runtime: fearless.RuntimeMetadataItem
    ) -> RuntimeProjection {
        RuntimeProjection(
            chain: runtime.chain,
            version: runtime.version,
            txVersion: runtime.txVersion,
            metadataDigest: Data(SHA256.hash(data: runtime.metadata))
        )
    }

    private func runtimeProjection(
        _ runtime: fearless.CDRuntimeMetadataItem
    ) -> RuntimeProjection {
        RuntimeProjection(
            chain: runtime.identifier ?? "",
            version: UInt32(bitPattern: runtime.version),
            txVersion: UInt32(bitPattern: runtime.txVersion),
            metadataDigest: Data(SHA256.hash(data: runtime.metadata ?? Data()))
        )
    }

    private func chainProjection(_ chain: ChainModel) -> ChainProjection {
        ChainProjection(
            chainId: chain.chainId,
            name: chain.name,
            disabled: chain.disabled,
            assetIds: chain.assets.map(\.id).sorted(),
            nodes: chain.nodes.map(nodeProjection).sorted {
                $0.sortKey.lexicographicallyPrecedes($1.sortKey)
            },
            customNodes: (chain.customNodes ?? []).map(nodeProjection).sorted {
                $0.sortKey.lexicographicallyPrecedes($1.sortKey)
            },
            selectedNode: chain.selectedNode.map(nodeProjection)
        )
    }

    private func chainProjection(_ chain: fearless.CDChain) -> ChainProjection {
        ChainProjection(
            chainId: chain.chainId ?? "",
            name: chain.name ?? "",
            disabled: chain.disabled,
            assetIds: chain.assets?.compactMap {
                ($0 as? fearless.CDAsset)?.id
            }.sorted() ?? [],
            nodes: chain.nodes?.compactMap {
                ($0 as? fearless.CDChainNode).map(nodeProjection)
            }.sorted {
                $0.sortKey.lexicographicallyPrecedes($1.sortKey)
            } ?? [],
            customNodes: chain.customNodes?.compactMap {
                ($0 as? fearless.CDChainNode).map(nodeProjection)
            }.sorted {
                $0.sortKey.lexicographicallyPrecedes($1.sortKey)
            } ?? [],
            selectedNode: chain.selectedNode.map(nodeProjection)
        )
    }

    private func nodeProjection(_ node: ChainNodeModel) -> NodeProjection {
        NodeProjection(
            url: node.url.absoluteString,
            name: node.name,
            apiQueryName: node.apikey?.queryName,
            apiKeyName: node.apikey?.keyName
        )
    }

    private func nodeProjection(_ node: fearless.CDChainNode) -> NodeProjection {
        NodeProjection(
            url: node.url?.absoluteString ?? "",
            name: node.name ?? "",
            apiQueryName: node.apiQueryName,
            apiKeyName: node.apiKeyName
        )
    }

    private func allNodes(in chain: ChainModel) -> [ChainNodeModel] {
        Array(chain.nodes) +
            Array(chain.customNodes ?? []) +
            [chain.selectedNode].compactMap { $0 }
    }

    private func loadBundledV8Model() throws -> NSManagedObjectModel {
        let appBundle = Bundle(for: SubstrateDataStorageFacade.self)
        let modelURL = ["omo", "mom"].lazy.compactMap {
            appBundle.url(
                forResource: SubstrateStorageVersion.version8.rawValue,
                withExtension: $0,
                subdirectory: SubstrateStorageParams.modelDirectory
            )
        }.first

        return try XCTUnwrap(
            modelURL.flatMap(NSManagedObjectModel.init(contentsOf:)),
            "Unable to load bundled SubstrateDataModel_v8"
        )
    }

    private func makeInMemoryContext() throws -> NSManagedObjectContext {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: try loadBundledV8Model())
        try coordinator.addPersistentStore(
            ofType: NSInMemoryStoreType,
            configurationName: nil,
            at: nil
        )

        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        return context
    }

    private func roundTrip<Model, Entity>(
        _ model: Model,
        entityName: String,
        entityClass _: Entity.Type,
        in context: NSManagedObjectContext
    ) throws -> Model where
        Model: Codable & Identifiable,
        Entity: NSManagedObject & CoreDataCodable
    {
        let mapper = CodableCoreDataMapper<Model, Entity>()
        var transformedModel: Model?

        try performAndWait(in: context) {
            let insertedObject = try XCTUnwrap(
                NSEntityDescription.insertNewObject(
                    forEntityName: entityName,
                    into: context
                ) as? Entity
            )
            try mapper.populate(entity: insertedObject, from: model, using: context)
            try context.save()
            context.reset()

            let request = NSFetchRequest<Entity>(entityName: entityName)
            let persistedObject = try XCTUnwrap(context.fetch(request).last)
            self.assertExactClass(
                of: persistedObject,
                is: Entity.self,
                entityName: entityName
            )
            transformedModel = try mapper.transform(entity: persistedObject)
        }

        return try XCTUnwrap(transformedModel)
    }

    private func assertMalformedRowRejected<Model, Entity>(
        _: Model.Type,
        entityName: String,
        entityClass _: Entity.Type,
        in context: NSManagedObjectContext,
        file: StaticString = #filePath,
        line: UInt = #line
    ) where
        Model: Codable & Identifiable,
        Entity: NSManagedObject & CoreDataCodable
    {
        guard let malformedEntity = NSEntityDescription.insertNewObject(
            forEntityName: entityName,
            into: context
        ) as? Entity else {
            XCTFail("\(entityName) did not materialize as its expected class", file: file, line: line)
            return
        }

        let mapper = CodableCoreDataMapper<Model, Entity>()
        XCTAssertThrowsError(
            try mapper.transform(entity: malformedEntity),
            "\(entityName) accepted a row with missing required values",
            file: file,
            line: line
        )
    }

    private func performAndWait(
        in context: NSManagedObjectContext,
        body: () throws -> Void
    ) throws {
        var bodyError: Error?
        context.performAndWait {
            do {
                try body()
            } catch {
                bodyError = error
            }
        }

        if let bodyError {
            throw bodyError
        }
    }

    private func assertExactClass(
        of object: NSManagedObject,
        is expectedClass: NSManagedObject.Type,
        entityName: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            ObjectIdentifier(type(of: object)),
            ObjectIdentifier(expectedClass),
            "\(entityName) materialized as \(NSStringFromClass(type(of: object)))",
            file: file,
            line: line
        )
    }

    private func versionHashes(for model: NSManagedObjectModel) -> [String: String] {
        model.entityVersionHashesByName.mapValues { $0.base64EncodedString() }
    }

    private func copiedPhoneStoreFixtureURL() -> URL {
        if let configuredPath = ProcessInfo.processInfo.environment[
            "FEARLESS_SUBSTRATE_PHONE_STORE_FIXTURE"
        ], !configuredPath.isEmpty {
            return URL(fileURLWithPath: configuredPath)
        }

        return URL(
            fileURLWithPath:
            "/private/tmp/fearless-device-coredata-20260723/SubstrateDataModel.sqlite"
        )
    }

    private func copyStoreFixtureToTemporaryDirectory(_ fixtureURL: URL) throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SubstrateStoragePhoneFixture")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let destinationURL = directoryURL.appendingPathComponent(fixtureURL.lastPathComponent)
        for suffix in ["", "-wal", "-shm"] {
            let sourceURL = URL(fileURLWithPath: fixtureURL.path + suffix)
            guard FileManager.default.fileExists(atPath: sourceURL.path) else {
                continue
            }

            let copiedURL = URL(fileURLWithPath: destinationURL.path + suffix)
            try FileManager.default.copyItem(at: sourceURL, to: copiedURL)
        }

        return destinationURL
    }

    private func inspectReadOnlyStore(
        at storeURL: URL,
        model: NSManagedObjectModel,
        fetchEveryObject: Bool
    ) throws -> [String: Int] {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let store = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
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
        var counts: [String: Int] = [:]

        try performAndWait(in: context) {
            for expectation in self.expectedEntityClasses {
                let request = NSFetchRequest<NSManagedObject>(entityName: expectation.entityName)
                let count = try context.count(for: request)
                counts[expectation.entityName] = count

                guard fetchEveryObject, count > 0 else {
                    continue
                }

                request.fetchBatchSize = 512
                request.returnsObjectsAsFaults = true
                let objects = try context.fetch(request)
                XCTAssertEqual(objects.count, count)

                for object in objects {
                    self.assertExactClass(
                        of: object,
                        is: expectation.managedObjectClass,
                        entityName: expectation.entityName
                    )
                }

                context.reset()
            }
        }

        return counts
    }

    private func metadataVersionHashes(_ metadata: [String: Any]) -> [String: Data]? {
        metadata[NSStoreModelVersionHashesKey] as? [String: Data]
    }

    private func storeFingerprints(at storeURL: URL) throws -> [String: Data] {
        var fingerprints: [String: Data] = [:]

        for suffix in ["", "-wal", "-shm"] {
            let fileURL = URL(fileURLWithPath: storeURL.path + suffix)
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                continue
            }

            fingerprints[suffix] = try digest(of: fileURL)
        }

        return fingerprints
    }

    private func digest(of fileURL: URL) throws -> Data {
        Data(SHA256.hash(data: try Data(contentsOf: fileURL, options: .mappedIfSafe)))
    }
}
