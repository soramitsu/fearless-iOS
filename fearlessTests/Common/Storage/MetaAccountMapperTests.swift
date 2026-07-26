import XCTest
@testable import fearless
import RobinHood
import SSFModels
import CoreData

class MetaAccountMapperTests: XCTestCase {
    func testTransformConvertsMandatoryGetterExceptionToSanitizedSwiftError() {
        let entityDescription = makeEntityDescription(
            managedObjectClass: CDMetaAccount.self,
            properties: []
        )
        let entity = CDMetaAccount(
            entity: entityDescription,
            insertInto: nil
        )

        XCTAssertThrowsError(
            try MetaAccountMapper().transform(entity: entity)
        ) { error in
            XCTAssertEqual(
                error as? SafeTransformableValueReaderError,
                .objectiveCException
            )
        }
    }

    func testMalformedChildRelationshipFailsClosedThroughDirectAndSelectionMappers()
        throws {
        let fixture = try makeMetaAccountWithThrowingChainAccountRelationship()

        XCTAssertThrowsError(
            try MetaAccountMapper().transform(entity: fixture.entity)
        ) { error in
            XCTAssertEqual(
                error as? SafeTransformableValueReaderError,
                .objectiveCException
            )
        }

        let startupMapper:
            AnyCoreDataMapper<MetaAccountSelectionModel, CDMetaAccount> =
            AnyCoreDataMapper(MetaAccountSelectionMapper())
        let projection = try startupMapper.transform(entity: fixture.entity)

        XCTAssertEqual(projection.identifier, "relationship-wallet")
        XCTAssertEqual(projection.recordState, .corrupt)
        XCTAssertNil(projection.wallet)
        XCTAssertFalse(projection.recordState.allowsStoredRecordUpdates)
    }

    func testSelectionStartupWrapperQuarantinesOwnIdentifierGetterException()
        throws {
        let entityDescription = makeEntityDescription(
            managedObjectClass: CDMetaAccount.self,
            properties: [
                makeAttribute(
                    name: "isSelected",
                    type: .booleanAttributeType
                ),
                makeAttribute(name: "order", type: .integer32AttributeType)
            ]
        )
        let entity = CDMetaAccount(
            entity: entityDescription,
            insertInto: nil
        )
        let startupMapper:
            AnyCoreDataMapper<MetaAccountSelectionModel, CDMetaAccount> =
            AnyCoreDataMapper(MetaAccountSelectionMapper())
        let projection = try startupMapper.transform(entity: entity)

        XCTAssertTrue(
            projection.identifier.hasPrefix(
                "fearless.quarantined-wallet:"
            )
        )
        XCTAssertEqual(projection.recordState, .corrupt)
        XCTAssertNil(projection.wallet)
        XCTAssertFalse(projection.isSelected)
        XCTAssertEqual(projection.order, 0)
        XCTAssertFalse(projection.recordState.allowsStoredRecordUpdates)
    }

    func testSaveAndFetch() throws {
        // given

        let operationQueue = OperationQueue()
        let facade = UserDataStorageTestFacade()

        let mapper = ManagedMetaAccountMapper()
        let repository = facade.createRepository(mapper: AnyCoreDataMapper(mapper))

        let maxChainAccountCount = 3
        let accountCount = 10

        let metaAccounts: [fearless.ManagedMetaAccountModel] = (0..<accountCount).map { _ in
            let account = AccountGenerator.generateMetaAccount(
                generatingChainAccounts: (0..<maxChainAccountCount).randomElement()!
            )

            return fearless.ManagedMetaAccountModel(
                info: account,
                isSelected: false,
                order: fearless.ManagedMetaAccountModel.noOrder
            )
        }

        // when

        let saveOperation = repository.saveOperation( { metaAccounts }, { [] })
        operationQueue.addOperations([saveOperation], waitUntilFinished: true)

        // then

        let allMetaAccountsOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        operationQueue.addOperations([allMetaAccountsOperation], waitUntilFinished: true)

        let allMetaAccounts = try allMetaAccountsOperation.extractResultData(
            throwing: BaseOperationError.parentOperationCancelled
        )

        let expectedAccounts = metaAccounts.reduce(into: [String: MetaAccountModel]()) { result, account in
            result[account.identifier] = account.info
        }

        let actualAccounts = allMetaAccounts.reduce(into: [String: MetaAccountModel]()) { result, account in
            result[account.identifier] = account.info
        }

        let differentOrders = allMetaAccounts.reduce(into: Set<UInt32>()) { $0.insert($1.order) }

        XCTAssertEqual(expectedAccounts, actualAccounts)
        XCTAssertEqual(differentOrders.count, accountCount)
    }

    func testCanonicalEcdsaSubstratePublicKeyIsAccepted() throws {
        let operationQueue = OperationQueue()
        let facade = UserDataStorageTestFacade()
        let generated = AccountGenerator.generateMetaAccount(generatingChainAccounts: 1)
        let ecdsaChainAccount = ChainAccountModel(
            chainId: "canonical-ecdsa-chain",
            accountId: Data(repeating: 0x59, count: 20),
            publicKey: Data(repeating: 0x58, count: 33),
            cryptoType: CryptoType.ecdsa.rawValue,
            ethereumBased: true
        )
        let wallet = MetaAccountModel(
            metaId: "canonical-ecdsa-wallet",
            name: generated.name,
            substrateAccountId: generated.substrateAccountId,
            substrateCryptoType: CryptoType.ecdsa.rawValue,
            substratePublicKey: Data(repeating: 0x5A, count: 33),
            ethereumAddress: generated.ethereumAddress,
            ethereumPublicKey: generated.ethereumPublicKey,
            chainAccounts: [ecdsaChainAccount],
            assetKeysOrder: generated.assetKeysOrder,
            canExportEthereumMnemonic: generated.canExportEthereumMnemonic,
            unusedChainIds: generated.unusedChainIds,
            selectedCurrency: generated.selectedCurrency,
            networkManagmentFilter: generated.networkManagmentFilter,
            assetsVisibility: generated.assetsVisibility,
            hasBackup: generated.hasBackup,
            favouriteChainIds: generated.favouriteChainIds
        )
        let storageRepository = facade.createRepository(
            mapper: AnyCoreDataMapper(ManagedMetaAccountMapper())
        )

        let saveOperation = storageRepository.saveOperation(
            { [ManagedMetaAccountModel(info: wallet, isSelected: true)] },
            { [] }
        )
        operationQueue.addOperations([saveOperation], waitUntilFinished: true)
        _ = try XCTUnwrap(saveOperation.result).get()

        let repository = AccountRepositoryFactory(storageFacade: facade)
            .createMetaAccountRepository(for: nil, sortDescriptors: [])
        let fetchOperation = repository.fetchAllOperation(
            with: RepositoryFetchOptions(
                includesProperties: true,
                includesSubentities: true
            )
        )
        operationQueue.addOperations([fetchOperation], waitUntilFinished: true)

        XCTAssertEqual(try XCTUnwrap(fetchOperation.result).get(), [wallet])
    }

    func testNonPersistableNilRequiredFieldsAreQuarantinedByMappersWithoutSaving() throws {
        let facade = UserDataStorageTestFacade()
        let callbackExpectation = expectation(
            description: "unsaved required-field corruptions are mapped"
        )
        var callbackResult: Result<[NonPersistableCorruptionObservation], Error>?

        facade.databaseService.performAsync { context, error in
            defer {
                callbackExpectation.fulfill()
            }

            do {
                if error != nil {
                    throw MetaAccountMapperTestFixtureError(
                        message: "Core Data setup failed"
                    )
                }
                guard let context else {
                    throw MetaAccountMapperTestFixtureError(
                        message: "Core Data setup returned no context"
                    )
                }

                let mapper = MetaAccountMapper()
                let selectionMapper = MetaAccountSelectionMapper()
                var observations: [NonPersistableCorruptionObservation] = []

                for corruption in NonPersistableSupportedWalletCorruption.allCases {
                    let generated = AccountGenerator.generateMetaAccount(
                        generatingChainAccounts: 1
                    )
                    let model = MetaAccountModel(
                        metaId: "unsaved-\(corruption.identifier)",
                        name: generated.name,
                        substrateAccountId: generated.substrateAccountId,
                        substrateCryptoType: generated.substrateCryptoType,
                        substratePublicKey: generated.substratePublicKey,
                        ethereumAddress: generated.ethereumAddress,
                        ethereumPublicKey: generated.ethereumPublicKey,
                        chainAccounts: generated.chainAccounts,
                        assetKeysOrder: generated.assetKeysOrder,
                        canExportEthereumMnemonic: generated.canExportEthereumMnemonic,
                        unusedChainIds: generated.unusedChainIds,
                        selectedCurrency: generated.selectedCurrency,
                        networkManagmentFilter: generated.networkManagmentFilter,
                        assetsVisibility: generated.assetsVisibility,
                        hasBackup: generated.hasBackup,
                        favouriteChainIds: generated.favouriteChainIds
                    )
                    let entity = CDMetaAccount(context: context)
                    try mapper.populate(entity: entity, from: model, using: context)
                    guard
                        let child = entity.chainAccounts?.allObjects.first
                            as? CDChainAccount
                    else {
                        throw MetaAccountMapperTestFixtureError(
                            message: "Generated wallet has no child chain account"
                        )
                    }

                    switch corruption {
                    case .missingMetaId:
                        entity.metaId = nil
                    case .missingName:
                        entity.name = nil
                    case .missingChildAccountId:
                        child.accountId = nil
                    case .missingChildChainId:
                        child.chainId = nil
                    case .missingChildPublicKey:
                        child.publicKey = nil
                    }

                    let coreDataRejectsInsert: Bool
                    do {
                        try entity.validateForInsert()
                        coreDataRejectsInsert = false
                    } catch {
                        coreDataRejectsInsert = true
                    }

                    let directMapperRejectsAsInvalid: Bool
                    do {
                        _ = try mapper.transform(entity: entity)
                        directMapperRejectsAsInvalid = false
                    } catch MetaAccountMapperError.invalidWalletRecord {
                        directMapperRejectsAsInvalid = true
                    }

                    let projection = try selectionMapper.transform(entity: entity)
                    let replacement = projection.replacingSelection(
                        !projection.isSelected
                    )
                    observations.append(
                        NonPersistableCorruptionObservation(
                            identifier: corruption.identifier,
                            coreDataRejectsInsert: coreDataRejectsInsert,
                            directMapperRejectsAsInvalid: directMapperRejectsAsInvalid,
                            recordState: projection.recordState,
                            hasProjectedWallet: projection.wallet != nil,
                            allowsStoredRecordUpdates:
                                projection.recordState.allowsStoredRecordUpdates,
                            replacementUpdatesWalletPayload:
                                replacement.updatesWalletPayload,
                            replacementUpdatesSelection:
                                replacement.updatesSelection
                        )
                    )

                    context.rollback()
                }

                callbackResult = .success(observations)
            } catch {
                callbackResult = .failure(error)
            }
        }

        wait(
            for: [callbackExpectation],
            timeout: Constants.defaultExpectationDuration
        )
        guard let callbackResult else {
            throw MetaAccountMapperTestFixtureError(
                message: "Core Data mapper callback produced no result"
            )
        }
        let observations = try callbackResult.get()

        XCTAssertEqual(
            observations.map(\.identifier),
            NonPersistableSupportedWalletCorruption.allCases.map(\.identifier)
        )
        XCTAssertTrue(observations.allSatisfy(\.coreDataRejectsInsert))
        XCTAssertTrue(observations.allSatisfy(\.directMapperRejectsAsInvalid))
        XCTAssertTrue(observations.allSatisfy { $0.recordState == .corrupt })
        XCTAssertTrue(observations.allSatisfy { !$0.hasProjectedWallet })
        XCTAssertTrue(observations.allSatisfy { !$0.allowsStoredRecordUpdates })
        XCTAssertTrue(
            observations.allSatisfy { !$0.replacementUpdatesWalletPayload }
        )
        XCTAssertTrue(
            observations.allSatisfy { !$0.replacementUpdatesSelection }
        )
    }

    func testRepositorySliceDecoderAcceptsExactShapeAndFailsClosedOtherwise() throws {
        let decoded = try ValidatedRepositorySlice(
            request: RepositorySliceRequest(
                offset: 2,
                count: 3,
                reversed: true
            )
        )

        XCTAssertEqual(decoded.offset, 2)
        XCTAssertEqual(decoded.count, 3)
        XCTAssertTrue(decoded.reversed)

        let invalidShapes: [[ValidatedRepositorySlice.ReflectedField]] = [
            [
                (label: "offset", value: 0),
                (label: "count", value: 1)
            ],
            [
                (label: "offset", value: 0),
                (label: "offset", value: 1),
                (label: "reversed", value: false)
            ],
            [
                (label: "offset", value: 0),
                (label: "count", value: 1),
                (label: "unexpected", value: false)
            ],
            [
                (label: nil, value: 0),
                (label: "count", value: 1),
                (label: "reversed", value: false)
            ],
            [
                (label: "offset", value: "0"),
                (label: "count", value: 1),
                (label: "reversed", value: false)
            ],
            [
                (label: "offset", value: 0),
                (label: "count", value: true),
                (label: "reversed", value: false)
            ],
            [
                (label: "offset", value: 0),
                (label: "count", value: 1),
                (label: "reversed", value: 0)
            ],
            [
                (label: "offset", value: -1),
                (label: "count", value: 1),
                (label: "reversed", value: false)
            ],
            [
                (label: "offset", value: 0),
                (label: "count", value: -1),
                (label: "reversed", value: false)
            ],
            [
                (label: "offset", value: 0),
                (label: "count", value: 1),
                (label: "reversed", value: false),
                (label: "extra", value: false)
            ]
        ]

        for (index, fields) in invalidShapes.enumerated() {
            XCTAssertThrowsError(
                try ValidatedRepositorySlice(reflectedFields: fields),
                "Invalid reflected shape \(index) was accepted"
            ) { error in
                XCTAssertEqual(
                    error as? TolerantMetaAccountRepositoryError,
                    .invalidSliceRequest
                )
                XCTAssertFalse(
                    (error as? LocalizedError)?
                        .errorDescription?
                        .isEmpty ?? true
                )
            }
        }
    }

    private func makeMetaAccountWithThrowingChainAccountRelationship()
        throws -> (
            context: NSManagedObjectContext,
            entity: CDMetaAccount
        ) {
        let chainAccountDescription = makeEntityDescription(
            managedObjectClass: CDChainAccount.self,
            properties: []
        )
        let chainAccounts = NSRelationshipDescription()
        chainAccounts.name = "chainAccounts"
        chainAccounts.destinationEntity = chainAccountDescription
        chainAccounts.minCount = 0
        chainAccounts.maxCount = 0
        chainAccounts.isOptional = true
        chainAccounts.deleteRule = .nullifyDeleteRule

        let metaAccountDescription = makeEntityDescription(
            managedObjectClass: CDMetaAccount.self,
            properties: [
                makeAttribute(name: "metaId", type: .stringAttributeType),
                makeAttribute(name: "name", type: .stringAttributeType),
                makeAttribute(
                    name: "substrateAccountId",
                    type: .stringAttributeType
                ),
                makeAttribute(
                    name: "substratePublicKey",
                    type: .binaryDataAttributeType
                ),
                makeAttribute(
                    name: "substrateCryptoType",
                    type: .integer16AttributeType
                ),
                makeAttribute(
                    name: "isSelected",
                    type: .booleanAttributeType
                ),
                makeAttribute(name: "order", type: .integer32AttributeType),
                chainAccounts
            ]
        )
        let context = try makeContext(
            entities: [metaAccountDescription, chainAccountDescription]
        )
        let entity = CDMetaAccount(
            entity: metaAccountDescription,
            insertInto: context
        )
        entity.setValue("relationship-wallet", forKey: "metaId")
        entity.setValue("Relationship wallet", forKey: "name")
        entity.setValue(
            String(repeating: "11", count: 32),
            forKey: "substrateAccountId"
        )
        entity.setValue(
            Data(repeating: 0x22, count: 32),
            forKey: "substratePublicKey"
        )
        entity.setValue(
            NSNumber(value: CryptoType.sr25519.rawValue),
            forKey: "substrateCryptoType"
        )
        entity.setValue(true, forKey: "isSelected")
        entity.setValue(Int32(9), forKey: "order")

        let throwingChild = CDChainAccount(
            entity: chainAccountDescription,
            insertInto: context
        )
        entity.setValue(
            NSSet(object: throwingChild),
            forKey: "chainAccounts"
        )

        return (context, entity)
    }

    private func makeEntityDescription(
        managedObjectClass: AnyClass,
        properties: [NSPropertyDescription]
    ) -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "MapperExceptionFixture_" + UUID().uuidString
            .replacingOccurrences(of: "-", with: "")
        entity.managedObjectClassName = NSStringFromClass(
            managedObjectClass
        )
        entity.properties = properties
        return entity
    }

    private func makeAttribute(
        name: String,
        type: NSAttributeType
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = true
        return attribute
    }

    private func makeContext(
        entities: [NSEntityDescription]
    ) throws -> NSManagedObjectContext {
        let model = NSManagedObjectModel()
        model.entities = entities
        let coordinator = NSPersistentStoreCoordinator(
            managedObjectModel: model
        )
        try coordinator.addPersistentStore(
            ofType: NSInMemoryStoreType,
            configurationName: nil,
            at: nil,
            options: nil
        )
        let context = NSManagedObjectContext(
            concurrencyType: .mainQueueConcurrencyType
        )
        context.persistentStoreCoordinator = coordinator
        return context
    }

}

private enum NonPersistableSupportedWalletCorruption: CaseIterable {
    case missingMetaId
    case missingName
    case missingChildAccountId
    case missingChildChainId
    case missingChildPublicKey

    var identifier: String {
        switch self {
        case .missingMetaId:
            return "missing-meta-id"
        case .missingName:
            return "missing-name"
        case .missingChildAccountId:
            return "missing-child-account-id"
        case .missingChildChainId:
            return "missing-child-chain-id"
        case .missingChildPublicKey:
            return "missing-child-public-key"
        }
    }
}

private struct NonPersistableCorruptionObservation {
    let identifier: String
    let coreDataRejectsInsert: Bool
    let directMapperRejectsAsInvalid: Bool
    let recordState: MetaAccountSelectionRecordState
    let hasProjectedWallet: Bool
    let allowsStoredRecordUpdates: Bool
    let replacementUpdatesWalletPayload: Bool
    let replacementUpdatesSelection: Bool
}

private struct MetaAccountMapperTestFixtureError: Error, CustomStringConvertible {
    let message: String

    var description: String {
        message
    }
}
