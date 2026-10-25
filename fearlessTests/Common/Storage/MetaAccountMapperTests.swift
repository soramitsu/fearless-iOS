import XCTest
@testable import fearless
import RobinHood
import SSFModels
import CoreData
import IrohaCrypto

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

    func testExplicitRestoreDisplayPreferencesSurviveAnOrdinaryWalletSave() throws {
        let queue = OperationQueue()
        let facade = UserDataStorageTestFacade()
        let repository = facade.createRepository(
            mapper: AnyCoreDataMapper(MetaAccountSelectionMapper(captureDisplayPreferences: true))
        )
        let wallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 1)
        let preferences = PersistedWalletDisplayPreferences(
            assetFilterOptions: ["unknown-future-filter", "hide-spam"],
            zeroBalanceAssetsHidden: true
        )
        let restore = MetaAccountSelectionModel(
            identifier: wallet.metaId, wallet: wallet, isSelected: true,
            order: fearless.ManagedMetaAccountModel.noOrder,
            displayPreferences: preferences, updatesWalletPayload: true
        )
        let restoreOperation = repository.saveOperation({ [restore] }, { [] })
        queue.addOperations([restoreOperation], waitUntilFinished: true)
        _ = try XCTUnwrap(restoreOperation.result).get()

        let firstFetch = repository.fetchAllOperation(with: RepositoryFetchOptions())
        queue.addOperations([firstFetch], waitUntilFinished: true)
        let restored = try XCTUnwrap(try XCTUnwrap(firstFetch.result).get().first)
        XCTAssertEqual(restored.displayPreferences, preferences)

        let ordinarySave = MetaAccountSelectionModel(
            identifier: wallet.metaId, wallet: wallet, isSelected: true,
            order: restored.order, updatesWalletPayload: true
        )
        let ordinaryOperation = repository.saveOperation({ [ordinarySave] }, { [] })
        queue.addOperations([ordinaryOperation], waitUntilFinished: true)
        _ = try XCTUnwrap(ordinaryOperation.result).get()

        let secondFetch = repository.fetchAllOperation(with: RepositoryFetchOptions())
        queue.addOperations([secondFetch], waitUntilFinished: true)
        XCTAssertEqual(
            try XCTUnwrap(secondFetch.result).get().first?.displayPreferences,
            preferences
        )
    }

    func testExactNewWalletReplacementRetainsExplicitCohortOrder() throws {
        let queue = OperationQueue()
        let facade = UserDataStorageTestFacade()
        let repository = facade.createRepository(
            mapper: AnyCoreDataMapper(MetaAccountSelectionMapper())
        )
        let wallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        let expectedOrder: UInt32 = 123
        let restore = MetaAccountSelectionModel(
            identifier: wallet.metaId, wallet: wallet, isSelected: true,
            order: expectedOrder, updatesWalletPayload: true,
            replacesWalletChildrenExactly: true
        )
        let save = repository.saveOperation({ [restore] }, { [] })
        queue.addOperations([save], waitUntilFinished: true)
        _ = try XCTUnwrap(save.result).get()

        let fetch = repository.fetchAllOperation(with: RepositoryFetchOptions())
        queue.addOperations([fetch], waitUntilFinished: true)
        let stored = try XCTUnwrap(try XCTUnwrap(fetch.result).get().first)
        XCTAssertEqual(stored.identifier, wallet.metaId)
        XCTAssertEqual(stored.order, expectedOrder)
        XCTAssertTrue(stored.isSelected)
    }

    func testExactNewWalletReplacementRejectsOrderOutsideCoreDataRange() throws {
        let queue = OperationQueue()
        let facade = UserDataStorageTestFacade()
        let repository = facade.createRepository(
            mapper: AnyCoreDataMapper(MetaAccountSelectionMapper())
        )
        let wallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        let invalid = MetaAccountSelectionModel(
            identifier: wallet.metaId, wallet: wallet, isSelected: true,
            order: UInt32(Int32.max) + 1, updatesWalletPayload: true,
            replacesWalletChildrenExactly: true
        )
        let save = repository.saveOperation({ [invalid] }, { [] })
        queue.addOperations([save], waitUntilFinished: true)
        XCTAssertThrowsError(try XCTUnwrap(save.result).get())

        let count = repository.fetchCountOperation()
        queue.addOperations([count], waitUntilFinished: true)
        XCTAssertEqual(try XCTUnwrap(count.result).get(), 0)
    }

    func testWalletReplacementRemovesObsoleteChainAndVisibilityRows() throws {
        let queue = OperationQueue()
        let facade = UserDataStorageTestFacade()
        let repository = facade.createRepository(mapper: AnyCoreDataMapper(MetaAccountSelectionMapper()))
        let original = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
            .replacingChainAccounts([
                ChainAccountModel(
                    chainId: "retained-chain", accountId: Data(repeating: 0x11, count: 32),
                    publicKey: Data(repeating: 0x21, count: 32),
                    cryptoType: CryptoType.ed25519.rawValue, ethereumBased: false
                ),
                ChainAccountModel(
                    chainId: "obsolete-chain", accountId: Data(repeating: 0x12, count: 32),
                    publicKey: Data(repeating: 0x22, count: 32),
                    cryptoType: CryptoType.ed25519.rawValue, ethereumBased: false
                )
            ])
            .replacingAssetsVisibility([
                AssetVisibility(assetId: "retained-asset", hidden: true),
                AssetVisibility(assetId: "obsolete-asset", hidden: false)
            ])
        let firstSave = repository.saveOperation({ [MetaAccountSelectionModel(
            identifier: original.metaId, wallet: original, isSelected: true,
            order: fearless.ManagedMetaAccountModel.noOrder, updatesWalletPayload: true
        )] }, { [] })
        queue.addOperations([firstSave], waitUntilFinished: true)
        _ = try XCTUnwrap(firstSave.result).get()

        let replacement = original
            .replacingChainAccounts(Set(original.chainAccounts.filter { $0.chainId == "retained-chain" }))
            .replacingAssetsVisibility([AssetVisibility(assetId: "retained-asset", hidden: false)])
        let secondSave = repository.saveOperation({ [MetaAccountSelectionModel(
            identifier: replacement.metaId, wallet: replacement, isSelected: true,
            order: fearless.ManagedMetaAccountModel.noOrder, updatesWalletPayload: true,
            replacesWalletChildrenExactly: true
        )] }, { [] })
        queue.addOperations([secondSave], waitUntilFinished: true)
        _ = try XCTUnwrap(secondSave.result).get()

        let fetch = repository.fetchAllOperation(with: RepositoryFetchOptions(
            includesProperties: true, includesSubentities: true
        ))
        queue.addOperations([fetch], waitUntilFinished: true)
        let stored = try XCTUnwrap(try XCTUnwrap(fetch.result).get().first)
        XCTAssertEqual(stored.wallet?.chainAccounts, replacement.chainAccounts)
        XCTAssertEqual(stored.wallet?.assetsVisibility, replacement.assetsVisibility)
        XCTAssertTrue(stored.isSelected)
    }

    func testOrdinaryWalletSaveRetainsExistingChildRows() throws {
        let queue = OperationQueue()
        let facade = UserDataStorageTestFacade()
        let repository = facade.createRepository(mapper: AnyCoreDataMapper(ManagedMetaAccountMapper()))
        let wallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 1)
            .replacingAssetsVisibility([AssetVisibility(assetId: "historical-asset", hidden: true)])
        let initialSave = repository.saveOperation(
            { [fearless.ManagedMetaAccountModel(info: wallet, isSelected: true)] }, { [] }
        )
        queue.addOperations([initialSave], waitUntilFinished: true)
        _ = try XCTUnwrap(initialSave.result).get()

        let ordinaryUpdate = wallet.replacingChainAccounts([]).replacingAssetsVisibility([])
        let updateSave = repository.saveOperation(
            { [fearless.ManagedMetaAccountModel(info: ordinaryUpdate, isSelected: true)] }, { [] }
        )
        queue.addOperations([updateSave], waitUntilFinished: true)
        _ = try XCTUnwrap(updateSave.result).get()

        let fetch = repository.fetchAllOperation(with: RepositoryFetchOptions())
        queue.addOperations([fetch], waitUntilFinished: true)
        let stored = try XCTUnwrap(try XCTUnwrap(fetch.result).get().first)
        XCTAssertEqual(stored.info.chainAccounts, wallet.chainAccounts)
        XCTAssertEqual(stored.info.assetsVisibility, wallet.assetsVisibility)
    }

    func testExactReplacementUpdatesRetainedChainEcosystem() throws {
        let queue = OperationQueue()
        let facade = UserDataStorageTestFacade()
        let repository = facade.createRepository(mapper: AnyCoreDataMapper(MetaAccountSelectionMapper()))
        let evmAccount = ChainAccountModel(
            chainId: "retained-ecosystem", accountId: Data(repeating: 0x41, count: 32),
            publicKey: Data(repeating: 0x42, count: 32),
            cryptoType: CryptoType.ed25519.rawValue, ethereumBased: true
        )
        let wallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
            .replacingChainAccounts([evmAccount])
        let firstSave = repository.saveOperation({ [MetaAccountSelectionModel(
            identifier: wallet.metaId, wallet: wallet, isSelected: true,
            order: fearless.ManagedMetaAccountModel.noOrder, updatesWalletPayload: true
        )] }, { [] })
        queue.addOperations([firstSave], waitUntilFinished: true)
        _ = try XCTUnwrap(firstSave.result).get()

        let substrateAccount = ChainAccountModel(
            chainId: evmAccount.chainId, accountId: evmAccount.accountId,
            publicKey: evmAccount.publicKey, cryptoType: evmAccount.cryptoType,
            ethereumBased: false
        )
        let replacement = wallet.replacingChainAccounts([substrateAccount])
        let exactSave = repository.saveOperation({ [MetaAccountSelectionModel(
            identifier: replacement.metaId, wallet: replacement, isSelected: true,
            order: fearless.ManagedMetaAccountModel.noOrder, updatesWalletPayload: true,
            replacesWalletChildrenExactly: true
        )] }, { [] })
        queue.addOperations([exactSave], waitUntilFinished: true)
        _ = try XCTUnwrap(exactSave.result).get()

        let fetch = repository.fetchAllOperation(with: RepositoryFetchOptions())
        queue.addOperations([fetch], waitUntilFinished: true)
        let stored = try XCTUnwrap(try XCTUnwrap(fetch.result).get().first)
        XCTAssertEqual(stored.wallet?.chainAccounts, [substrateAccount])
    }

    func testOrdinaryWalletSaveStillMergesDuplicateVisibilityInputs() throws {
        let queue = OperationQueue()
        let facade = UserDataStorageTestFacade()
        let repository = facade.createRepository(mapper: AnyCoreDataMapper(ManagedMetaAccountMapper()))
        let wallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        let duplicate = AssetVisibility(assetId: "historical-duplicate", hidden: true)
        let update = wallet.replacingAssetsVisibility([duplicate, duplicate])
        for model in [wallet, update] {
            let save = repository.saveOperation(
                { [fearless.ManagedMetaAccountModel(info: model, isSelected: true)] }, { [] }
            )
            queue.addOperations([save], waitUntilFinished: true)
            _ = try XCTUnwrap(save.result).get()
        }
        let fetch = repository.fetchAllOperation(with: RepositoryFetchOptions())
        queue.addOperations([fetch], waitUntilFinished: true)
        let stored = try XCTUnwrap(try XCTUnwrap(fetch.result).get().first)
        XCTAssertEqual(stored.info.assetsVisibility, [duplicate])
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

    func testEvmOnlyWalletRoundTripsThroughCurrentStoreAndSelectionMapper() throws {
        let privateKey = Data(repeating: 0x01, count: 32)
        let publicKey = try SECKeyFactory().derive(
            fromPrivateKey: SECPrivateKey(rawData: privateKey)
        ).publicKey().rawData()
        let address = try publicKey.ethereumAddressFromPublicKey()
        let wallet = MetaAccountModel(
            metaId: "evm-only-mapper-wallet", name: "Independent EVM",
            substrateAccountId: nil, substrateCryptoType: CryptoType.ed25519.rawValue,
            substratePublicKey: nil, ethereumAddress: address, ethereumPublicKey: publicKey,
            chainAccounts: [], assetKeysOrder: nil, canExportEthereumMnemonic: false,
            unusedChainIds: nil, selectedCurrency: Currency.defaultCurrency(),
            networkManagmentFilter: nil, assetsVisibility: [], hasBackup: false,
            favouriteChainIds: []
        )
        let facade = UserDataStorageTestFacade()
        let queue = OperationQueue()
        let repository = facade.createRepository(mapper: AnyCoreDataMapper(ManagedMetaAccountMapper()))
        let save = repository.saveOperation(
            { [ManagedMetaAccountModel(info: wallet, isSelected: true)] }, { [] }
        )
        queue.addOperations([save], waitUntilFinished: true)
        _ = try XCTUnwrap(save.result).get()

        let fetch = repository.fetchAllOperation(with: RepositoryFetchOptions(
            includesProperties: true, includesSubentities: true
        ))
        queue.addOperations([fetch], waitUntilFinished: true)
        let stored = try XCTUnwrap(fetch.result).get()
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored[0].info, wallet)
        XCTAssertTrue(stored[0].isSelected)
        XCTAssertNil(stored[0].info.substratePublicKey)
        XCTAssertNil(stored[0].info.legacyTonAccount)

        let selectionRepository = facade.createRepository(
            mapper: AnyCoreDataMapper(MetaAccountSelectionMapper(captureDisplayPreferences: true))
        )
        let selectionFetch = selectionRepository.fetchAllOperation(with: RepositoryFetchOptions(
            includesProperties: true, includesSubentities: true
        ))
        queue.addOperations([selectionFetch], waitUntilFinished: true)
        let projection = try XCTUnwrap(try XCTUnwrap(selectionFetch.result).get().first)
        XCTAssertEqual(projection.recordState, .supported)
        XCTAssertEqual(projection.wallet?.ethereumAddress, address)
        XCTAssertEqual(projection.wallet?.ethereumPublicKey, publicKey)
    }

    func testEvmOnlyMapperQuarantinesIncompleteMismatchedAndPartialTonRows() throws {
        let privateKey = Data(repeating: 0x01, count: 32)
        let publicKey = try SECKeyFactory().derive(
            fromPrivateKey: SECPrivateKey(rawData: privateKey)
        ).publicKey().rawData()
        let address = try publicKey.ethereumAddressFromPublicKey()
        let validAddress = address.map { String(format: "%02x", $0) }.joined()
        let facade = UserDataStorageTestFacade()
        let checked = expectation(description: "Check unsaved EVM-only row mutations")
        var didAcceptValid = false
        var didRejectWrongAddress = false
        var didRejectMissingPublicKey = false
        var didRejectPartialTon = false
        var callbackError: Error?
        facade.databaseService.performAsync { context, error in
            defer { checked.fulfill() }
            do {
                if let error { throw error }
                guard let context else { throw MetaAccountMapperError.invalidWalletRecord }
                let row = CDMetaAccount(context: context)
                row.metaId = "evm-only-corruption-probe"
                row.name = "EVM only"
                row.ethereumAddress = validAddress
                row.ethereumPublicKey = publicKey
                row.favouriteChainIds = NSArray()
                didAcceptValid = (try? MetaAccountMapper().transform(entity: row)) != nil

                row.ethereumAddress = Data(repeating: 0x44, count: 20)
                    .map { String(format: "%02x", $0) }.joined()
                let wrongAddressState = try MetaAccountSelectionMapper().transform(entity: row).recordState
                didRejectWrongAddress = (try? MetaAccountMapper().transform(entity: row)) == nil &&
                    wrongAddressState == .corrupt
                row.ethereumAddress = validAddress

                row.ethereumPublicKey = nil
                let missingKeyState = try MetaAccountSelectionMapper().transform(entity: row).recordState
                didRejectMissingPublicKey = (try? MetaAccountMapper().transform(entity: row)) == nil &&
                    missingKeyState == .unsupported
                row.ethereumPublicKey = publicKey

                row.setValue(Data([0x01]), forKey: "tonAddress")
                let partialTonState = try MetaAccountSelectionMapper().transform(entity: row).recordState
                didRejectPartialTon = (try? MetaAccountMapper().transform(entity: row)) == nil &&
                    partialTonState == .unsupported
                context.rollback()
            } catch {
                callbackError = error
            }
        }
        wait(for: [checked], timeout: Constants.defaultExpectationDuration)
        if let callbackError { throw callbackError }
        XCTAssertTrue(didAcceptValid)
        XCTAssertTrue(didRejectWrongAddress)
        XCTAssertTrue(didRejectMissingPublicKey)
        XCTAssertTrue(didRejectPartialTon)
    }

    func testNonPersistableNilRequiredFieldsQuarantineTheWalletOrSkipTheRowWithoutSaving() throws {
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
                            affectsOnlyChainAccountRow: corruption.affectsOnlyChainAccountRow,
                            skippedRowIssues: projection.chainAccountRecords?.unusable.map(\.issue) ?? [],
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

        let walletCorruptions = observations.filter { !$0.affectsOnlyChainAccountRow }
        XCTAssertFalse(walletCorruptions.isEmpty)
        XCTAssertTrue(walletCorruptions.allSatisfy(\.directMapperRejectsAsInvalid))
        XCTAssertTrue(walletCorruptions.allSatisfy { $0.recordState == .corrupt })
        XCTAssertTrue(walletCorruptions.allSatisfy { !$0.hasProjectedWallet })
        XCTAssertTrue(walletCorruptions.allSatisfy { !$0.allowsStoredRecordUpdates })
        XCTAssertTrue(
            walletCorruptions.allSatisfy { !$0.replacementUpdatesWalletPayload }
        )
        XCTAssertTrue(
            walletCorruptions.allSatisfy { !$0.replacementUpdatesSelection }
        )

        // A per-chain row without a required field is skipped and reported on its own.
        let rowCorruptions = observations.filter(\.affectsOnlyChainAccountRow)
        XCTAssertFalse(rowCorruptions.isEmpty)
        XCTAssertTrue(rowCorruptions.allSatisfy { !$0.directMapperRejectsAsInvalid })
        XCTAssertTrue(rowCorruptions.allSatisfy { $0.recordState == .supported })
        XCTAssertTrue(rowCorruptions.allSatisfy(\.hasProjectedWallet))
        XCTAssertTrue(rowCorruptions.allSatisfy { $0.skippedRowIssues == [.missingField] })
    }

    func testBlankStoredNamesMapToLocalizedFallbackWithoutWritingTheRow() throws {
        XCTAssertEqual(
            R.string.localizable.walletNameUnnamed(preferredLanguages: ["en"]),
            "Unnamed wallet"
        )
        XCTAssertEqual(
            R.string.localizable.walletNameUnnamed(preferredLanguages: ["ja"]),
            "名前のないウォレット"
        )
        let fallback = MetaAccountMapper.localizedFallbackName()
        XCTAssertFalse(fallback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        for storedName in [" ", "\n\t", ""] {
            let facade = UserDataStorageTestFacade()
            let wallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 1)
            try seedStoredWallet(wallet, in: facade) { $0.name = storedName }

            let observation = try performCoreData(in: facade) { context in
                let entity = try self.storedWallet(wallet.metaId, in: context)
                let mapped = try MetaAccountMapper().transform(entity: entity)
                let injected = try MetaAccountMapper(fallbackName: { "Injected fallback" })
                    .transform(entity: entity)
                let projection = try MetaAccountSelectionMapper().transform(entity: entity)

                return (
                    mapped: mapped,
                    injectedName: injected.name,
                    recordState: projection.recordState,
                    projectedName: projection.wallet?.name,
                    storedName: entity.name,
                    hasChanges: context.hasChanges
                )
            }

            let label = "stored name \(storedName.debugDescription)"
            XCTAssertEqual(observation.mapped, wallet.replacingName(fallback), label)
            XCTAssertEqual(observation.injectedName, "Injected fallback", label)
            XCTAssertEqual(observation.recordState, .supported, label)
            XCTAssertEqual(observation.projectedName, fallback, label)
            XCTAssertEqual(observation.storedName, storedName, label)
            XCTAssertFalse(observation.hasChanges, label)
            XCTAssertEqual(try storedFields(wallet.metaId, in: facade).name, storedName, label)
        }
    }

    func testPaddedStoredNameIsKeptVerbatim() throws {
        let facade = UserDataStorageTestFacade()
        let wallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 1)
        try seedStoredWallet(wallet, in: facade) { $0.name = " Main " }

        let mapped = try XCTUnwrap(try fetchWallets(in: facade).first)

        XCTAssertEqual(mapped.name, " Main ")
        XCTAssertEqual(try storedFields(wallet.metaId, in: facade).name, " Main ")
    }

    func testBlankNamedWalletKeepsStoredNameOnUnrelatedSaveAndPersistsRename() throws {
        let facade = UserDataStorageTestFacade()
        let wallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 1)
        try seedStoredWallet(wallet, in: facade) { $0.name = " " }
        let mapped = try XCTUnwrap(try fetchWallets(in: facade).first)
        XCTAssertEqual(mapped.name, MetaAccountMapper.localizedFallbackName())

        // Saving the presented fallback back must not pin one language into the record.
        try saveWallet(mapped.replacingIsBackuped(!mapped.hasBackup), in: facade)

        XCTAssertEqual(
            try storedFields(wallet.metaId, in: facade),
            StoredWalletFields(
                name: " ",
                ethereumAddress: wallet.ethereumAddress?.toHex(),
                ethereumPublicKey: wallet.ethereumPublicKey,
                hasBackup: !wallet.hasBackup
            )
        )

        try saveWallet(mapped.replacingName("Renamed"), in: facade)

        XCTAssertEqual(try storedFields(wallet.metaId, in: facade).name, "Renamed")
        XCTAssertEqual(try fetchWallets(in: facade).map(\.name), ["Renamed"])
    }

    func testLegacyPartialEthereumPairStaysSaveableWithoutChangingStoredFields() throws {
        for keepsPublicKey in [true, false] {
            let facade = UserDataStorageTestFacade()
            let wallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 1)
            let storedAddress = try XCTUnwrap(wallet.ethereumAddress).toHex(includePrefix: true)
            try seedStoredWallet(wallet, in: facade) { entity in
                if keepsPublicKey {
                    entity.ethereumAddress = nil
                } else {
                    // A prefixed address proves that the stored bytes are not re-encoded.
                    entity.ethereumAddress = storedAddress
                    entity.ethereumPublicKey = nil
                }
            }
            let before = try storedFields(wallet.metaId, in: facade)

            let mapped = try XCTUnwrap(try fetchWallets(in: facade).first)
            XCTAssertEqual(mapped.ethereumAddress, keepsPublicKey ? nil : wallet.ethereumAddress)
            XCTAssertEqual(mapped.ethereumPublicKey, keepsPublicKey ? wallet.ethereumPublicKey : nil)

            try saveWallet(mapped.replacingName("Renamed legacy"), in: facade)

            let after = try storedFields(wallet.metaId, in: facade)
            XCTAssertEqual(after.name, "Renamed legacy")
            XCTAssertEqual(after.ethereumAddress, before.ethereumAddress)
            XCTAssertEqual(after.ethereumPublicKey, before.ethereumPublicKey)
            XCTAssertEqual(
                try fetchWallets(in: facade),
                [mapped.replacingName("Renamed legacy")]
            )
        }
    }

    func testSaveRejectsNewOrChangedPartialEthereumPairWithoutMutatingStore() throws {
        let facade = UserDataStorageTestFacade()
        let complete = AccountGenerator.generateMetaAccount(generatingChainAccounts: 1)
        let legacy = AccountGenerator.generateMetaAccount(generatingChainAccounts: 1)
        try seedStoredWallet(complete, in: facade)
        try seedStoredWallet(legacy, in: facade) { $0.ethereumAddress = nil }
        let completeBefore = try storedFields(complete.metaId, in: facade)
        let legacyBefore = try storedFields(legacy.metaId, in: facade)
        let storedLegacy = legacy.replacingEthereumAddress(nil)
        let otherPublicKey = Data(repeating: 0x5A, count: 33)

        let newWallet = AccountGenerator.generateMetaAccount()
        let rejectedSaves: [(String, MetaAccountModel)] = [
            ("complete record loses its address", complete.replacingEthereumAddress(nil)),
            ("complete record loses its public key", complete.replacingEthereumPublicKey(nil)),
            ("new wallet with only a public key", newWallet.replacingEthereumAddress(nil)),
            ("new wallet with only an address", newWallet.replacingEthereumPublicKey(nil)),
            ("partial record changes its public key", storedLegacy.replacingEthereumPublicKey(otherPublicKey)),
            (
                "partial record swaps to the other half",
                storedLegacy.replacingEthereumAddress(legacy.ethereumAddress).replacingEthereumPublicKey(nil)
            )
        ]

        for (label, model) in rejectedSaves {
            XCTAssertThrowsError(try saveWallet(model.replacingName("Rejected"), in: facade), label) { error in
                XCTAssertEqual(error as? MetaAccountMapperError, .invalidWalletRecord, label)
            }
        }

        XCTAssertEqual(try storedFields(complete.metaId, in: facade), completeBefore)
        XCTAssertEqual(try storedFields(legacy.metaId, in: facade), legacyBefore)
        XCTAssertEqual(
            try Set(fetchWallets(in: facade).map(\.metaId)),
            [complete.metaId, legacy.metaId]
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

    private func seedStoredWallet(
        _ wallet: MetaAccountModel,
        in facade: UserDataStorageTestFacade,
        rawEdit: @escaping (CDMetaAccount) -> Void = { _ in }
    ) throws {
        try saveWallet(wallet, in: facade)
        try performCoreData(in: facade) { context in
            try rawEdit(self.storedWallet(wallet.metaId, in: context))
            try context.save()
        }
    }

    private func saveWallet(_ wallet: MetaAccountModel, in facade: UserDataStorageTestFacade) throws {
        let queue = OperationQueue()
        let repository = facade.createRepository(mapper: AnyCoreDataMapper(ManagedMetaAccountMapper()))
        let save = repository.saveOperation(
            { [ManagedMetaAccountModel(info: wallet, isSelected: false)] }, { [] }
        )
        queue.addOperations([save], waitUntilFinished: true)
        _ = try XCTUnwrap(save.result).get()
    }

    private func fetchWallets(in facade: UserDataStorageTestFacade) throws -> [MetaAccountModel] {
        let queue = OperationQueue()
        let repository = facade.createRepository(mapper: AnyCoreDataMapper(ManagedMetaAccountMapper()))
        let fetch = repository.fetchAllOperation(with: RepositoryFetchOptions(
            includesProperties: true, includesSubentities: true
        ))
        queue.addOperations([fetch], waitUntilFinished: true)
        return try XCTUnwrap(fetch.result).get().map(\.info)
    }

    private func storedFields(
        _ metaId: String, in facade: UserDataStorageTestFacade
    ) throws -> StoredWalletFields {
        try performCoreData(in: facade) { context in
            let entity = try self.storedWallet(metaId, in: context)
            return StoredWalletFields(
                name: entity.name,
                ethereumAddress: entity.ethereumAddress,
                ethereumPublicKey: entity.ethereumPublicKey,
                hasBackup: entity.hasBackup
            )
        }
    }

    private func storedWallet(_ metaId: String, in context: NSManagedObjectContext) throws -> CDMetaAccount {
        let request = NSFetchRequest<CDMetaAccount>(entityName: "CDMetaAccount")
        request.predicate = NSPredicate(format: "%K == %@", #keyPath(CDMetaAccount.metaId), metaId)
        guard let entity = try context.fetch(request).first else {
            throw MetaAccountMapperTestFixtureError(message: "Stored wallet \(metaId) was not found")
        }
        return entity
    }

    private func performCoreData<T>(
        in facade: UserDataStorageTestFacade,
        _ body: @escaping (NSManagedObjectContext) throws -> T
    ) throws -> T {
        let completed = expectation(description: "Core Data operation completes")
        var result: Result<T, Error>?

        facade.databaseService.performAsync { context, error in
            defer { completed.fulfill() }
            do {
                if let error {
                    throw error
                }
                guard let context else {
                    throw MetaAccountMapperTestFixtureError(message: "Core Data setup returned no context")
                }
                result = try .success(body(context))
            } catch {
                result = .failure(error)
            }
        }

        wait(for: [completed], timeout: Constants.defaultExpectationDuration)
        guard let result else {
            throw MetaAccountMapperTestFixtureError(message: "Core Data callback produced no result")
        }
        return try result.get()
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

    /// A per-chain row problem costs only that row (IK-11); the wallet stays shown.
    var affectsOnlyChainAccountRow: Bool {
        switch self {
        case .missingChildAccountId, .missingChildChainId, .missingChildPublicKey:
            return true
        case .missingMetaId, .missingName:
            return false
        }
    }

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
    let affectsOnlyChainAccountRow: Bool
    let skippedRowIssues: [StoredChainAccountIssue]
    let coreDataRejectsInsert: Bool
    let directMapperRejectsAsInvalid: Bool
    let recordState: MetaAccountSelectionRecordState
    let hasProjectedWallet: Bool
    let allowsStoredRecordUpdates: Bool
    let replacementUpdatesWalletPayload: Bool
    let replacementUpdatesSelection: Bool
}

private struct StoredWalletFields: Equatable {
    let name: String?
    let ethereumAddress: String?
    let ethereumPublicKey: Data?
    let hasBackup: Bool
}

private struct MetaAccountMapperTestFixtureError: Error, CustomStringConvertible {
    let message: String

    var description: String {
        message
    }
}
