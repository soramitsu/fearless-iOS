import XCTest
@testable import fearless
import CoreData
import RobinHood
import enum SSFModels.CryptoType
import struct SSFModels.ChainAccountModel

class SelectedAccountSettingsTests: XCTestCase {
    func testSelectFirst() throws {
        // given

        let operationQueue = OperationQueue()
        let facade = UserDataStorageTestFacade()
        let selectedAccountSettings = SelectedWalletSettings(
            storageFacade: facade,
            operationQueue: operationQueue
        )

        let mapper = ManagedMetaAccountMapper()
        let repository = facade.createRepository(mapper: AnyCoreDataMapper(mapper))

        let selectedAccount = ManagedMetaAccountModel(
            info: AccountGenerator.generateMetaAccount(generatingChainAccounts: 2),
            isSelected: true
        )

        // when

        let setupExpectation = XCTestExpectation()
        selectedAccountSettings.setup(runningCompletionIn: .main) { _ in
            setupExpectation.fulfill()
        }

        wait(for: [setupExpectation], timeout: Constants.defaultExpectationDuration)

        XCTAssertNil(selectedAccountSettings.value)

        let saveExpectation = XCTestExpectation()
        selectedAccountSettings.save(value: selectedAccount.info, runningCompletionIn: .main) { _ in
            saveExpectation.fulfill()
        }

        wait(for: [saveExpectation], timeout: Constants.defaultExpectationDuration)

        // then

        XCTAssertEqual(selectedAccountSettings.value, selectedAccount.info)

        let allMetaAccountsOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        operationQueue.addOperations([allMetaAccountsOperation], waitUntilFinished: true)

        let allMetaAccounts = try allMetaAccountsOperation.extractResultData(
            throwing: BaseOperationError.parentOperationCancelled
        )

        XCTAssertEqual(selectedAccount.info, allMetaAccounts.first?.info)
        XCTAssertEqual(allMetaAccounts.count, 1)
        XCTAssertEqual(allMetaAccounts.first?.isSelected, true)
    }

    func testChangeSelectedAccount() throws {
        // given

        let operationQueue = OperationQueue()
        let facade = UserDataStorageTestFacade()
        let selectedAccountSettings = SelectedWalletSettings(
            storageFacade: facade,
            operationQueue: operationQueue
        )

        let mapper = ManagedMetaAccountMapper()
        let repository = facade.createRepository(mapper: AnyCoreDataMapper(mapper))

        let initialSelectedAccount = ManagedMetaAccountModel(
            info: AccountGenerator.generateMetaAccount(generatingChainAccounts: 2),
            isSelected: true
        )

        let nextSelectedAccount = AccountGenerator.generateMetaAccount(generatingChainAccounts: 2)

        let saveOperation = repository.saveOperation({ [initialSelectedAccount] }, { [] })
        operationQueue.addOperations([saveOperation], waitUntilFinished: true)

        // when

        let setupExpectation = XCTestExpectation()
        selectedAccountSettings.setup(runningCompletionIn: .main) { _ in
            setupExpectation.fulfill()
        }

        wait(for: [setupExpectation], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(selectedAccountSettings.value, initialSelectedAccount.info)

        let saveExpectation = XCTestExpectation()
        selectedAccountSettings.save(value: nextSelectedAccount, runningCompletionIn: .main) { _ in
            saveExpectation.fulfill()
        }

        wait(for: [saveExpectation], timeout: Constants.defaultExpectationDuration)

        // then

        XCTAssertEqual(selectedAccountSettings.value, nextSelectedAccount)

        let allMetaAccountsOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        operationQueue.addOperations([allMetaAccountsOperation], waitUntilFinished: true)

        let allMetaAccounts = try allMetaAccountsOperation.extractResultData(
            throwing: BaseOperationError.parentOperationCancelled
        )

        let expectedAccounts = [initialSelectedAccount.info, nextSelectedAccount].reduce(
            into: [String: fearless.MetaAccountModel]()
        ) { result, account in
            result[account.metaId] = account
        }

        let actualAccounts = allMetaAccounts.reduce(into: [String: fearless.MetaAccountModel]()) { result, account in
            result[account.identifier] = account.info
        }

        XCTAssertEqual(expectedAccounts, actualAccounts)
    }

    func testSetupWhenWalletsExistWithoutSelectionRepairsDeterministicFallback() throws {
        let operationQueue = OperationQueue()
        let facade = UserDataStorageTestFacade()
        let selectedAccountSettings = SelectedWalletSettings(
            storageFacade: facade,
            operationQueue: operationQueue
        )
        let repository = facade.createRepository(
            mapper: AnyCoreDataMapper(ManagedMetaAccountMapper())
        )
        let firstByOrder = ManagedMetaAccountModel(
            info: AccountGenerator.generateMetaAccount(generatingChainAccounts: 1),
            isSelected: false,
            order: 1
        )
        let laterByOrder = ManagedMetaAccountModel(
            info: AccountGenerator.generateMetaAccount(generatingChainAccounts: 1),
            isSelected: false,
            order: 2
        )

        let seedOperation = repository.saveOperation({
            [firstByOrder, laterByOrder]
        }, {
            []
        })
        operationQueue.addOperations([seedOperation], waitUntilFinished: true)
        _ = try XCTUnwrap(seedOperation.result).get()

        let setupExpectation = expectation(description: "missing selection is repaired")
        var setupResult: Result<MetaAccountModel?, Error>?
        selectedAccountSettings.setup(runningCompletionIn: .main) { result in
            setupResult = result
            setupExpectation.fulfill()
        }

        wait(for: [setupExpectation], timeout: Constants.defaultExpectationDuration)

        let selectedWallet = try XCTUnwrap(try setupResult?.get())
        XCTAssertEqual(selectedWallet, firstByOrder.info)
        XCTAssertEqual(selectedAccountSettings.value, firstByOrder.info)

        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        operationQueue.addOperations([fetchOperation], waitUntilFinished: true)
        let persistedAccounts: [ManagedMetaAccountModel] = try XCTUnwrap(fetchOperation.result).get()
        let selectedAccounts = persistedAccounts.filter(\.isSelected)

        XCTAssertEqual(selectedAccounts.map(\.identifier), [firstByOrder.identifier])
        XCTAssertEqual(persistedAccounts.count, 2)
    }

    func testSetupToleratesTonOnlyRowAlongsideSelectedValidWalletWithoutChangingEitherPayload() throws {
        let operationQueue = OperationQueue()
        let facade = UserDataStorageTestFacade()
        let selectedAccountSettings = SelectedWalletSettings(
            storageFacade: facade,
            operationQueue: operationQueue
        )
        let validWallet = ManagedMetaAccountModel(
            info: AccountGenerator.generateMetaAccount(generatingChainAccounts: 1),
            isSelected: true,
            order: 2
        )

        try seed([validWallet], in: facade, using: operationQueue)
        try insertTonOnlyWallet(
            identifier: "ton-only-unselected",
            isSelected: false,
            order: 1,
            in: facade,
            malformedChainAccount: true
        )
        let before = try rawWalletSnapshots(in: facade)
        let malformedChainAccountsBefore = try rawChainAccountSnapshots(
            walletIdentifier: "ton-only-unselected",
            in: facade
        )

        let result = try setup(selectedAccountSettings)

        XCTAssertEqual(result, validWallet.info)
        XCTAssertEqual(selectedAccountSettings.value, validWallet.info)
        XCTAssertEqual(selectedAccountSettings.storeState, .ready)
        XCTAssertEqual(try rawWalletSnapshots(in: facade), before)
        XCTAssertEqual(
            try rawChainAccountSnapshots(
                walletIdentifier: "ton-only-unselected",
                in: facade
            ),
            malformedChainAccountsBefore
        )
    }

    func testSetupWithOnlyTonOnlyWalletReportsUnsupportedWithoutMutatingRow() throws {
        let operationQueue = OperationQueue()
        let facade = UserDataStorageTestFacade()
        let selectedAccountSettings = SelectedWalletSettings(
            storageFacade: facade,
            operationQueue: operationQueue
        )

        try insertTonOnlyWallet(
            identifier: "ton-only-selected",
            isSelected: true,
            order: 1,
            in: facade,
            malformedChainAccount: true
        )
        let before = try rawWalletSnapshots(in: facade)
        let malformedChainAccountsBefore = try rawChainAccountSnapshots(
            walletIdentifier: "ton-only-selected",
            in: facade
        )

        let result = try setup(selectedAccountSettings)

        XCTAssertNil(result)
        XCTAssertNil(selectedAccountSettings.value)
        XCTAssertEqual(selectedAccountSettings.storeState, .unsupportedOnly)
        XCTAssertEqual(try rawWalletSnapshots(in: facade), before)
        XCTAssertEqual(
            try rawChainAccountSnapshots(
                walletIdentifier: "ton-only-selected",
                in: facade
            ),
            malformedChainAccountsBefore
        )
    }

    func testStartupQuarantinesMixedCorruptSupportedRowsAndPreservesEveryStoredField() throws {
        let operationQueue = OperationQueue()
        let facade = UserDataStorageTestFacade()
        let settings = SelectedWalletSettings(
            storageFacade: facade,
            operationQueue: operationQueue
        )
        let healthyWallet = copyWallet(
            AccountGenerator.generateMetaAccount(generatingChainAccounts: 1),
            identifier: "healthy-wallet"
        )
        let corruptions = PersistedSupportedWalletCorruption.allCases
        let corruptIdentifiers = corruptions.map {
            "corrupt-\($0.identifier)"
        }
        let corruptOrders = Set(
            corruptions.indices.map { Int32($0 + 100) }
        )

        try seed(
            [ManagedMetaAccountModel(info: healthyWallet, isSelected: false)],
            in: facade,
            using: operationQueue
        )

        for (index, corruption) in corruptions.enumerated() {
            try insertCorruptSupportedWallet(
                identifier: corruptIdentifiers[index],
                corruption: corruption,
                isSelected: true,
                order: Int32(index + 100),
                in: facade,
                using: operationQueue
            )
        }

        let corruptRowsBefore = try rawStoredWalletSnapshots(
            orders: corruptOrders,
            in: facade
        )
        let sortDescriptors = [
            NSSortDescriptor(key: #keyPath(CDMetaAccount.metaId), ascending: true)
        ]
        let factory = AccountRepositoryFactory(storageFacade: facade)
        let repository = factory.createMetaAccountRepository(
            for: nil,
            sortDescriptors: sortDescriptors
        )
        let managedRepository = factory.createManagedMetaAccountRepository(
            for: nil,
            sortDescriptors: sortDescriptors
        )
        let options = RepositoryFetchOptions(
            includesProperties: true,
            includesSubentities: true
        )
        let projectionRepository = facade.createRepository(
            mapper: AnyCoreDataMapper(MetaAccountSelectionMapper())
        )
        let projections = try execute(
            projectionRepository.fetchAllOperation(with: options),
            using: operationQueue
        )
        let corruptProjections = projections.filter {
            $0.recordState == .corrupt
        }

        XCTAssertEqual(corruptProjections.count, corruptions.count)
        XCTAssertTrue(corruptProjections.allSatisfy { $0.wallet == nil })
        XCTAssertTrue(
            corruptProjections.allSatisfy {
                !$0.recordState.allowsStoredRecordUpdates
            }
        )
        XCTAssertTrue(
            corruptProjections.allSatisfy {
                let replacement = $0.replacingSelection(!$0.isSelected)
                return replacement.recordState == .corrupt &&
                    !replacement.updatesWalletPayload &&
                    !replacement.updatesSelection
            }
        )
        XCTAssertEqual(
            try execute(
                repository.fetchAllOperation(with: options),
                using: operationQueue
            ),
            [healthyWallet]
        )
        XCTAssertEqual(
            try execute(
                managedRepository.fetchAllOperation(with: options),
                using: operationQueue
            ).map(\.identifier),
            [healthyWallet.identifier]
        )
        XCTAssertEqual(
            try execute(repository.fetchCountOperation(), using: operationQueue),
            1
        )
        XCTAssertEqual(
            try execute(
                repository.fetchOperation(
                    by: { corruptIdentifiers + [healthyWallet.identifier] },
                    options: options
                ),
                using: operationQueue
            ),
            [healthyWallet]
        )

        for identifier in corruptIdentifiers {
            let corruptWallet: MetaAccountModel? = try execute(
                repository.fetchOperation(
                    by: { identifier },
                    options: options
                ),
                using: operationQueue
            )
            XCTAssertNil(corruptWallet, "Corrupt row escaped quarantine: \(identifier)")
        }

        let asyncExpectation = expectation(description: "corrupt-row tolerant async fetch completes")
        var asyncResult: Result<[MetaAccountModel], Error>?
        let asyncRepository = factory.createAsyncMetaAccountRepository(
            for: nil,
            sortDescriptors: sortDescriptors
        )
        Task {
            do {
                asyncResult = .success(try await asyncRepository.fetchAll())
            } catch {
                asyncResult = .failure(error)
            }
            asyncExpectation.fulfill()
        }
        wait(for: [asyncExpectation], timeout: Constants.defaultExpectationDuration)
        XCTAssertEqual(try XCTUnwrap(asyncResult).get(), [healthyWallet])

        XCTAssertEqual(try setup(settings), healthyWallet)
        XCTAssertEqual(settings.value, healthyWallet)
        XCTAssertEqual(settings.storeState, .ready)
        XCTAssertEqual(
            try rawStoredWalletSnapshots(
                orders: corruptOrders,
                in: facade
            ),
            corruptRowsBefore
        )

        _ = try execute(
            repository.saveOperation({ [] }, { corruptIdentifiers }),
            using: operationQueue
        )
        _ = try execute(
            repository.replaceOperation { [healthyWallet] },
            using: operationQueue
        )

        let collidingWallet = copyWallet(
            AccountGenerator.generateMetaAccount(generatingChainAccounts: 1),
            identifier: corruptIdentifiers[0]
        )
        let collisionOperation = repository.saveOperation(
            { [collidingWallet] },
            { [] }
        )
        operationQueue.addOperations([collisionOperation], waitUntilFinished: true)
        XCTAssertThrowsError(try XCTUnwrap(collisionOperation.result).get()) { error in
            guard
                let settingsError = error as? SelectedWalletSettingsError,
                case .unsupportedWalletIdentifierConflict = settingsError
            else {
                return XCTFail("Unexpected collision error: \(error)")
            }
        }

        XCTAssertEqual(
            try rawStoredWalletSnapshots(
                orders: corruptOrders,
                in: facade
            ),
            corruptRowsBefore
        )
        XCTAssertEqual(
            try execute(
                repository.fetchAllOperation(with: options),
                using: operationQueue
            ),
            [healthyWallet]
        )
    }

    func testCorruptOnlyStoreReportsUnavailableAndPreservesEveryStoredField() throws {
        let operationQueue = OperationQueue()
        let facade = UserDataStorageTestFacade()
        let settings = SelectedWalletSettings(
            storageFacade: facade,
            operationQueue: operationQueue
        )
        let corruptions: [PersistedSupportedWalletCorruption] = [
            .malformedSubstrateAccountId,
            .emptyMetaId,
            .whitespaceMetaId,
            .emptyName,
            .whitespaceName
        ]
        let corruptOrders = Set(
            corruptions.indices.map { Int32($0 + 500) }
        )

        for (index, corruption) in corruptions.enumerated() {
            try insertCorruptSupportedWallet(
                identifier: "corrupt-only-\(corruption.identifier)",
                corruption: corruption,
                isSelected: true,
                order: Int32(index + 500),
                in: facade,
                using: operationQueue
            )
        }

        let before = try rawStoredWalletSnapshots(
            orders: corruptOrders,
            in: facade
        )

        XCTAssertNil(try setup(settings))
        XCTAssertNil(settings.value)
        XCTAssertEqual(settings.storeState, .unavailable)
        XCTAssertEqual(
            try rawStoredWalletSnapshots(
                orders: corruptOrders,
                in: facade
            ),
            before
        )
    }

    func testStructurallyValidUnsupportedWalletKeepsUnsupportedOnlyWithCorruptSibling() throws {
        let operationQueue = OperationQueue()
        let facade = UserDataStorageTestFacade()
        let settings = SelectedWalletSettings(
            storageFacade: facade,
            operationQueue: operationQueue
        )

        try insertTonOnlyWallet(
            identifier: "valid-unsupported-ton-wallet",
            isSelected: true,
            order: 1,
            in: facade,
            malformedChainAccount: true
        )
        try insertCorruptSupportedWallet(
            identifier: "corrupt-supported-sibling",
            corruption: .malformedEthereumAddress,
            isSelected: true,
            order: 700,
            in: facade,
            using: operationQueue
        )
        let parentRowsBefore = try rawWalletSnapshots(in: facade)
        let corruptRowBefore = try rawStoredWalletSnapshots(
            orders: [700],
            in: facade
        )
        let tonChildrenBefore = try rawChainAccountSnapshots(
            walletIdentifier: "valid-unsupported-ton-wallet",
            in: facade
        )

        XCTAssertNil(try setup(settings))
        XCTAssertNil(settings.value)
        XCTAssertEqual(settings.storeState, .unsupportedOnly)
        XCTAssertEqual(try rawWalletSnapshots(in: facade), parentRowsBefore)
        XCTAssertEqual(
            try rawStoredWalletSnapshots(orders: [700], in: facade),
            corruptRowBefore
        )
        XCTAssertEqual(
            try rawChainAccountSnapshots(
                walletIdentifier: "valid-unsupported-ton-wallet",
                in: facade
            ),
            tonChildrenBefore
        )
    }

    func testSetupReplacesSelectedTonOnlyRowWithDeterministicValidFallbackAndPreservesPayloads() throws {
        let operationQueue = OperationQueue()
        let facade = UserDataStorageTestFacade()
        let selectedAccountSettings = SelectedWalletSettings(
            storageFacade: facade,
            operationQueue: operationQueue
        )
        let expectedFallback = ManagedMetaAccountModel(
            info: AccountGenerator.generateMetaAccount(generatingChainAccounts: 1),
            isSelected: false,
            order: 2
        )
        let laterWallet = ManagedMetaAccountModel(
            info: AccountGenerator.generateMetaAccount(generatingChainAccounts: 1),
            isSelected: false,
            order: 3
        )

        // New rows receive their order from the mapper, so insert them separately to make
        // the persisted order deterministic instead of relying on a batch's iteration order.
        try seed([expectedFallback], in: facade, using: operationQueue)
        try seed([laterWallet], in: facade, using: operationQueue)
        try insertTonOnlyWallet(
            identifier: "ton-only-selected",
            isSelected: true,
            order: 1,
            in: facade
        )
        let before = try rawWalletSnapshots(in: facade)

        let result = try setup(selectedAccountSettings)
        let after = try rawWalletSnapshots(in: facade)

        XCTAssertEqual(result, expectedFallback.info)
        XCTAssertEqual(selectedAccountSettings.value, expectedFallback.info)
        XCTAssertEqual(selectedAccountSettings.storeState, .ready)
        XCTAssertEqual(after.count, before.count)
        XCTAssertEqual(
            after.filter(\.isSelected).map(\.identifier),
            [expectedFallback.identifier]
        )

        for original in before {
            let updated = try XCTUnwrap(
                after.first { $0.identifier == original.identifier }
            )
            XCTAssertEqual(updated.payload, original.payload)
            XCTAssertEqual(updated.order, original.order)
        }
    }

    func testSaveAfterUnsupportedOnlyAddsValidWalletWithoutOverwritingTonPayload() throws {
        let operationQueue = OperationQueue()
        let facade = UserDataStorageTestFacade()
        let selectedAccountSettings = SelectedWalletSettings(
            storageFacade: facade,
            operationQueue: operationQueue
        )

        try insertTonOnlyWallet(
            identifier: "ton-only-selected",
            isSelected: true,
            order: 7,
            in: facade
        )
        let before = try XCTUnwrap(rawWalletSnapshots(in: facade).first)
        XCTAssertNil(try setup(selectedAccountSettings))
        XCTAssertEqual(selectedAccountSettings.storeState, .unsupportedOnly)

        let validWallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 1)
        XCTAssertEqual(
            try save(validWallet, in: selectedAccountSettings),
            validWallet
        )

        let after = try rawWalletSnapshots(in: facade)
        let preservedTonWallet = try XCTUnwrap(
            after.first { $0.identifier == before.identifier }
        )
        let newValidWallet = try XCTUnwrap(
            after.first { $0.identifier == validWallet.identifier }
        )

        XCTAssertEqual(after.count, 2)
        XCTAssertEqual(preservedTonWallet.payload, before.payload)
        XCTAssertEqual(preservedTonWallet.order, before.order)
        XCTAssertFalse(preservedTonWallet.isSelected)
        XCTAssertTrue(newValidWallet.isSelected)
        XCTAssertEqual(selectedAccountSettings.value, validWallet)
        XCTAssertEqual(selectedAccountSettings.storeState, .ready)
    }

    func testSaveRejectsIdentifierCollisionWithUnsupportedWalletWithoutMutatingStore() throws {
        let operationQueue = OperationQueue()
        let facade = UserDataStorageTestFacade()
        let selectedAccountSettings = SelectedWalletSettings(
            storageFacade: facade,
            operationQueue: operationQueue
        )
        let unsupportedIdentifier = "ton-only-selected"

        try insertTonOnlyWallet(
            identifier: unsupportedIdentifier,
            isSelected: true,
            order: 1,
            in: facade
        )
        let before = try rawWalletSnapshots(in: facade)
        XCTAssertNil(try setup(selectedAccountSettings))

        let generatedWallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 1)
        let collidingWallet = MetaAccountModel(
            metaId: unsupportedIdentifier,
            name: generatedWallet.name,
            substrateAccountId: generatedWallet.substrateAccountId,
            substrateCryptoType: generatedWallet.substrateCryptoType,
            substratePublicKey: generatedWallet.substratePublicKey,
            ethereumAddress: generatedWallet.ethereumAddress,
            ethereumPublicKey: generatedWallet.ethereumPublicKey,
            chainAccounts: generatedWallet.chainAccounts,
            assetKeysOrder: generatedWallet.assetKeysOrder,
            canExportEthereumMnemonic: generatedWallet.canExportEthereumMnemonic,
            unusedChainIds: generatedWallet.unusedChainIds,
            selectedCurrency: generatedWallet.selectedCurrency,
            networkManagmentFilter: generatedWallet.networkManagmentFilter,
            assetsVisibility: generatedWallet.assetsVisibility,
            hasBackup: generatedWallet.hasBackup,
            favouriteChainIds: generatedWallet.favouriteChainIds
        )

        XCTAssertThrowsError(
            try save(collidingWallet, in: selectedAccountSettings)
        ) { error in
            guard
                let settingsError = error as? SelectedWalletSettingsError,
                case .unsupportedWalletIdentifierConflict = settingsError
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        XCTAssertEqual(try rawWalletSnapshots(in: facade), before)
        XCTAssertNil(selectedAccountSettings.value)
        XCTAssertEqual(selectedAccountSettings.storeState, .unsupportedOnly)
    }

    func testAccountRepositoryDeleteAllRemovesSupportedAndUnsupportedWalletsForLogout() throws {
        let operationQueue = OperationQueue()
        let facade = UserDataStorageTestFacade()
        let supportedWallet = ManagedMetaAccountModel(
            info: AccountGenerator.generateMetaAccount(generatingChainAccounts: 1),
            isSelected: true
        )

        try seed([supportedWallet], in: facade, using: operationQueue)
        try insertTonOnlyWallet(
            identifier: "ton-wallet-that-must-be-deleted-on-logout",
            isSelected: false,
            order: 2,
            in: facade
        )
        XCTAssertEqual(try rawWalletSnapshots(in: facade).count, 2)

        let repository = AccountRepositoryFactory(storageFacade: facade)
            .createMetaAccountRepository(for: nil, sortDescriptors: [])
        let deleteAllOperation = repository.deleteAllOperation()
        operationQueue.addOperations([deleteAllOperation], waitUntilFinished: true)
        _ = try XCTUnwrap(deleteAllOperation.result).get()

        XCTAssertEqual(try rawWalletSnapshots(in: facade), [])
    }

    func testFilteredAccountRepositoryDeleteAllRemainsScopedAndIncludesUnsupportedMatches() throws {
        let operationQueue = OperationQueue()
        let facade = UserDataStorageTestFacade()
        let deletedSupportedWallet = ManagedMetaAccountModel(
            info: AccountGenerator.generateMetaAccount(generatingChainAccounts: 1),
            isSelected: true
        )
        let retainedSupportedWallet = ManagedMetaAccountModel(
            info: AccountGenerator.generateMetaAccount(generatingChainAccounts: 1),
            isSelected: false
        )

        try seed(
            [deletedSupportedWallet, retainedSupportedWallet],
            in: facade,
            using: operationQueue
        )
        try insertTonOnlyWallet(
            identifier: "deleted-ton-wallet",
            isSelected: false,
            order: 3,
            in: facade
        )
        try insertTonOnlyWallet(
            identifier: "retained-ton-wallet",
            isSelected: false,
            order: 4,
            in: facade
        )

        let filter = NSPredicate(
            format: "%K IN %@",
            #keyPath(CDMetaAccount.metaId),
            [deletedSupportedWallet.identifier, "deleted-ton-wallet"]
        )
        let repository = AccountRepositoryFactory(storageFacade: facade)
            .createMetaAccountRepository(for: filter, sortDescriptors: [])
        let deleteAllOperation = repository.deleteAllOperation()
        operationQueue.addOperations([deleteAllOperation], waitUntilFinished: true)
        _ = try XCTUnwrap(deleteAllOperation.result).get()

        XCTAssertEqual(
            try rawWalletSnapshots(in: facade).map(\.identifier),
            [retainedSupportedWallet.identifier, "retained-ton-wallet"].sorted()
        )
    }

    func testAccountRepositoriesProjectMixedStoreBeforePagingAndSupportAsyncReads() throws {
        let operationQueue = OperationQueue()
        let facade = UserDataStorageTestFacade()
        let generatedFirst = AccountGenerator.generateMetaAccount(generatingChainAccounts: 1)
        let generatedSecond = AccountGenerator.generateMetaAccount(generatingChainAccounts: 1)
        let firstWallet = copyWallet(generatedFirst, identifier: "a-supported-wallet")
        let secondWallet = copyWallet(generatedSecond, identifier: "c-supported-wallet")

        try seed(
            [
                ManagedMetaAccountModel(info: firstWallet, isSelected: true),
                ManagedMetaAccountModel(info: secondWallet, isSelected: false)
            ],
            in: facade,
            using: operationQueue
        )
        try insertTonOnlyWallet(
            identifier: "b-ton-wallet",
            isSelected: false,
            order: 3,
            in: facade
        )
        let before = try rawWalletSnapshots(in: facade)
        let sortDescriptors = [
            NSSortDescriptor(key: #keyPath(CDMetaAccount.metaId), ascending: true)
        ]
        let factory = AccountRepositoryFactory(storageFacade: facade)
        let metaRepository = factory.createMetaAccountRepository(
            for: nil,
            sortDescriptors: sortDescriptors
        )
        let managedRepository = factory.createManagedMetaAccountRepository(
            for: nil,
            sortDescriptors: sortDescriptors
        )
        let options = RepositoryFetchOptions(
            includesProperties: true,
            includesSubentities: true
        )

        let allMetaAccounts = try execute(
            metaRepository.fetchAllOperation(with: options),
            using: operationQueue
        )
        let allManagedAccounts = try execute(
            managedRepository.fetchAllOperation(with: options),
            using: operationQueue
        )
        let firstPage = try execute(
            metaRepository.fetchOperation(
                by: RepositorySliceRequest(offset: 0, count: 1, reversed: false),
                options: options
            ),
            using: operationQueue
        )
        let secondPage = try execute(
            metaRepository.fetchOperation(
                by: RepositorySliceRequest(offset: 1, count: 1, reversed: false),
                options: options
            ),
            using: operationQueue
        )
        let supportedByIdentifier: MetaAccountModel? = try execute(
            metaRepository.fetchOperation(
                by: { firstWallet.identifier },
                options: options
            ),
            using: operationQueue
        )
        let unsupportedByIdentifier: MetaAccountModel? = try execute(
            metaRepository.fetchOperation(
                by: { "b-ton-wallet" },
                options: options
            ),
            using: operationQueue
        )
        let mixedByIdentifiers: [MetaAccountModel] = try execute(
            metaRepository.fetchOperation(
                by: {
                    [
                        firstWallet.identifier,
                        "b-ton-wallet",
                        secondWallet.identifier
                    ]
                },
                options: options
            ),
            using: operationQueue
        )
        let count = try execute(
            metaRepository.fetchCountOperation(),
            using: operationQueue
        )

        XCTAssertEqual(
            allMetaAccounts.map(\.identifier),
            [firstWallet.identifier, secondWallet.identifier]
        )
        XCTAssertEqual(
            allManagedAccounts.map(\.identifier),
            [firstWallet.identifier, secondWallet.identifier]
        )
        XCTAssertEqual(firstPage.map(\.identifier), [firstWallet.identifier])
        XCTAssertEqual(secondPage.map(\.identifier), [secondWallet.identifier])
        XCTAssertEqual(supportedByIdentifier, firstWallet)
        XCTAssertNil(unsupportedByIdentifier)
        XCTAssertEqual(
            mixedByIdentifiers.map(\.identifier),
            [firstWallet.identifier, secondWallet.identifier]
        )
        XCTAssertEqual(count, 2)

        let asyncExpectation = expectation(description: "async mixed-store fetch completes")
        var asyncResult: Result<[MetaAccountModel], Error>?
        let asyncRepository = factory.createAsyncMetaAccountRepository(
            for: nil,
            sortDescriptors: sortDescriptors
        )
        Task {
            do {
                asyncResult = .success(try await asyncRepository.fetchAll())
            } catch {
                asyncResult = .failure(error)
            }
            asyncExpectation.fulfill()
        }

        wait(for: [asyncExpectation], timeout: Constants.defaultExpectationDuration)
        XCTAssertEqual(
            try XCTUnwrap(asyncResult).get().map(\.identifier),
            [firstWallet.identifier, secondWallet.identifier]
        )
        XCTAssertEqual(try rawWalletSnapshots(in: facade), before)
    }

    func testRepositoryPagingSlicesHealthyProjectionAcrossPersistedCorruptRows() throws {
        let operationQueue = OperationQueue()
        let facade = UserDataStorageTestFacade()
        let healthyWallets = [
            copyWallet(
                AccountGenerator.generateMetaAccount(generatingChainAccounts: 1),
                identifier: "b-healthy-first"
            ),
            copyWallet(
                AccountGenerator.generateMetaAccount(generatingChainAccounts: 1),
                identifier: "d-healthy-second"
            ),
            copyWallet(
                AccountGenerator.generateMetaAccount(generatingChainAccounts: 1),
                identifier: "e-healthy-third"
            )
        ]
        let corruptOrders: Set<Int32> = [800, 801, 802]

        try seed(
            healthyWallets.enumerated().map {
                ManagedMetaAccountModel(
                    info: $0.element,
                    isSelected: $0.offset == 0
                )
            },
            in: facade,
            using: operationQueue
        )
        try insertCorruptSupportedWallet(
            identifier: "a-corrupt-before",
            corruption: .malformedSubstrateAccountId,
            isSelected: false,
            order: 800,
            in: facade,
            using: operationQueue
        )
        try insertCorruptSupportedWallet(
            identifier: "c-corrupt-inside",
            corruption: .shortChainPublicKey,
            isSelected: false,
            order: 801,
            in: facade,
            using: operationQueue
        )
        try insertCorruptSupportedWallet(
            identifier: "f-corrupt-after",
            corruption: .emptyName,
            isSelected: false,
            order: 802,
            in: facade,
            using: operationQueue
        )

        let corruptRowsBefore = try rawStoredWalletSnapshots(
            orders: corruptOrders,
            in: facade
        )
        let sortDescriptors = [
            NSSortDescriptor(key: #keyPath(CDMetaAccount.metaId), ascending: true)
        ]
        let factory = AccountRepositoryFactory(storageFacade: facade)
        let repository = factory.createMetaAccountRepository(
            for: nil,
            sortDescriptors: sortDescriptors
        )
        let managedRepository = factory.createManagedMetaAccountRepository(
            for: nil,
            sortDescriptors: sortDescriptors
        )
        let options = RepositoryFetchOptions(
            includesProperties: true,
            includesSubentities: true
        )

        func page(
            offset: Int,
            count: Int,
            reversed: Bool
        ) throws -> [String] {
            try execute(
                repository.fetchOperation(
                    by: RepositorySliceRequest(
                        offset: offset,
                        count: count,
                        reversed: reversed
                    ),
                    options: options
                ),
                using: operationQueue
            ).map(\.identifier)
        }

        func managedPage(
            offset: Int,
            count: Int,
            reversed: Bool
        ) throws -> [String] {
            try execute(
                managedRepository.fetchOperation(
                    by: RepositorySliceRequest(
                        offset: offset,
                        count: count,
                        reversed: reversed
                    ),
                    options: options
                ),
                using: operationQueue
            ).map(\.identifier)
        }

        let forwardIdentifiers = healthyWallets.map(\.identifier)
        let reversedIdentifiers = Array(forwardIdentifiers.reversed())

        XCTAssertEqual(try page(offset: 0, count: 1, reversed: false), [forwardIdentifiers[0]])
        XCTAssertEqual(try page(offset: 1, count: 1, reversed: false), [forwardIdentifiers[1]])
        XCTAssertEqual(try page(offset: 2, count: 1, reversed: false), [forwardIdentifiers[2]])
        XCTAssertEqual(
            try page(offset: 0, count: 2, reversed: false),
            Array(forwardIdentifiers.prefix(2))
        )
        XCTAssertEqual(
            try page(offset: 1, count: 2, reversed: false),
            Array(forwardIdentifiers.dropFirst())
        )
        XCTAssertEqual(
            try page(offset: 0, count: Int.max, reversed: false),
            forwardIdentifiers
        )
        XCTAssertEqual(try page(offset: 0, count: 0, reversed: false), [])
        XCTAssertEqual(try page(offset: 3, count: 1, reversed: false), [])
        XCTAssertEqual(
            try page(offset: Int.max, count: Int.max, reversed: false),
            []
        )

        XCTAssertEqual(try page(offset: 0, count: 1, reversed: true), [reversedIdentifiers[0]])
        XCTAssertEqual(try page(offset: 1, count: 1, reversed: true), [reversedIdentifiers[1]])
        XCTAssertEqual(try page(offset: 2, count: 1, reversed: true), [reversedIdentifiers[2]])
        XCTAssertEqual(
            try page(offset: 0, count: 2, reversed: true),
            Array(reversedIdentifiers.prefix(2))
        )
        XCTAssertEqual(
            try page(offset: 1, count: 2, reversed: true),
            Array(reversedIdentifiers.dropFirst())
        )
        XCTAssertEqual(try page(offset: 0, count: 0, reversed: true), [])
        XCTAssertEqual(try page(offset: 3, count: 1, reversed: true), [])

        XCTAssertEqual(
            try managedPage(offset: 0, count: 3, reversed: false),
            forwardIdentifiers
        )
        XCTAssertEqual(
            try managedPage(offset: 0, count: 3, reversed: true),
            reversedIdentifiers
        )
        XCTAssertEqual(
            try execute(repository.fetchCountOperation(), using: operationQueue),
            healthyWallets.count
        )
        XCTAssertEqual(
            try rawStoredWalletSnapshots(orders: corruptOrders, in: facade),
            corruptRowsBefore
        )
    }

    func testAccountRepositoryUpdatePreservesUnsupportedPayloadAndWalletMetadata() throws {
        let operationQueue = OperationQueue()
        let facade = UserDataStorageTestFacade()
        let wallet = ManagedMetaAccountModel(
            info: AccountGenerator.generateMetaAccount(generatingChainAccounts: 1),
            isSelected: true
        )

        try seed([wallet], in: facade, using: operationQueue)
        try insertTonOnlyWallet(
            identifier: "ton-wallet-preserved-across-update",
            isSelected: false,
            order: 17,
            in: facade
        )
        let before = try rawWalletSnapshots(in: facade)
        let walletBefore = try XCTUnwrap(
            before.first { $0.identifier == wallet.identifier }
        )
        let tonBefore = try XCTUnwrap(
            before.first { $0.identifier == "ton-wallet-preserved-across-update" }
        )
        let renamedWallet = copyWallet(
            wallet.info,
            identifier: wallet.identifier,
            name: "Renamed without collateral damage"
        )
        let repository = AccountRepositoryFactory(storageFacade: facade)
            .createMetaAccountRepository(for: nil, sortDescriptors: [])

        _ = try execute(
            repository.saveOperation({ [renamedWallet] }, { [] }),
            using: operationQueue
        )

        let after = try rawWalletSnapshots(in: facade)
        let walletAfter = try XCTUnwrap(
            after.first { $0.identifier == wallet.identifier }
        )
        XCTAssertEqual(
            after.first { $0.identifier == tonBefore.identifier },
            tonBefore
        )
        XCTAssertEqual(walletAfter.order, walletBefore.order)
        XCTAssertEqual(walletAfter.isSelected, walletBefore.isSelected)
        XCTAssertEqual(walletAfter.payload, walletBefore.payload)
    }

    func testAccountRepositoryReplacePreservesUnsupportedRowsAndDeletesOnlySupportedRows() throws {
        let operationQueue = OperationQueue()
        let facade = UserDataStorageTestFacade()
        let removedWallet = copyWallet(
            AccountGenerator.generateMetaAccount(generatingChainAccounts: 1),
            identifier: "removed-supported-wallet"
        )
        let retainedWallet = copyWallet(
            AccountGenerator.generateMetaAccount(generatingChainAccounts: 1),
            identifier: "retained-supported-wallet"
        )

        try seed(
            [
                ManagedMetaAccountModel(info: removedWallet, isSelected: true),
                ManagedMetaAccountModel(info: retainedWallet, isSelected: false)
            ],
            in: facade,
            using: operationQueue
        )
        try insertTonOnlyWallet(
            identifier: "preserved-ton-wallet",
            isSelected: false,
            order: 3,
            in: facade
        )
        let tonBefore = try XCTUnwrap(
            rawWalletSnapshots(in: facade).first {
                $0.identifier == "preserved-ton-wallet"
            }
        )
        let renamedWallet = copyWallet(
            retainedWallet,
            identifier: retainedWallet.identifier,
            name: "Retained and updated"
        )
        let repository = AccountRepositoryFactory(storageFacade: facade)
            .createMetaAccountRepository(for: nil, sortDescriptors: [])

        _ = try execute(
            repository.replaceOperation { [renamedWallet] },
            using: operationQueue
        )

        let after = try rawWalletSnapshots(in: facade)
        XCTAssertNil(after.first { $0.identifier == removedWallet.identifier })
        XCTAssertNotNil(after.first { $0.identifier == renamedWallet.identifier })
        XCTAssertEqual(
            after.first { $0.identifier == tonBefore.identifier },
            tonBefore
        )

        let storedWallets = try execute(
            repository.fetchAllOperation(with: RepositoryFetchOptions()),
            using: operationQueue
        )
        XCTAssertEqual(storedWallets, [renamedWallet])
    }

    func testAccountRepositoryRejectsUnsupportedIdentifierCollisionWithoutMutation() throws {
        let operationQueue = OperationQueue()
        let facade = UserDataStorageTestFacade()
        let collidingIdentifier = "existing-ton-wallet"

        try insertTonOnlyWallet(
            identifier: collidingIdentifier,
            isSelected: true,
            order: 1,
            in: facade
        )
        let before = try rawWalletSnapshots(in: facade)
        let collidingWallet = copyWallet(
            AccountGenerator.generateMetaAccount(generatingChainAccounts: 1),
            identifier: collidingIdentifier
        )
        let repository = AccountRepositoryFactory(storageFacade: facade)
            .createMetaAccountRepository(for: nil, sortDescriptors: [])
        let saveOperation = repository.saveOperation({ [collidingWallet] }, { [] })
        operationQueue.addOperations([saveOperation], waitUntilFinished: true)

        XCTAssertThrowsError(try XCTUnwrap(saveOperation.result).get()) { error in
            guard
                let settingsError = error as? SelectedWalletSettingsError,
                case .unsupportedWalletIdentifierConflict = settingsError
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertEqual(try rawWalletSnapshots(in: facade), before)
    }

    func testManagedMapperFailsSafelyWhenWalletOrderHasReachedInt32Max() throws {
        let operationQueue = OperationQueue()
        let facade = UserDataStorageTestFacade()
        let existingWallet = ManagedMetaAccountModel(
            info: AccountGenerator.generateMetaAccount(generatingChainAccounts: 1),
            isSelected: true
        )

        try seed([existingWallet], in: facade, using: operationQueue)
        try setRawWalletOrder(
            identifier: existingWallet.identifier,
            order: Int32.max,
            in: facade
        )
        let before = try rawWalletSnapshots(in: facade)
        let newWallet = ManagedMetaAccountModel(
            info: AccountGenerator.generateMetaAccount(generatingChainAccounts: 1),
            isSelected: false
        )
        let repository = facade.createRepository(
            mapper: AnyCoreDataMapper(ManagedMetaAccountMapper())
        )
        let saveOperation = repository.saveOperation({ [newWallet] }, { [] })
        operationQueue.addOperations([saveOperation], waitUntilFinished: true)

        XCTAssertThrowsError(try XCTUnwrap(saveOperation.result).get()) { error in
            guard
                let mapperError = error as? MetaAccountMapperError,
                case .walletOrderOverflow = mapperError
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertEqual(try rawWalletSnapshots(in: facade), before)
    }

    func testSelectionMapperFailsSafelyWhenUnsupportedWalletOrderHasReachedInt32Max() throws {
        let operationQueue = OperationQueue()
        let facade = UserDataStorageTestFacade()
        let selectedAccountSettings = SelectedWalletSettings(
            storageFacade: facade,
            operationQueue: operationQueue
        )

        try insertTonOnlyWallet(
            identifier: "max-order-ton-wallet",
            isSelected: true,
            order: Int32.max,
            in: facade
        )
        let before = try rawWalletSnapshots(in: facade)
        XCTAssertNil(try setup(selectedAccountSettings))
        XCTAssertEqual(selectedAccountSettings.storeState, .unsupportedOnly)

        XCTAssertThrowsError(
            try save(
                AccountGenerator.generateMetaAccount(generatingChainAccounts: 1),
                in: selectedAccountSettings
            )
        ) { error in
            guard
                let mapperError = error as? MetaAccountMapperError,
                case .walletOrderOverflow = mapperError
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        XCTAssertEqual(try rawWalletSnapshots(in: facade), before)
        XCTAssertNil(selectedAccountSettings.value)
        XCTAssertEqual(selectedAccountSettings.storeState, .unsupportedOnly)
    }

    func testOutOfOrderSetupCannotOverwriteLatestValueStateOrPersistStaleRepair() throws {
        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 8
        let currentFacade = UserDataStorageTestFacade()
        let staleFacade = UserDataStorageTestFacade()
        let firstWallet = copyWallet(
            AccountGenerator.generateMetaAccount(generatingChainAccounts: 1),
            identifier: "first-wallet"
        )
        let latestWallet = copyWallet(
            AccountGenerator.generateMetaAccount(generatingChainAccounts: 1),
            identifier: "latest-wallet"
        )

        try seed(
            [ManagedMetaAccountModel(info: firstWallet, isSelected: false)],
            in: currentFacade,
            using: operationQueue
        )
        try seed(
            [ManagedMetaAccountModel(info: latestWallet, isSelected: true)],
            in: currentFacade,
            using: operationQueue
        )
        try seed(
            [ManagedMetaAccountModel(info: firstWallet, isSelected: false)],
            in: staleFacade,
            using: operationQueue
        )
        try seed(
            [ManagedMetaAccountModel(info: latestWallet, isSelected: false)],
            in: staleFacade,
            using: operationQueue
        )

        let firstRequest = expectation(description: "first setup reaches Core Data")
        let latestRequest = expectation(description: "latest setup reaches Core Data")
        let controlledService = ControllableWalletCoreDataService(
            configuration: currentFacade.databaseService.configuration,
            requestExpectations: [firstRequest, latestRequest]
        )
        let controlledFacade = ControllableWalletStorageFacade(
            databaseService: controlledService
        )
        let settings = SelectedWalletSettings(
            storageFacade: controlledFacade,
            operationQueue: operationQueue
        )
        let staleCompletion = expectation(description: "stale setup completes")
        let latestCompletion = expectation(description: "latest setup completes")
        var staleResult: Result<MetaAccountModel?, Error>?
        var latestResult: Result<MetaAccountModel?, Error>?

        settings.setup(runningCompletionIn: .main) {
            staleResult = $0
            staleCompletion.fulfill()
        }
        wait(for: [firstRequest], timeout: Constants.defaultExpectationDuration)

        settings.setup(runningCompletionIn: .main) {
            latestResult = $0
            latestCompletion.fulfill()
        }
        wait(for: [latestRequest], timeout: Constants.defaultExpectationDuration)

        try controlledService.resolveRequest(
            at: 1,
            using: currentFacade.databaseService
        )
        wait(for: [latestCompletion], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(try XCTUnwrap(latestResult).get(), latestWallet)
        XCTAssertEqual(settings.value, latestWallet)
        XCTAssertEqual(settings.storeState, .ready)

        try controlledService.resolveRequest(
            at: 0,
            using: staleFacade.databaseService
        )
        wait(for: [staleCompletion], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(try XCTUnwrap(staleResult).get(), firstWallet)
        XCTAssertEqual(settings.value, latestWallet)
        XCTAssertEqual(settings.storeState, .ready)
        XCTAssertEqual(controlledService.requestCount, 2)
        XCTAssertEqual(
            try rawWalletSnapshots(in: currentFacade)
                .filter(\.isSelected)
                .map(\.identifier),
            [latestWallet.identifier]
        )
        XCTAssertEqual(
            try rawWalletSnapshots(in: staleFacade)
                .filter(\.isSelected)
                .map(\.identifier),
            []
        )
    }

    func testSetupGenerationCannotChangeInsideAtomicValueAndStateCommit() throws {
        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 8
        let firstFacade = UserDataStorageTestFacade()
        let latestFacade = UserDataStorageTestFacade()
        let firstWallet = copyWallet(
            AccountGenerator.generateMetaAccount(generatingChainAccounts: 1),
            identifier: "first-wallet"
        )
        let latestWallet = copyWallet(
            AccountGenerator.generateMetaAccount(generatingChainAccounts: 1),
            identifier: "latest-wallet"
        )

        try seed(
            [ManagedMetaAccountModel(info: firstWallet, isSelected: true)],
            in: firstFacade,
            using: operationQueue
        )
        try seed(
            [ManagedMetaAccountModel(info: latestWallet, isSelected: true)],
            in: latestFacade,
            using: operationQueue
        )

        let firstFetch = expectation(description: "first setup fetch starts")
        let latestFetch = expectation(description: "latest setup waits for atomic commit")
        let firstCommitEntered = expectation(description: "first setup begins atomic commit")
        let releaseFirstCommit = DispatchSemaphore(value: 0)
        let setupPrepared = DispatchSemaphore(value: 0)
        let commitCountLock = NSLock()
        var commitCount = 0
        let controlledService = ControllableWalletCoreDataService(
            configuration: firstFacade.databaseService.configuration,
            requestExpectations: [firstFetch, latestFetch]
        )
        let settings = SelectedWalletSettings(
            storageFacade: ControllableWalletStorageFacade(
                databaseService: controlledService
            ),
            operationQueue: operationQueue,
            setupPreparationHook: {
                setupPrepared.signal()
            },
            setupCommitHook: {
                commitCountLock.lock()
                commitCount += 1
                let shouldPause = commitCount == 1
                commitCountLock.unlock()

                if shouldPause {
                    firstCommitEntered.fulfill()
                    _ = releaseFirstCommit.wait(
                        timeout: .now() + Constants.defaultExpectationDuration
                    )
                }
            }
        )
        let firstCompletion = expectation(description: "first setup completes")
        let latestInvocationStarted = expectation(description: "latest setup invocation starts")
        let latestCompletion = expectation(description: "latest setup completes")
        var firstResult: Result<MetaAccountModel?, Error>?
        var latestResult: Result<MetaAccountModel?, Error>?

        settings.setup(runningCompletionIn: .main) {
            firstResult = $0
            firstCompletion.fulfill()
        }
        XCTAssertEqual(
            setupPrepared.wait(
                timeout: .now() + Constants.defaultExpectationDuration
            ),
            .success
        )
        wait(for: [firstFetch], timeout: Constants.defaultExpectationDuration)
        try controlledService.resolveRequest(
            at: 0,
            using: firstFacade.databaseService
        )
        wait(for: [firstCommitEntered], timeout: Constants.defaultExpectationDuration)

        DispatchQueue.global().async {
            latestInvocationStarted.fulfill()
            settings.setup(runningCompletionIn: .main) {
                latestResult = $0
                latestCompletion.fulfill()
            }
        }
        wait(for: [latestInvocationStarted], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(
            setupPrepared.wait(timeout: .now() + 0.2),
            .timedOut
        )
        XCTAssertEqual(controlledService.requestCount, 1)

        releaseFirstCommit.signal()
        wait(
            for: [firstCompletion, latestFetch],
            timeout: Constants.defaultExpectationDuration
        )
        XCTAssertEqual(
            setupPrepared.wait(
                timeout: .now() + Constants.defaultExpectationDuration
            ),
            .success
        )

        try controlledService.resolveRequest(
            at: 1,
            using: latestFacade.databaseService
        )
        wait(for: [latestCompletion], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(try XCTUnwrap(firstResult).get(), firstWallet)
        XCTAssertEqual(try XCTUnwrap(latestResult).get(), latestWallet)
        XCTAssertEqual(settings.value, latestWallet)
        XCTAssertEqual(settings.storeState, .ready)
        XCTAssertEqual(controlledService.requestCount, 2)
    }

    func testConcurrentSavesAreSerializedAndOlderFailureCannotRollbackLatestSelection() throws {
        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 8
        let sourceFacade = UserDataStorageTestFacade()
        let initialWallet = copyWallet(
            AccountGenerator.generateMetaAccount(generatingChainAccounts: 1),
            identifier: "initial-wallet"
        )
        let olderWallet = copyWallet(
            AccountGenerator.generateMetaAccount(generatingChainAccounts: 1),
            identifier: "older-wallet"
        )
        let latestWallet = copyWallet(
            AccountGenerator.generateMetaAccount(generatingChainAccounts: 1),
            identifier: "latest-wallet"
        )

        try seed(
            [ManagedMetaAccountModel(info: initialWallet, isSelected: true)],
            in: sourceFacade,
            using: operationQueue
        )
        try seed(
            [ManagedMetaAccountModel(info: olderWallet, isSelected: false)],
            in: sourceFacade,
            using: operationQueue
        )
        try seed(
            [ManagedMetaAccountModel(info: latestWallet, isSelected: false)],
            in: sourceFacade,
            using: operationQueue
        )

        let olderFetch = expectation(description: "older save fetch starts")
        let latestFetch = expectation(description: "latest save waits then fetches")
        let latestPersist = expectation(description: "latest save persists")
        let controlledService = ControllableWalletCoreDataService(
            configuration: sourceFacade.databaseService.configuration,
            requestExpectations: [olderFetch, latestFetch, latestPersist]
        )
        let settings = SelectedWalletSettings(
            storageFacade: ControllableWalletStorageFacade(
                databaseService: controlledService
            ),
            operationQueue: operationQueue
        )
        let olderCompletion = expectation(description: "older save fails")
        let latestCompletion = expectation(description: "latest save succeeds")
        var olderResult: Result<MetaAccountModel, Error>?
        var latestResult: Result<MetaAccountModel, Error>?

        settings.save(value: olderWallet, runningCompletionIn: .main) {
            olderResult = $0
            olderCompletion.fulfill()
        }
        wait(for: [olderFetch], timeout: Constants.defaultExpectationDuration)

        settings.save(value: latestWallet, runningCompletionIn: .main) {
            latestResult = $0
            latestCompletion.fulfill()
        }

        XCTAssertEqual(settings.value, latestWallet)
        XCTAssertEqual(controlledService.requestCount, 1)

        try controlledService.failRequest(
            at: 0,
            with: ControllableWalletCoreDataServiceError.injectedFailure
        )
        wait(
            for: [olderCompletion, latestFetch],
            timeout: Constants.defaultExpectationDuration
        )

        XCTAssertThrowsError(try XCTUnwrap(olderResult).get())
        XCTAssertEqual(settings.value, latestWallet)

        try controlledService.resolveRequest(
            at: 1,
            using: sourceFacade.databaseService
        )
        wait(for: [latestPersist], timeout: Constants.defaultExpectationDuration)
        try controlledService.resolveRequest(
            at: 2,
            using: sourceFacade.databaseService
        )
        wait(for: [latestCompletion], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(try XCTUnwrap(latestResult).get(), latestWallet)
        XCTAssertEqual(settings.value, latestWallet)
        XCTAssertEqual(settings.storeState, .ready)
        XCTAssertEqual(controlledService.requestCount, 3)
        XCTAssertEqual(
            try rawWalletSnapshots(in: sourceFacade)
                .filter(\.isSelected)
                .map(\.identifier),
            [latestWallet.identifier]
        )
    }

    func testSaveInvalidatesOlderSetupBeforeItCanCommitOrRepairSelection() throws {
        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 8
        let currentFacade = UserDataStorageTestFacade()
        let staleFacade = UserDataStorageTestFacade()
        let firstWallet = copyWallet(
            AccountGenerator.generateMetaAccount(generatingChainAccounts: 1),
            identifier: "first-wallet"
        )
        let savedWallet = copyWallet(
            AccountGenerator.generateMetaAccount(generatingChainAccounts: 1),
            identifier: "saved-wallet"
        )

        try seed(
            [ManagedMetaAccountModel(info: firstWallet, isSelected: true)],
            in: currentFacade,
            using: operationQueue
        )
        try seed(
            [ManagedMetaAccountModel(info: savedWallet, isSelected: false)],
            in: currentFacade,
            using: operationQueue
        )
        try seed(
            [ManagedMetaAccountModel(info: firstWallet, isSelected: false)],
            in: staleFacade,
            using: operationQueue
        )
        try seed(
            [ManagedMetaAccountModel(info: savedWallet, isSelected: false)],
            in: staleFacade,
            using: operationQueue
        )

        let setupFetch = expectation(description: "setup fetch starts")
        let saveFetch = expectation(description: "save fetch starts")
        let savePersist = expectation(description: "save persists")
        let controlledService = ControllableWalletCoreDataService(
            configuration: currentFacade.databaseService.configuration,
            requestExpectations: [setupFetch, saveFetch, savePersist]
        )
        let settings = SelectedWalletSettings(
            storageFacade: ControllableWalletStorageFacade(
                databaseService: controlledService
            ),
            operationQueue: operationQueue
        )
        let setupCompletion = expectation(description: "stale setup completes")
        let saveCompletion = expectation(description: "save completes")
        var setupResult: Result<MetaAccountModel?, Error>?
        var saveResult: Result<MetaAccountModel, Error>?

        settings.setup(runningCompletionIn: .main) {
            setupResult = $0
            setupCompletion.fulfill()
        }
        wait(for: [setupFetch], timeout: Constants.defaultExpectationDuration)

        settings.save(value: savedWallet, runningCompletionIn: .main) {
            saveResult = $0
            saveCompletion.fulfill()
        }
        wait(for: [saveFetch], timeout: Constants.defaultExpectationDuration)

        try controlledService.resolveRequest(
            at: 1,
            using: currentFacade.databaseService
        )
        wait(for: [savePersist], timeout: Constants.defaultExpectationDuration)
        try controlledService.resolveRequest(
            at: 2,
            using: currentFacade.databaseService
        )
        wait(for: [saveCompletion], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(try XCTUnwrap(saveResult).get(), savedWallet)
        XCTAssertEqual(settings.value, savedWallet)
        XCTAssertEqual(settings.storeState, .ready)

        try controlledService.resolveRequest(
            at: 0,
            using: staleFacade.databaseService
        )
        wait(for: [setupCompletion], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(try XCTUnwrap(setupResult).get(), firstWallet)
        XCTAssertEqual(settings.value, savedWallet)
        XCTAssertEqual(settings.storeState, .ready)
        XCTAssertEqual(controlledService.requestCount, 3)
        XCTAssertEqual(
            try rawWalletSnapshots(in: currentFacade)
                .filter(\.isSelected)
                .map(\.identifier),
            [savedWallet.identifier]
        )
        XCTAssertEqual(
            try rawWalletSnapshots(in: staleFacade)
                .filter(\.isSelected)
                .map(\.identifier),
            []
        )
    }

    func testSetupStartedDuringSaveWaitsForPersistenceAndCannotReadStaleSelection() throws {
        let asynchronousTimeout =
            Constants.defaultExpectationDuration * 4
        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 8
        let sourceFacade = UserDataStorageTestFacade()
        let initialWallet = copyWallet(
            AccountGenerator.generateMetaAccount(generatingChainAccounts: 1),
            identifier: "initial-wallet"
        )
        let savedWallet = copyWallet(
            AccountGenerator.generateMetaAccount(generatingChainAccounts: 1),
            identifier: "saved-wallet"
        )

        try seed(
            [ManagedMetaAccountModel(info: initialWallet, isSelected: true)],
            in: sourceFacade,
            using: operationQueue
        )
        try seed(
            [ManagedMetaAccountModel(info: savedWallet, isSelected: false)],
            in: sourceFacade,
            using: operationQueue
        )

        let saveFetch = expectation(description: "save fetch starts")
        let savePersist = expectation(description: "save persists")
        let setupFetch = expectation(description: "setup starts after save")
        let controlledService = ControllableWalletCoreDataService(
            configuration: sourceFacade.databaseService.configuration,
            requestExpectations: [saveFetch, savePersist, setupFetch]
        )
        let settings = SelectedWalletSettings(
            storageFacade: ControllableWalletStorageFacade(
                databaseService: controlledService
            ),
            operationQueue: operationQueue
        )
        let saveCompletion = expectation(description: "save completes")
        let setupCompletion = expectation(description: "setup completes")
        var saveResult: Result<MetaAccountModel, Error>?
        var setupResult: Result<MetaAccountModel?, Error>?

        settings.save(value: savedWallet, runningCompletionIn: .main) {
            saveResult = $0
            saveCompletion.fulfill()
        }
        wait(for: [saveFetch], timeout: asynchronousTimeout)

        settings.setup(runningCompletionIn: .main) {
            setupResult = $0
            setupCompletion.fulfill()
        }

        XCTAssertEqual(controlledService.requestCount, 1)
        XCTAssertEqual(settings.value, savedWallet)

        try controlledService.resolveRequest(
            at: 0,
            using: sourceFacade.databaseService
        )
        wait(for: [savePersist], timeout: asynchronousTimeout)
        try controlledService.resolveRequest(
            at: 1,
            using: sourceFacade.databaseService
        )
        wait(
            for: [saveCompletion, setupFetch],
            timeout: asynchronousTimeout
        )

        XCTAssertEqual(try XCTUnwrap(saveResult).get(), savedWallet)
        try controlledService.resolveRequest(
            at: 2,
            using: sourceFacade.databaseService
        )
        wait(for: [setupCompletion], timeout: asynchronousTimeout)

        XCTAssertEqual(try XCTUnwrap(setupResult).get(), savedWallet)
        XCTAssertEqual(settings.value, savedWallet)
        XCTAssertEqual(settings.storeState, .ready)
        XCTAssertEqual(
            try rawWalletSnapshots(in: sourceFacade)
                .filter(\.isSelected)
                .map(\.identifier),
            [savedWallet.identifier]
        )
    }

    func testSaveRegistrationIsAtomicAgainstSetupAtPreparationBoundary() throws {
        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 8
        let sourceFacade = UserDataStorageTestFacade()
        let initialWallet = copyWallet(
            AccountGenerator.generateMetaAccount(generatingChainAccounts: 1),
            identifier: "initial-wallet"
        )
        let savedWallet = copyWallet(
            AccountGenerator.generateMetaAccount(generatingChainAccounts: 1),
            identifier: "saved-wallet"
        )

        try seed(
            [ManagedMetaAccountModel(info: initialWallet, isSelected: true)],
            in: sourceFacade,
            using: operationQueue
        )
        try seed(
            [ManagedMetaAccountModel(info: savedWallet, isSelected: false)],
            in: sourceFacade,
            using: operationQueue
        )

        let saveFetch = expectation(description: "save fetch starts")
        let savePersist = expectation(description: "save persists")
        let setupFetch = expectation(description: "setup fetch waits for persistence")
        let savePrepared = expectation(description: "save invalidates setup generation")
        let setupPrepared = expectation(description: "setup replaces generation during paused save")
        let releaseSavePreparation = DispatchSemaphore(value: 0)
        let controlledService = ControllableWalletCoreDataService(
            configuration: sourceFacade.databaseService.configuration,
            requestExpectations: [saveFetch, savePersist, setupFetch]
        )
        let settings = SelectedWalletSettings(
            storageFacade: ControllableWalletStorageFacade(
                databaseService: controlledService
            ),
            operationQueue: operationQueue,
            savePreparationHook: {
                savePrepared.fulfill()
                _ = releaseSavePreparation.wait(
                    timeout: .now() + Constants.defaultExpectationDuration
                )
            },
            setupPreparationHook: {
                setupPrepared.fulfill()
            }
        )
        let saveInvocationReturned = expectation(description: "save invocation returns")
        let setupInvocationReturned = expectation(description: "setup invocation returns")
        let saveCompletion = expectation(description: "save completes")
        let setupCompletion = expectation(description: "setup completes")
        var saveResult: Result<MetaAccountModel, Error>?
        var setupResult: Result<MetaAccountModel?, Error>?

        DispatchQueue.global().async {
            settings.save(value: savedWallet, runningCompletionIn: .main) {
                saveResult = $0
                saveCompletion.fulfill()
            }
            saveInvocationReturned.fulfill()
        }
        wait(for: [savePrepared], timeout: Constants.defaultExpectationDuration)

        DispatchQueue.global().async {
            settings.setup(runningCompletionIn: .main) {
                setupResult = $0
                setupCompletion.fulfill()
            }
            setupInvocationReturned.fulfill()
        }
        wait(for: [setupPrepared], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(controlledService.requestCount, 0)

        releaseSavePreparation.signal()
        wait(
            for: [saveFetch, saveInvocationReturned, setupInvocationReturned],
            timeout: Constants.defaultExpectationDuration
        )

        XCTAssertEqual(controlledService.requestCount, 1)
        XCTAssertEqual(settings.value, savedWallet)

        try controlledService.resolveRequest(
            at: 0,
            using: sourceFacade.databaseService
        )
        wait(for: [savePersist], timeout: Constants.defaultExpectationDuration)
        try controlledService.resolveRequest(
            at: 1,
            using: sourceFacade.databaseService
        )
        wait(
            for: [saveCompletion, setupFetch],
            timeout: Constants.defaultExpectationDuration
        )

        try controlledService.resolveRequest(
            at: 2,
            using: sourceFacade.databaseService
        )
        wait(for: [setupCompletion], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(try XCTUnwrap(saveResult).get(), savedWallet)
        XCTAssertEqual(try XCTUnwrap(setupResult).get(), savedWallet)
        XCTAssertEqual(settings.value, savedWallet)
        XCTAssertEqual(settings.storeState, .ready)
        XCTAssertEqual(controlledService.requestCount, 3)
        XCTAssertEqual(
            try rawWalletSnapshots(in: sourceFacade)
                .filter(\.isSelected)
                .map(\.identifier),
            [savedWallet.identifier]
        )
    }

    func testSetupValueAndStoreStateCommitAtomicallyAgainstSaveRegistration() throws {
        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 8
        let sourceFacade = UserDataStorageTestFacade()
        let savedWallet = copyWallet(
            AccountGenerator.generateMetaAccount(generatingChainAccounts: 1),
            identifier: "saved-wallet"
        )

        try insertTonOnlyWallet(
            identifier: "unsupported-ton-wallet",
            isSelected: true,
            order: 0,
            in: sourceFacade
        )

        let setupFetch = expectation(description: "setup fetch starts")
        let saveFetch = expectation(description: "save fetch waits for setup commit")
        let savePersist = expectation(description: "save persists")
        let setupCommitEntered = expectation(description: "setup begins atomic commit")
        let releaseSetupCommit = DispatchSemaphore(value: 0)
        let savePreparationReached = DispatchSemaphore(value: 0)
        let controlledService = ControllableWalletCoreDataService(
            configuration: sourceFacade.databaseService.configuration,
            requestExpectations: [setupFetch, saveFetch, savePersist]
        )
        let settings = SelectedWalletSettings(
            storageFacade: ControllableWalletStorageFacade(
                databaseService: controlledService
            ),
            operationQueue: operationQueue,
            savePreparationHook: {
                savePreparationReached.signal()
            },
            setupCommitHook: {
                setupCommitEntered.fulfill()
                _ = releaseSetupCommit.wait(
                    timeout: .now() + Constants.defaultExpectationDuration
                )
            }
        )
        let setupCompletion = expectation(description: "setup completes")
        let saveInvocationStarted = expectation(description: "save invocation starts")
        let saveCompletion = expectation(description: "save completes")
        var setupResult: Result<MetaAccountModel?, Error>?
        var saveResult: Result<MetaAccountModel, Error>?

        settings.setup(runningCompletionIn: .main) {
            setupResult = $0
            setupCompletion.fulfill()
        }
        wait(for: [setupFetch], timeout: Constants.defaultExpectationDuration)
        try controlledService.resolveRequest(
            at: 0,
            using: sourceFacade.databaseService
        )
        wait(for: [setupCommitEntered], timeout: Constants.defaultExpectationDuration)

        DispatchQueue.global().async {
            saveInvocationStarted.fulfill()
            settings.save(value: savedWallet, runningCompletionIn: .main) {
                saveResult = $0
                saveCompletion.fulfill()
            }
        }
        wait(for: [saveInvocationStarted], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(
            savePreparationReached.wait(timeout: .now() + 0.2),
            .timedOut
        )
        XCTAssertEqual(controlledService.requestCount, 1)

        releaseSetupCommit.signal()
        wait(
            for: [setupCompletion, saveFetch],
            timeout: Constants.defaultExpectationDuration
        )

        XCTAssertNil(try XCTUnwrap(setupResult).get())
        XCTAssertEqual(settings.storeState, .unsupportedOnly)
        XCTAssertEqual(
            savePreparationReached.wait(
                timeout: .now() + Constants.defaultExpectationDuration
            ),
            .success
        )

        try controlledService.resolveRequest(
            at: 1,
            using: sourceFacade.databaseService
        )
        wait(for: [savePersist], timeout: Constants.defaultExpectationDuration)
        try controlledService.resolveRequest(
            at: 2,
            using: sourceFacade.databaseService
        )
        wait(for: [saveCompletion], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(try XCTUnwrap(saveResult).get(), savedWallet)
        XCTAssertEqual(settings.value, savedWallet)
        XCTAssertEqual(settings.storeState, .ready)
        XCTAssertEqual(controlledService.requestCount, 3)
        XCTAssertEqual(
            try rawWalletSnapshots(in: sourceFacade)
                .filter(\.isSelected)
                .map(\.identifier),
            [savedWallet.identifier]
        )
    }

    func testTolerantFactoriesAndStreamsIgnoreCorruptSelectedSiblingAndKeepObservingValidWallet() throws {
        try assertTolerantObservableReconcilesEveryObserverGap()
        try assertTolerantObservableReconcilesTransientIdentifier()
        try assertTolerantObservableAggregatesSameIdentifierHandoffs()

        let facade = UserDataStorageTestFacade()
        let repositoryQueue = OperationQueue()
        let validWallet = copyWallet(
            AccountGenerator.generateMetaAccount(generatingChainAccounts: 1),
            identifier: "provider-valid-wallet",
            name: "Provider Valid Wallet"
        )
        let transitionWallet = copyWallet(
            validWallet,
            identifier: "provider-valid-to-corrupt-wallet",
            name: "Provider Transition Wallet"
        )
        let corruptIdentifier = "provider-corrupt-wallet"
        let corruptIdentifiers = Set([corruptIdentifier])

        try seed(
            [
                ManagedMetaAccountModel(info: validWallet, isSelected: true),
                ManagedMetaAccountModel(info: transitionWallet, isSelected: true)
            ],
            in: facade,
            using: repositoryQueue
        )

        try performCoreData(in: facade) { context in
            let corruptWallet = self.copyWallet(
                validWallet,
                identifier: corruptIdentifier,
                name: "Provider Corrupt Wallet"
            )
            let entity = CDMetaAccount(context: context)
            try MetaAccountMapper().populate(
                entity: entity,
                from: corruptWallet,
                using: context
            )
            entity.isSelected = true
            entity.order = 900
            entity.name = ""
            let child = try XCTUnwrap(
                entity.chainAccounts?.allObjects.first as? CDChainAccount
            )
            // The account-ID provider must match this corrupt row through its child
            // relationship, not merely through the primary account columns.
            child.accountId = validWallet.substrateAccountId.toHex()

            // A structurally corrupt sibling with the same persistent identifier must
            // not make the healthy row disappear from tolerant reads.
            let duplicateWallet = self.copyWallet(
                validWallet,
                identifier: validWallet.identifier,
                name: "Provider Duplicate Corrupt Wallet"
            )
            let duplicateEntity = CDMetaAccount(context: context)
            try MetaAccountMapper().populate(
                entity: duplicateEntity,
                from: duplicateWallet,
                using: context
            )
            duplicateEntity.isSelected = true
            duplicateEntity.order = 899
            duplicateEntity.name = ""
            let duplicateChild = try XCTUnwrap(
                duplicateEntity.chainAccounts?.allObjects.first as? CDChainAccount
            )
            duplicateChild.accountId = validWallet.substrateAccountId.toHex()
            try context.save()
        }

        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: facade)
        let metaRepository = accountRepositoryFactory.createMetaAccountRepository(
            for: nil,
            sortDescriptors: []
        )
        let managedRepository = accountRepositoryFactory.createManagedMetaAccountRepository(
            for: NSPredicate.selectedMetaAccount(),
            sortDescriptors: []
        )

        XCTAssertEqual(
            Set(try execute(
                metaRepository.fetchAllOperation(
                    with: RepositoryFetchOptions(
                        includesProperties: true,
                        includesSubentities: true
                    )
                ),
                using: repositoryQueue
            ).map(\.identifier)),
            Set([validWallet.identifier, transitionWallet.identifier])
        )
        XCTAssertEqual(
            Set(try execute(
                managedRepository.fetchAllOperation(
                    with: RepositoryFetchOptions(
                        includesProperties: true,
                        includesSubentities: true
                    )
                ),
                using: repositoryQueue
            ).map(\.identifier)),
            Set([validWallet.identifier, transitionWallet.identifier])
        )

        let operationManager = OperationManager()
        let providerFactory = AccountProviderFactory(
            storageFacade: facade,
            operationManager: operationManager
        )
        let accountProvider = providerFactory.createStreambleProvider(
            for: validWallet.substrateAccountId
        )
        let managedProvider = providerFactory.createManagedMetaAccountProvider(
            for: NSPredicate.selectedMetaAccount(),
            sortDescriptors: []
        )
        let accountObserver = NSObject()
        let managedObserver = NSObject()
        let accountInitial = expectation(description: "account stream returns healthy initial wallet")
        let managedInitial = expectation(description: "managed stream returns healthy initial wallet")
        let accountUpdate = expectation(description: "account stream observes healthy update")
        let managedUpdate = expectation(description: "managed stream observes healthy update")
        let accountTransitionDelete = expectation(
            description: "account stream removes a wallet that becomes corrupt"
        )
        let managedTransitionDelete = expectation(
            description: "managed stream removes a wallet that becomes corrupt"
        )
        let accountTransitionRestore = expectation(
            description: "account stream reinserts a repaired wallet"
        )
        let managedTransitionRestore = expectation(
            description: "managed stream reinserts a repaired wallet"
        )
        let updatedName = "Provider Valid Wallet Updated"
        let restoredName = "Provider Transition Wallet Restored"
        var accountInitialDelivered = false
        var managedInitialDelivered = false

        accountProvider.addObserver(
            accountObserver,
            deliverOn: .main,
            executing: { changes in
                let wallets = changes.compactMap { change -> MetaAccountModel? in
                    switch change {
                    case let .insert(newItem), let .update(newItem):
                        return newItem
                    case let .delete(deletedIdentifier):
                        if deletedIdentifier == transitionWallet.identifier {
                            accountTransitionDelete.fulfill()
                        }
                        if deletedIdentifier == validWallet.identifier {
                            XCTFail("A corrupt duplicate deleted the healthy account stream item")
                        }
                        return nil
                    }
                }

                XCTAssertTrue(
                    wallets.allSatisfy {
                        !corruptIdentifiers.contains($0.identifier)
                    }
                )
                if wallets.contains(where: { $0.name == updatedName }) {
                    accountUpdate.fulfill()
                } else if wallets.contains(where: { $0.name == restoredName }) {
                    accountTransitionRestore.fulfill()
                } else if !accountInitialDelivered {
                    accountInitialDelivered = true
                    XCTAssertEqual(
                        Set(wallets.map(\.identifier)),
                        Set([validWallet.identifier, transitionWallet.identifier])
                    )
                    accountInitial.fulfill()
                }
            },
            failing: { error in
                XCTFail("Account stream failed beside a corrupt sibling: \(error)")
            },
            options: StreamableProviderObserverOptions(refreshWhenEmpty: false)
        )
        managedProvider.addObserver(
            managedObserver,
            deliverOn: .main,
            executing: { changes in
                let wallets = changes.compactMap { change -> ManagedMetaAccountModel? in
                    switch change {
                    case let .insert(newItem), let .update(newItem):
                        return newItem
                    case let .delete(deletedIdentifier):
                        if deletedIdentifier == transitionWallet.identifier {
                            managedTransitionDelete.fulfill()
                        }
                        if deletedIdentifier == validWallet.identifier {
                            XCTFail("A corrupt duplicate deleted the healthy managed stream item")
                        }
                        return nil
                    }
                }

                XCTAssertTrue(
                    wallets.allSatisfy {
                        !corruptIdentifiers.contains($0.identifier)
                    }
                )
                if wallets.contains(where: { $0.info.name == updatedName }) {
                    managedUpdate.fulfill()
                } else if wallets.contains(where: { $0.info.name == restoredName }) {
                    managedTransitionRestore.fulfill()
                } else if !managedInitialDelivered {
                    managedInitialDelivered = true
                    XCTAssertEqual(
                        Set(wallets.map(\.identifier)),
                        Set([validWallet.identifier, transitionWallet.identifier])
                    )
                    XCTAssertTrue(wallets.allSatisfy(\.isSelected))
                    managedInitial.fulfill()
                }
            },
            failing: { error in
                XCTFail("Managed wallet stream failed beside a corrupt sibling: \(error)")
            },
            options: StreamableProviderObserverOptions(refreshWhenEmpty: false)
        )

        wait(
            for: [accountInitial, managedInitial],
            timeout: Constants.defaultExpectationDuration
        )

        // The observable tracks validity per Core Data object, so invalidating one
        // previously valid wallet emits a delete and repairing it emits an insert.
        try performCoreData(in: facade) { context in
            let request = NSFetchRequest<CDMetaAccount>(entityName: "CDMetaAccount")
            request.predicate = NSPredicate(
                format: "%K == %@",
                #keyPath(CDMetaAccount.metaId),
                transitionWallet.identifier
            )
            let entity = try XCTUnwrap(context.fetch(request).first)
            entity.name = " \n\t "
            try context.save()
        }
        wait(
            for: [accountTransitionDelete, managedTransitionDelete],
            timeout: Constants.defaultExpectationDuration
        )
        try performCoreData(in: facade) { context in
            let request = NSFetchRequest<CDMetaAccount>(entityName: "CDMetaAccount")
            request.predicate = NSPredicate(
                format: "%K == %@",
                #keyPath(CDMetaAccount.metaId),
                transitionWallet.identifier
            )
            let entity = try XCTUnwrap(context.fetch(request).first)
            entity.name = restoredName
            try context.save()
        }
        wait(
            for: [accountTransitionRestore, managedTransitionRestore],
            timeout: Constants.defaultExpectationDuration
        )

        // Exercise update and delete notifications for a pre-existing corrupt duplicate.
        try performCoreData(in: facade) { context in
            let request = NSFetchRequest<CDMetaAccount>(entityName: "CDMetaAccount")
            request.predicate = NSPredicate(
                format: "%K == %@",
                #keyPath(CDMetaAccount.metaId),
                validWallet.identifier
            )
            let entity = try XCTUnwrap(
                context.fetch(request).first {
                    ($0.name ?? "").trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty
                }
            )
            entity.name = " \n\t "
            try context.save()
            context.delete(entity)
            try context.save()
        }

        try performCoreData(in: facade) { context in
            let insertedCorruptWallet = self.copyWallet(
                AccountGenerator.generateMetaAccount(generatingChainAccounts: 1),
                identifier: validWallet.identifier,
                name: "Inserted Corrupt Wallet"
            )
            let entity = CDMetaAccount(context: context)
            try MetaAccountMapper().populate(
                entity: entity,
                from: insertedCorruptWallet,
                using: context
            )
            entity.isSelected = true
            entity.order = 901
            entity.name = ""
            let child = try XCTUnwrap(
                entity.chainAccounts?.allObjects.first as? CDChainAccount
            )
            child.accountId = validWallet.substrateAccountId.toHex()
            try context.save()

            // Exercise an update notification for the same still-corrupt matching row.
            entity.name = " \n\t "
            try context.save()

            // A corrupt duplicate was never tracked as valid, so its raw identifier
            // must not be emitted as a delete for the healthy sibling.
            context.delete(entity)
            try context.save()
        }

        try performCoreData(in: facade) { context in
            let request = NSFetchRequest<CDMetaAccount>(entityName: "CDMetaAccount")
            request.predicate = NSPredicate(
                format: "%K == %@",
                #keyPath(CDMetaAccount.metaId),
                validWallet.identifier
            )
            let entity = try XCTUnwrap(
                context.fetch(request).first {
                    $0.name == validWallet.name
                }
            )
            entity.name = updatedName
            try context.save()
        }

        wait(
            for: [accountUpdate, managedUpdate],
            timeout: Constants.defaultExpectationDuration
        )
        accountProvider.removeObserver(accountObserver)
        managedProvider.removeObserver(managedObserver)

        let corruptProjections = try performCoreData(in: facade) { context in
            let request = NSFetchRequest<CDMetaAccount>(entityName: "CDMetaAccount")
            request.predicate = NSPredicate(
                format: "%K IN %@",
                #keyPath(CDMetaAccount.metaId),
                Array(corruptIdentifiers)
            )
            return try context.fetch(request).map {
                try MetaAccountSelectionMapper().transform(entity: $0)
            }
        }
        XCTAssertEqual(corruptProjections.count, corruptIdentifiers.count)
        XCTAssertTrue(corruptProjections.allSatisfy { $0.recordState == .corrupt })
        XCTAssertTrue(corruptProjections.allSatisfy { $0.wallet == nil })
    }

    private func assertTolerantObservableReconcilesEveryObserverGap() throws {
        let facade = UserDataStorageTestFacade()
        let repositoryQueue = OperationQueue()
        let processingQueue = DispatchQueue(
            label: "jp.co.fearless.wallet-observable.observer-gap-test"
        )
        let wallet = copyWallet(
            AccountGenerator.generateMetaAccount(generatingChainAccounts: 1),
            identifier: "observer-gap-wallet",
            name: "Observer Gap Wallet"
        )
        try seed(
            [ManagedMetaAccountModel(info: wallet, isSelected: true)],
            in: facade,
            using: repositoryQueue
        )

        let observable = TolerantMetaAccountContextObservable(
            service: facade.databaseService,
            mapper: AnyCoreDataMapper(ManagedMetaAccountMapper()),
            predicate: { _ in true },
            processingQueue: processingQueue
        )
        let startExpectation = expectation(description: "gap observable starts")
        observable.start { error in
            XCTAssertNil(error)
            startExpectation.fulfill()
        }
        wait(for: [startExpectation], timeout: Constants.defaultExpectationDuration)

        func updateWalletName(_ name: String) throws {
            try performCoreData(in: facade) { context in
                let request = NSFetchRequest<CDMetaAccount>(entityName: "CDMetaAccount")
                request.predicate = NSPredicate(
                    format: "%K == %@",
                    #keyPath(CDMetaAccount.metaId),
                    wallet.identifier
                )
                let entity = try XCTUnwrap(context.fetch(request).first)
                entity.name = name
                try context.save()
            }
            processingQueue.sync {}
        }

        // Reconcile the exact activation race: valid -> corrupt -> valid completes
        // after start but before RobinHood asynchronously registers its observer.
        try updateWalletName(" \n\t ")
        let restoredName = "Observer Gap Wallet Restored"
        try updateWalletName(restoredName)

        let firstObserver = NSObject()
        let firstReconciliationExpectation = expectation(
            description: "pre-registration final state is reconciled"
        )
        var firstBatch: [DataProviderChange<ManagedMetaAccountModel>] = []
        observable.addObserver(
            firstObserver,
            deliverOn: .main,
            executing: { changes in
                firstBatch = changes
                firstReconciliationExpectation.fulfill()
            }
        )
        wait(
            for: [firstReconciliationExpectation],
            timeout: Constants.defaultExpectationDuration
        )
        XCTAssertEqual(firstBatch.count, 2)
        if case let .delete(identifier)? = firstBatch.first {
            XCTAssertEqual(identifier, wallet.identifier)
        } else {
            XCTFail("Reconciliation must invalidate the provider's stale snapshot")
        }
        if case let .insert(model)? = firstBatch.last {
            XCTAssertEqual(model.identifier, wallet.identifier)
            XCTAssertEqual(model.info.name, restoredName)
        } else {
            XCTFail("Reconciliation must finish with the current healthy wallet")
        }

        observable.removeObserver(firstObserver)
        processingQueue.sync {}

        let oldDeliveryQueue = DispatchQueue(
            label: "jp.co.fearless.wallet-observable.old-delivery-test"
        )
        let newDeliveryQueue = DispatchQueue(
            label: "jp.co.fearless.wallet-observable.new-delivery-test"
        )
        let oldDeliveryBlockStarted = DispatchSemaphore(value: 0)
        let newDeliveryBlockStarted = DispatchSemaphore(value: 0)
        let releaseOldDelivery = DispatchSemaphore(value: 0)
        let releaseNewDelivery = DispatchSemaphore(value: 0)
        defer {
            releaseOldDelivery.signal()
            releaseNewDelivery.signal()
        }
        oldDeliveryQueue.async {
            oldDeliveryBlockStarted.signal()
            releaseOldDelivery.wait()
        }
        newDeliveryQueue.async {
            newDeliveryBlockStarted.signal()
            releaseNewDelivery.wait()
        }
        XCTAssertEqual(
            oldDeliveryBlockStarted.wait(
                timeout: .now() + Constants.defaultExpectationDuration
            ),
            .success
        )
        XCTAssertEqual(
            newDeliveryBlockStarted.wait(
                timeout: .now() + Constants.defaultExpectationDuration
            ),
            .success
        )

        let teardownObserver = NSObject()
        observable.addObserver(
            teardownObserver,
            deliverOn: oldDeliveryQueue,
            executing: { _ in }
        )
        processingQueue.sync {}

        // Model StreamableProvider's teardown race deterministically. The source
        // callback is already in flight when the provider loses its last user.
        // Removal remains asynchronous, and the repair mutation happens without
        // draining that removal first.
        try updateWalletName("")
        observable.removeObserver(teardownObserver)
        let resubscribedName = "Observer Gap Wallet Resubscribed"
        try updateWalletName(resubscribedName)

        // Re-add the identical observer while its old-generation callback is
        // blocked, then independently block the new-generation reconciliation.
        // Finishing the old callback must only acknowledge its unique delivery.
        var blockedNewGenerationBatch: [
            DataProviderChange<ManagedMetaAccountModel>
        ] = []
        observable.addObserver(
            teardownObserver,
            deliverOn: newDeliveryQueue,
            executing: { changes in
                blockedNewGenerationBatch = changes
            }
        )
        processingQueue.sync {}
        releaseOldDelivery.signal()
        oldDeliveryQueue.sync {}
        processingQueue.sync {}

        // A second removal must still repend the independently in-flight new
        // generation, proving an old completion cannot ABA-clear its state.
        observable.removeObserver(teardownObserver)
        processingQueue.sync {}

        let abaReconciliationExpectation = expectation(
            description: "same observer generation is reconciled independently"
        )
        var abaBatch: [DataProviderChange<ManagedMetaAccountModel>] = []
        observable.addObserver(
            teardownObserver,
            deliverOn: .main,
            executing: { changes in
                abaBatch = changes
                abaReconciliationExpectation.fulfill()
            }
        )
        wait(
            for: [abaReconciliationExpectation],
            timeout: Constants.defaultExpectationDuration
        )
        XCTAssertEqual(abaBatch.count, 2)
        if case let .delete(identifier)? = abaBatch.first {
            XCTAssertEqual(identifier, wallet.identifier)
        } else {
            XCTFail("Resubscription reconciliation must begin with a delete")
        }
        if case let .insert(model)? = abaBatch.last {
            XCTAssertEqual(model.identifier, wallet.identifier)
            XCTAssertEqual(model.info.name, resubscribedName)
        } else {
            XCTFail("Resubscription must finish with the current healthy wallet")
        }

        releaseNewDelivery.signal()
        newDeliveryQueue.sync {}
        processingQueue.sync {}
        XCTAssertEqual(blockedNewGenerationBatch.count, 2)
        observable.removeObserver(teardownObserver)
        processingQueue.sync {}
        let stopExpectation = expectation(description: "gap observable stops")
        observable.stop { error in
            XCTAssertNil(error)
            stopExpectation.fulfill()
        }
        wait(for: [stopExpectation], timeout: Constants.defaultExpectationDuration)
    }

    private func assertTolerantObservableReconcilesTransientIdentifier() throws {
        let facade = UserDataStorageTestFacade()
        let processingQueue = DispatchQueue(
            label: "jp.co.fearless.wallet-observable.transient-test"
        )
        let wallet = copyWallet(
            AccountGenerator.generateMetaAccount(generatingChainAccounts: 1),
            identifier: "transient-observer-gap-wallet",
            name: "Transient Observer Gap Wallet"
        )
        let observable = TolerantMetaAccountContextObservable(
            service: facade.databaseService,
            mapper: AnyCoreDataMapper(ManagedMetaAccountMapper()),
            predicate: { _ in true },
            processingQueue: processingQueue
        )
        let startExpectation = expectation(description: "transient observable starts")
        observable.start { error in
            XCTAssertNil(error)
            startExpectation.fulfill()
        }
        wait(for: [startExpectation], timeout: Constants.defaultExpectationDuration)

        // Coalescing is identifier based, so a row created and removed entirely
        // within the gap must reconcile as a delete-only terminal state.
        try performCoreData(in: facade) { context in
            let entity = CDMetaAccount(context: context)
            try MetaAccountMapper().populate(
                entity: entity,
                from: wallet,
                using: context
            )
            entity.isSelected = true
            try context.save()
            context.delete(entity)
            try context.save()
        }
        processingQueue.sync {}

        let observer = NSObject()
        let reconciliationExpectation = expectation(
            description: "transient identifier is reconciled"
        )
        var batch: [DataProviderChange<ManagedMetaAccountModel>] = []
        observable.addObserver(
            observer,
            deliverOn: .main,
            executing: { changes in
                batch = changes
                reconciliationExpectation.fulfill()
            }
        )
        wait(
            for: [reconciliationExpectation],
            timeout: Constants.defaultExpectationDuration
        )
        XCTAssertEqual(batch.count, 1)
        if case let .delete(identifier)? = batch.first {
            XCTAssertEqual(identifier, wallet.identifier)
        } else {
            XCTFail("A transient identifier must reconcile as delete-only")
        }

        observable.removeObserver(observer)
        processingQueue.sync {}
        let stopExpectation = expectation(description: "transient observable stops")
        observable.stop { error in
            XCTAssertNil(error)
            stopExpectation.fulfill()
        }
        wait(
            for: [stopExpectation],
            timeout: Constants.defaultExpectationDuration
        )
    }

    private func assertTolerantObservableAggregatesSameIdentifierHandoffs() throws {
        let facade = UserDataStorageTestFacade()
        let repositoryQueue = OperationQueue()
        let processingQueue = DispatchQueue(
            label: "jp.co.fearless.wallet-observable.identifier-handoff-test"
        )
        let identifier = "same-identifier-handoff-wallet"
        let firstWallet = copyWallet(
            AccountGenerator.generateMetaAccount(generatingChainAccounts: 1),
            identifier: identifier,
            name: "Handoff Wallet A"
        )
        let secondWallet = copyWallet(
            AccountGenerator.generateMetaAccount(generatingChainAccounts: 1),
            identifier: identifier,
            name: "Handoff Wallet B"
        )
        try seed(
            [ManagedMetaAccountModel(info: firstWallet, isSelected: true)],
            in: facade,
            using: repositoryQueue
        )
        try performCoreData(in: facade) { context in
            let entity = CDMetaAccount(context: context)
            try MetaAccountMapper().populate(
                entity: entity,
                from: secondWallet,
                using: context
            )
            entity.isSelected = true
            entity.order = 900
            entity.name = ""
            try context.save()
        }

        let observable = TolerantMetaAccountContextObservable(
            service: facade.databaseService,
            mapper: AnyCoreDataMapper(ManagedMetaAccountMapper()),
            predicate: { _ in true },
            processingQueue: processingQueue
        )
        let startExpectation = expectation(description: "handoff observable starts")
        observable.start { error in
            XCTAssertNil(error)
            startExpectation.fulfill()
        }
        wait(for: [startExpectation], timeout: Constants.defaultExpectationDuration)

        let observer = NSObject()
        let firstHandoffExpectation = expectation(
            description: "healthy role moves from A to B"
        )
        let secondHandoffExpectation = expectation(
            description: "healthy role moves from B to A"
        )
        var receivedBatches: [[DataProviderChange<ManagedMetaAccountModel>]] = []
        observable.addObserver(
            observer,
            deliverOn: .main,
            executing: { changes in
                receivedBatches.append(changes)
                if receivedBatches.count == 1 {
                    firstHandoffExpectation.fulfill()
                } else if receivedBatches.count == 2 {
                    secondHandoffExpectation.fulfill()
                } else {
                    XCTFail("Each same-identifier handoff must emit one terminal batch")
                }
            }
        )
        processingQueue.sync {}

        func moveHealthyRole(from oldName: String, to newName: String) throws {
            try performCoreData(in: facade) { context in
                let request = NSFetchRequest<CDMetaAccount>(
                    entityName: "CDMetaAccount"
                )
                request.predicate = NSPredicate(
                    format: "%K == %@",
                    #keyPath(CDMetaAccount.metaId),
                    identifier
                )
                let entities = try context.fetch(request)
                XCTAssertEqual(entities.count, 2)
                let healthyEntity = try XCTUnwrap(
                    entities.first { $0.name == oldName }
                )
                let corruptEntity = try XCTUnwrap(
                    entities.first {
                        ($0.name ?? "").trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty
                    }
                )
                healthyEntity.name = ""
                corruptEntity.name = newName
                try context.save()
            }
        }

        // Both objects are updated in one save. Core Data exposes notification
        // objects as an unordered set, so processing them one-by-one could emit a
        // terminal delete even though the identifier remains healthy.
        try moveHealthyRole(
            from: firstWallet.name,
            to: secondWallet.name
        )
        wait(
            for: [firstHandoffExpectation],
            timeout: Constants.defaultExpectationDuration
        )
        XCTAssertEqual(receivedBatches.count, 1)
        XCTAssertEqual(receivedBatches[0].count, 1)
        if case let .update(model)? = receivedBatches[0].first {
            XCTAssertEqual(model.identifier, identifier)
            XCTAssertEqual(model.info.name, secondWallet.name)
        } else {
            XCTFail("A-to-B handoff must emit one terminal update, never a delete")
        }

        try moveHealthyRole(
            from: secondWallet.name,
            to: firstWallet.name
        )
        wait(
            for: [secondHandoffExpectation],
            timeout: Constants.defaultExpectationDuration
        )
        XCTAssertEqual(receivedBatches.count, 2)
        XCTAssertEqual(receivedBatches[1].count, 1)
        if case let .update(model)? = receivedBatches[1].first {
            XCTAssertEqual(model.identifier, identifier)
            XCTAssertEqual(model.info.name, firstWallet.name)
        } else {
            XCTFail("B-to-A handoff must emit one terminal update, never a delete")
        }

        observable.removeObserver(observer)
        processingQueue.sync {}
        let stopExpectation = expectation(description: "handoff observable stops")
        observable.stop { error in
            XCTAssertNil(error)
            stopExpectation.fulfill()
        }
        wait(for: [stopExpectation], timeout: Constants.defaultExpectationDuration)
    }

    func testRepositorySaveRejectsEquivalentChainAccountAliasesBeforeMutatingStoredWallet() throws {
        let facade = UserDataStorageTestFacade()
        let operationQueue = OperationQueue()
        let identifier = "duplicate-alias-save-wallet"
        let generatedWallet = copyWallet(
            AccountGenerator.generateMetaAccount(generatingChainAccounts: 0),
            identifier: identifier
        )
        let storedWallet = replacingChainAccounts(
            in: generatedWallet,
            with: [
                ChainAccountModel(
                    chainId: UniversalWalletRegistry.bitcoinMainnet.chainId,
                    accountId: Data(repeating: 0x10, count: 32),
                    publicKey: Data(repeating: 0x20, count: 32),
                    cryptoType: CryptoType.sr25519.rawValue,
                    ethereumBased: false
                )
            ]
        )
        try seed(
            [ManagedMetaAccountModel(info: storedWallet, isSelected: true)],
            in: facade,
            using: operationQueue
        )
        try setRawWalletOrder(identifier: identifier, order: 1_100, in: facade)
        let before = try rawStoredWalletSnapshots(
            orders: [1_100],
            in: facade
        )

        let duplicateModels = [
            replacingChainAccounts(
                in: storedWallet,
                with: [
                    ChainAccountModel(
                        chainId: "duplicate-remote-chain",
                        accountId: Data(repeating: 0x11, count: 32),
                        publicKey: Data(repeating: 0x21, count: 32),
                        cryptoType: CryptoType.sr25519.rawValue,
                        ethereumBased: false
                    ),
                    ChainAccountModel(
                        chainId: "duplicate-remote-chain",
                        accountId: Data(repeating: 0x12, count: 32),
                        publicKey: Data(repeating: 0x22, count: 32),
                        cryptoType: CryptoType.sr25519.rawValue,
                        ethereumBased: false
                    )
                ]
            ),
            replacingChainAccounts(
                in: storedWallet,
                with: [
                    ChainAccountModel(
                        chainId: UniversalWalletRegistry.bitcoinMainnet.chainId,
                        accountId: Data(repeating: 0x13, count: 32),
                        publicKey: Data(repeating: 0x23, count: 32),
                        cryptoType: CryptoType.sr25519.rawValue,
                        ethereumBased: false
                    ),
                    ChainAccountModel(
                        chainId: UniversalWalletRegistry.bitcoinMainnet.id,
                        accountId: Data(repeating: 0x14, count: 32),
                        publicKey: Data(repeating: 0x24, count: 32),
                        cryptoType: CryptoType.sr25519.rawValue,
                        ethereumBased: false
                    )
                ]
            )
        ]
        let malformedModels = [
            ChainAccountModel(
                chainId: "",
                accountId: Data(repeating: 0x31, count: 32),
                publicKey: Data(repeating: 0x41, count: 32),
                cryptoType: CryptoType.sr25519.rawValue,
                ethereumBased: false
            ),
            ChainAccountModel(
                chainId: " padded-chain-id ",
                accountId: Data(repeating: 0x32, count: 32),
                publicKey: Data(repeating: 0x42, count: 32),
                cryptoType: CryptoType.sr25519.rawValue,
                ethereumBased: false
            ),
            ChainAccountModel(
                chainId: "empty-account-id",
                accountId: Data(),
                publicKey: Data(repeating: 0x43, count: 32),
                cryptoType: CryptoType.sr25519.rawValue,
                ethereumBased: false
            ),
            ChainAccountModel(
                chainId: "short-public-key",
                accountId: Data(repeating: 0x34, count: 32),
                publicKey: Data(repeating: 0x44, count: 31),
                cryptoType: CryptoType.sr25519.rawValue,
                ethereumBased: false
            ),
            ChainAccountModel(
                chainId: "ecdsa-wrong-public-key-width",
                accountId: Data(repeating: 0x35, count: 32),
                publicKey: Data(repeating: 0x45, count: 32),
                cryptoType: CryptoType.ecdsa.rawValue,
                ethereumBased: false
            ),
            ChainAccountModel(
                chainId: "invalid-crypto-type",
                accountId: Data(repeating: 0x36, count: 32),
                publicKey: Data(repeating: 0x46, count: 32),
                cryptoType: UInt8.max,
                ethereumBased: false
            )
        ].map {
            replacingChainAccounts(in: storedWallet, with: [$0])
        }
        let repository = AccountRepositoryFactory(storageFacade: facade)
            .createMetaAccountRepository(for: nil, sortDescriptors: [])

        for invalidModel in duplicateModels + malformedModels {
            let saveOperation = repository.saveOperation(
                { [invalidModel] },
                { [] }
            )
            XCTAssertThrowsError(
                try execute(saveOperation, using: operationQueue)
            ) { error in
                guard case MetaAccountMapperError.invalidWalletRecord = error else {
                    return XCTFail(
                        "Expected duplicate child validation error, got \(error)"
                    )
                }
            }
            XCTAssertEqual(
                try rawStoredWalletSnapshots(orders: [1_100], in: facade),
                before
            )
        }

        // Replacing one persisted alias with its canonical equivalent must update
        // the existing child rather than append a second equivalent child.
        let aliasReplacement = replacingChainAccounts(
            in: storedWallet,
            with: [
                ChainAccountModel(
                    chainId: UniversalWalletRegistry.bitcoinMainnet.id,
                    accountId: Data(repeating: 0x15, count: 32),
                    publicKey: Data(repeating: 0x25, count: 32),
                    cryptoType: CryptoType.sr25519.rawValue,
                    ethereumBased: false
                )
            ]
        )
        _ = try execute(
            repository.saveOperation(
                { [aliasReplacement] },
                { [] }
            ),
            using: operationQueue
        )

        let afterAliasReplacement = try rawStoredWalletSnapshots(
            orders: [1_100],
            in: facade
        )
        XCTAssertEqual(afterAliasReplacement.count, 1)
        XCTAssertEqual(afterAliasReplacement[0].chainAccounts.count, 1)
        XCTAssertEqual(
            afterAliasReplacement[0].chainAccounts[0].chainId,
            UniversalWalletRegistry.bitcoinMainnet.id
        )
    }

    func testDeleteAndReplaceRejectDuplicateStoredIdentifiersInBothInsertionOrdersWithoutMutation() throws {
        for supportedFirst in [true, false] {
            let facade = UserDataStorageTestFacade()
            let operationQueue = OperationQueue()
            let identifier = supportedFirst
                ? "collision-supported-first"
                : "collision-unsupported-first"
            let supportedOrder: Int32 = 1_150
            let unsupportedOrder: Int32 = 1_151

            let insertSupported = {
                try self.insertWallet(
                    identifier: identifier,
                    isSelected: true,
                    order: supportedOrder,
                    childSpecs: [],
                    in: facade
                )
            }
            let insertUnsupported = {
                try self.insertTonOnlyWallet(
                    identifier: identifier,
                    isSelected: false,
                    order: unsupportedOrder,
                    in: facade
                )
            }
            if supportedFirst {
                try insertSupported()
                try insertUnsupported()
            } else {
                try insertUnsupported()
                try insertSupported()
            }

            let orders = Set([supportedOrder, unsupportedOrder])
            let before = try rawStoredWalletSnapshots(
                orders: orders,
                in: facade
            )
            XCTAssertEqual(before.count, 2)

            let repository = AccountRepositoryFactory(storageFacade: facade)
                .createMetaAccountRepository(for: nil, sortDescriptors: [])
            let deleteOperation = repository.saveOperation(
                { [] },
                { [identifier] }
            )
            XCTAssertThrowsError(
                try execute(deleteOperation, using: operationQueue)
            ) { error in
                guard
                    let settingsError = error as? SelectedWalletSettingsError,
                    case .duplicateWalletIdentifier = settingsError
                else {
                    return XCTFail(
                        "Expected duplicate delete collision, got \(error)"
                    )
                }
            }
            XCTAssertEqual(
                try rawStoredWalletSnapshots(orders: orders, in: facade),
                before
            )

            let replaceOperation = repository.replaceOperation { [] }
            XCTAssertThrowsError(
                try execute(replaceOperation, using: operationQueue)
            ) { error in
                guard
                    let settingsError = error as? SelectedWalletSettingsError,
                    case .duplicateWalletIdentifier = settingsError
                else {
                    return XCTFail(
                        "Expected duplicate replace collision, got \(error)"
                    )
                }
            }
            XCTAssertEqual(
                try rawStoredWalletSnapshots(orders: orders, in: facade),
                before
            )
        }
    }

    func testPersistedDuplicateAndUniversalAliasChainAccountsAreAlwaysQuarantinedWithoutMutation() throws {
        typealias ChildSpec = (chainId: String, marker: UInt8)
        typealias Fixture = (identifier: String, children: [ChildSpec])

        let exactForward: [ChildSpec] = [
            ("remote-chain-id", 0x01),
            ("remote-chain-id", 0x02)
        ]
        let exactReverse = Array(exactForward.reversed())
        let aliasPairs: [(String, String)] = [
            (
                UniversalWalletRegistry.bitcoinMainnet.chainId,
                UniversalWalletRegistry.bitcoinMainnet.id
            ),
            (
                UniversalWalletRegistry.bitcoinTestnet.chainId,
                UniversalWalletRegistry.bitcoinTestnet.id
            ),
            (
                UniversalWalletRegistry.solanaMainnet.chainId,
                UniversalWalletRegistry.solanaMainnet.id.uppercased()
            ),
            (
                UniversalWalletRegistry.solanaDevnet.chainId,
                UniversalWalletRegistry.solanaDevnet.id
            ),
            (
                UniversalWalletRegistry.tonMainnetRegistryEntry.chainId,
                UniversalWalletRegistry.tonMainnetRegistryEntry.id
            ),
            (
                TonChainSelection.mainnetChainId,
                UniversalWalletRegistry.tonMainnetRegistryEntry.id
            ),
            (
                UniversalWalletRegistry.taira.chainId,
                UniversalWalletRegistry.taira.id
            ),
            (
                UniversalWalletRegistry.nexus.chainId,
                UniversalWalletRegistry.nexus.id
            )
        ]
        var fixtures: [Fixture] = [
            ("duplicate-exact-forward", exactForward),
            ("duplicate-exact-reverse", exactReverse)
        ]

        for (index, pair) in aliasPairs.enumerated() {
            let forward: [ChildSpec] = [
                (pair.0, UInt8(index * 2 + 10)),
                (pair.1, UInt8(index * 2 + 11))
            ]
            fixtures.append(("duplicate-alias-\(index)-forward", forward))
            fixtures.append(("duplicate-alias-\(index)-reverse", Array(forward.reversed())))
        }

        let facade = UserDataStorageTestFacade()
        let operationQueue = OperationQueue()
        let healthyWallet = copyWallet(
            AccountGenerator.generateMetaAccount(generatingChainAccounts: 1),
            identifier: "duplicate-control-healthy"
        )
        try seed(
            [ManagedMetaAccountModel(info: healthyWallet, isSelected: true)],
            in: facade,
            using: operationQueue
        )

        let fixtureOrders = Set(
            fixtures.indices.map { Int32(1_200 + $0) }
        )
        for (index, fixture) in fixtures.enumerated() {
            try insertWallet(
                identifier: fixture.identifier,
                isSelected: true,
                order: Int32(1_200 + index),
                childSpecs: fixture.children,
                in: facade
            )
        }

        let before = try rawStoredWalletSnapshots(
            orders: fixtureOrders,
            in: facade
        )
        let fixtureIdentifiers = Set(fixtures.map(\.identifier))
        let mappingStates = try performCoreData(in: facade) { context in
            let request = NSFetchRequest<CDMetaAccount>(entityName: "CDMetaAccount")
            request.predicate = NSPredicate(
                format: "%K IN %@",
                #keyPath(CDMetaAccount.metaId),
                Array(fixtureIdentifiers)
            )
            return try context.fetch(request).reduce(into: [String: Bool]()) {
                result,
                entity in
                let identifier = try XCTUnwrap(entity.metaId)
                do {
                    _ = try MetaAccountMapper().transform(entity: entity)
                    result[identifier] = false
                } catch MetaAccountMapperError.invalidWalletRecord {
                    result[identifier] = true
                }
            }
        }
        XCTAssertEqual(Set(mappingStates.keys), fixtureIdentifiers)
        XCTAssertTrue(mappingStates.values.allSatisfy { $0 })

        let projectionRepository = facade.createRepository(
            mapper: AnyCoreDataMapper(MetaAccountSelectionMapper())
        )
        let projections = try execute(
            projectionRepository.fetchAllOperation(
                with: RepositoryFetchOptions(
                    includesProperties: true,
                    includesSubentities: true
                )
            ),
            using: operationQueue
        )
        let duplicateProjections = projections.filter {
            fixtureIdentifiers.contains($0.identifier)
        }
        XCTAssertEqual(duplicateProjections.count, fixtures.count)
        XCTAssertTrue(duplicateProjections.allSatisfy { $0.recordState == .corrupt })
        XCTAssertTrue(duplicateProjections.allSatisfy { $0.wallet == nil })

        let tolerantRepository = AccountRepositoryFactory(storageFacade: facade)
            .createMetaAccountRepository(for: nil, sortDescriptors: [])
        XCTAssertEqual(
            try execute(
                tolerantRepository.fetchAllOperation(
                    with: RepositoryFetchOptions(
                        includesProperties: true,
                        includesSubentities: true
                    )
                ),
                using: operationQueue
            ).map(\.identifier),
            [healthyWallet.identifier]
        )
        XCTAssertEqual(
            try rawStoredWalletSnapshots(orders: fixtureOrders, in: facade),
            before
        )
    }

    private func setup(_ settings: SelectedWalletSettings) throws -> MetaAccountModel? {
        let setupExpectation = expectation(description: "selected wallet setup completes")
        var setupResult: Result<MetaAccountModel?, Error>?

        settings.setup(runningCompletionIn: .main) { result in
            setupResult = result
            setupExpectation.fulfill()
        }

        wait(for: [setupExpectation], timeout: Constants.defaultExpectationDuration)
        return try XCTUnwrap(setupResult).get()
    }

    private func save(
        _ wallet: MetaAccountModel,
        in settings: SelectedWalletSettings
    ) throws -> MetaAccountModel {
        let saveExpectation = expectation(description: "selected wallet save completes")
        var saveResult: Result<MetaAccountModel, Error>?

        settings.save(value: wallet, runningCompletionIn: .main) { result in
            saveResult = result
            saveExpectation.fulfill()
        }

        wait(for: [saveExpectation], timeout: Constants.defaultExpectationDuration)
        return try XCTUnwrap(saveResult).get()
    }

    private func execute<Result>(
        _ operation: BaseOperation<Result>,
        using operationQueue: OperationQueue
    ) throws -> Result {
        operationQueue.addOperations([operation], waitUntilFinished: true)
        return try XCTUnwrap(operation.result).get()
    }

    private func copyWallet(
        _ wallet: MetaAccountModel,
        identifier: String,
        name: String? = nil
    ) -> MetaAccountModel {
        MetaAccountModel(
            metaId: identifier,
            name: name ?? wallet.name,
            substrateAccountId: wallet.substrateAccountId,
            substrateCryptoType: wallet.substrateCryptoType,
            substratePublicKey: wallet.substratePublicKey,
            ethereumAddress: wallet.ethereumAddress,
            ethereumPublicKey: wallet.ethereumPublicKey,
            chainAccounts: wallet.chainAccounts,
            assetKeysOrder: wallet.assetKeysOrder,
            canExportEthereumMnemonic: wallet.canExportEthereumMnemonic,
            unusedChainIds: wallet.unusedChainIds,
            selectedCurrency: wallet.selectedCurrency,
            networkManagmentFilter: wallet.networkManagmentFilter,
            assetsVisibility: wallet.assetsVisibility,
            hasBackup: wallet.hasBackup,
            favouriteChainIds: wallet.favouriteChainIds
        )
    }

    private func replacingChainAccounts(
        in wallet: MetaAccountModel,
        with chainAccounts: Set<ChainAccountModel>
    ) -> MetaAccountModel {
        MetaAccountModel(
            metaId: wallet.metaId,
            name: wallet.name,
            substrateAccountId: wallet.substrateAccountId,
            substrateCryptoType: wallet.substrateCryptoType,
            substratePublicKey: wallet.substratePublicKey,
            ethereumAddress: wallet.ethereumAddress,
            ethereumPublicKey: wallet.ethereumPublicKey,
            chainAccounts: chainAccounts,
            assetKeysOrder: wallet.assetKeysOrder,
            canExportEthereumMnemonic: wallet.canExportEthereumMnemonic,
            unusedChainIds: wallet.unusedChainIds,
            selectedCurrency: wallet.selectedCurrency,
            networkManagmentFilter: wallet.networkManagmentFilter,
            assetsVisibility: wallet.assetsVisibility,
            hasBackup: wallet.hasBackup,
            favouriteChainIds: wallet.favouriteChainIds
        )
    }

    private func seed(
        _ wallets: [ManagedMetaAccountModel],
        in facade: UserDataStorageTestFacade,
        using operationQueue: OperationQueue
    ) throws {
        let repository = facade.createRepository(
            mapper: AnyCoreDataMapper(ManagedMetaAccountMapper())
        )
        let saveOperation = repository.saveOperation({ wallets }, { [] })
        operationQueue.addOperations([saveOperation], waitUntilFinished: true)
        guard let saveResult = saveOperation.result else {
            throw WalletCorruptionTestFixtureError(
                message: "Managed wallet seed operation completed without a result"
            )
        }
        _ = try saveResult.get()
    }

    private func insertWallet(
        identifier: String,
        isSelected: Bool,
        order: Int32,
        childSpecs: [(chainId: String, marker: UInt8)],
        in facade: UserDataStorageTestFacade
    ) throws {
        try performCoreData(in: facade) { context in
            let wallet = self.copyWallet(
                AccountGenerator.generateMetaAccount(generatingChainAccounts: 0),
                identifier: identifier
            )
            let entity = CDMetaAccount(context: context)
            try MetaAccountMapper().populate(
                entity: entity,
                from: wallet,
                using: context
            )
            entity.isSelected = isSelected
            entity.order = order

            for childSpec in childSpecs {
                let child = CDChainAccount(context: context)
                child.chainId = childSpec.chainId
                child.accountId = Data(repeating: childSpec.marker, count: 32).toHex()
                child.publicKey = Data(
                    repeating: childSpec.marker &+ 0x40,
                    count: 32
                )
                child.cryptoType = Int16(CryptoType.sr25519.rawValue)
                child.ethereumBased = false
                entity.addToChainAccounts(child)
            }

            try context.save()
        }
    }

    private func insertTonOnlyWallet(
        identifier: String,
        isSelected: Bool,
        order: Int32,
        in facade: UserDataStorageTestFacade,
        malformedChainAccount: Bool = false
    ) throws {
        try performCoreData(in: facade) { context in
            let wallet = CDMetaAccount(context: context)
            wallet.metaId = identifier
            wallet.name = "Preserved TON Wallet"
            wallet.isSelected = isSelected
            wallet.order = order
            wallet.canExportEthereumMnemonic = false
            wallet.hasBackup = false
            wallet.favouriteChainIds = NSArray()
            wallet.setValue(false, forKey: "zeroBalanceAssetsHidden")
            wallet.setValue(Data(repeating: 0x41, count: 36), forKey: "tonAddress")
            wallet.setValue(Data(repeating: 0x42, count: 32), forKey: "tonPublicKey")
            wallet.setValue("v5R1", forKey: "tonContractVersion")

            if malformedChainAccount {
                let chainAccount = CDChainAccount(context: context)
                chainAccount.accountId = "not-valid-hex"
                chainAccount.chainId = "foreign-chain"
                chainAccount.publicKey = Data(repeating: 0x43, count: 32)
                wallet.addToChainAccounts(chainAccount)
            }

            try context.save()
        }
    }

    private func insertCorruptSupportedWallet(
        identifier: String,
        corruption: PersistedSupportedWalletCorruption,
        isSelected: Bool,
        order: Int32,
        in facade: UserDataStorageTestFacade,
        using operationQueue: OperationQueue
    ) throws {
        let wallet = copyWallet(
            AccountGenerator.generateMetaAccount(generatingChainAccounts: 1),
            identifier: identifier
        )
        try seed(
            [ManagedMetaAccountModel(info: wallet, isSelected: isSelected)],
            in: facade,
            using: operationQueue
        )

        try performCoreData(in: facade) { context in
            let request = NSFetchRequest<CDMetaAccount>(entityName: "CDMetaAccount")
            request.predicate = NSPredicate(
                format: "%K == %@",
                #keyPath(CDMetaAccount.metaId),
                identifier
            )
            guard let storedWallet = try context.fetch(request).first else {
                throw WalletCorruptionTestFixtureError(
                    message: "Seeded wallet \(identifier) was not found for corruption \(corruption.identifier)"
                )
            }
            storedWallet.isSelected = isSelected
            storedWallet.order = order

            let chainAccount = {
                storedWallet.chainAccounts?.allObjects.first as? CDChainAccount
            }
            func requiredChainAccount() throws -> CDChainAccount {
                guard let chainAccount = chainAccount() else {
                    throw WalletCorruptionTestFixtureError(
                        message: "Seeded wallet \(identifier) has no child for corruption \(corruption.identifier)"
                    )
                }
                return chainAccount
            }

            switch corruption {
            case .malformedSubstrateAccountId:
                storedWallet.substrateAccountId = "not-hex"
            case .shortSubstrateAccountId:
                storedWallet.substrateAccountId = "01"
            case .emptySubstratePublicKey:
                storedWallet.substratePublicKey = Data()
            case .shortSubstratePublicKey:
                storedWallet.substratePublicKey = Data(repeating: 0x51, count: 31)
            case .ecdsaWithWrongSubstratePublicKeyLength:
                storedWallet.substrateCryptoType = Int16(CryptoType.ecdsa.rawValue)
            case .invalidSubstrateCryptoType:
                storedWallet.substrateCryptoType = Int16.max
            case .malformedEthereumAddress:
                storedWallet.ethereumAddress = "not-hex"
            case .shortEthereumAddress:
                storedWallet.ethereumAddress = "01"
            case .emptyEthereumPublicKey:
                storedWallet.ethereumPublicKey = Data()
            case .emptyChainAccountId:
                try requiredChainAccount().accountId = ""
            case .malformedChainAccountId:
                try requiredChainAccount().accountId = "not-hex"
            case .emptyChainId:
                try requiredChainAccount().chainId = ""
            case .whitespaceChainId:
                try requiredChainAccount().chainId = " \n\t "
            case .paddedChainId:
                try requiredChainAccount().chainId = " padded-chain-id "
            case .emptyChainPublicKey:
                try requiredChainAccount().publicKey = Data()
            case .shortChainPublicKey:
                try requiredChainAccount().publicKey = Data(repeating: 0x52, count: 31)
            case .ecdsaWithWrongChainPublicKeyLength:
                try requiredChainAccount().cryptoType = Int16(CryptoType.ecdsa.rawValue)
            case .invalidChainCryptoType:
                try requiredChainAccount().cryptoType = Int16.max
            case .emptyMetaId:
                storedWallet.metaId = ""
            case .whitespaceMetaId:
                storedWallet.metaId = " \n\t "
            case .paddedMetaId:
                storedWallet.metaId = " \(identifier) "
            case .emptyName:
                storedWallet.name = ""
            case .whitespaceName:
                storedWallet.name = " \n\t "
            }

            try context.save()
        }
    }

    private func rawStoredWalletSnapshots(
        orders: Set<Int32>,
        in facade: UserDataStorageTestFacade
    ) throws -> [RawStoredWalletSnapshot] {
        try performCoreData(in: facade) { context in
            let request = NSFetchRequest<CDMetaAccount>(entityName: "CDMetaAccount")
            let wallets = try context.fetch(request).filter {
                orders.contains($0.order)
            }

            return wallets.map { wallet in
                let chainAccounts = (
                    wallet.chainAccounts?.allObjects as? [CDChainAccount] ?? []
                ).map {
                    RawStoredChainAccountSnapshot(
                        accountId: $0.accountId,
                        publicKey: $0.publicKey,
                        cryptoType: $0.cryptoType,
                        ethereumBased: $0.ethereumBased,
                        chainId: $0.chainId,
                        ecosystem: $0.entity.propertiesByName["ecosystem"] == nil
                            ? nil
                            : $0.value(forKey: "ecosystem") as? String
                    )
                }
                .sorted { $0.sortKey < $1.sortKey }

                let currency = wallet.selectedCurrency.map {
                    RawStoredCurrencySnapshot(
                        id: $0.id,
                        symbol: $0.symbol,
                        name: $0.name,
                        icon: $0.icon,
                        isSelected: $0.isSelected
                    )
                }
                let assetsVisibility = (
                    wallet.entity.propertiesByName["assetsVisibility"] == nil
                        ? []
                        : (wallet.value(forKey: "assetsVisibility") as? NSSet)?
                            .allObjects as? [NSManagedObject] ?? []
                ).map {
                    RawStoredAssetVisibilitySnapshot(
                        assetId: $0.value(forKey: "assetId") as? String,
                        hidden: ($0.value(forKey: "hidden") as? Bool) ?? false
                    )
                }
                .sorted { ($0.assetId ?? "") < ($1.assetId ?? "") }

                return RawStoredWalletSnapshot(
                    objectIdentifier: wallet.objectID.uriRepresentation().absoluteString,
                    metaId: wallet.metaId,
                    name: wallet.name,
                    isSelected: wallet.isSelected,
                    order: wallet.order,
                    substrateAccountId: wallet.substrateAccountId,
                    substratePublicKey: wallet.substratePublicKey,
                    substrateCryptoType: wallet.substrateCryptoType,
                    ethereumAddress: wallet.ethereumAddress,
                    ethereumPublicKey: wallet.ethereumPublicKey,
                    chainAccounts: chainAccounts,
                    assetKeysOrder: wallet.assetKeysOrder as? [String],
                    canExportEthereumMnemonic: wallet.canExportEthereumMnemonic,
                    unusedChainIds: wallet.unusedChainIds as? [String],
                    selectedCurrency: currency,
                    networkManagmentFilter: wallet.networkManagmentFilter,
                    hasBackup: wallet.hasBackup,
                    favouriteChainIds: wallet.favouriteChainIds as? [String],
                    zeroBalanceAssetsHidden: wallet.entity
                        .propertiesByName["zeroBalanceAssetsHidden"] == nil
                        ? nil
                        : wallet.value(forKey: "zeroBalanceAssetsHidden") as? Bool,
                    tonAddress: wallet.entity.propertiesByName["tonAddress"] == nil
                        ? nil
                        : wallet.value(forKey: "tonAddress") as? Data,
                    tonPublicKey: wallet.entity.propertiesByName["tonPublicKey"] == nil
                        ? nil
                        : wallet.value(forKey: "tonPublicKey") as? Data,
                    tonContractVersion: wallet.entity
                        .propertiesByName["tonContractVersion"] == nil
                        ? nil
                        : wallet.value(forKey: "tonContractVersion") as? String,
                    assetsVisibility: assetsVisibility
                )
            }
            .sorted { $0.objectIdentifier < $1.objectIdentifier }
        }
    }

    private func rawChainAccountSnapshots(
        walletIdentifier: String,
        in facade: UserDataStorageTestFacade
    ) throws -> [RawChainAccountSnapshot] {
        try performCoreData(in: facade) { context in
            let request = NSFetchRequest<CDMetaAccount>(entityName: "CDMetaAccount")
            request.predicate = NSPredicate(
                format: "%K == %@",
                #keyPath(CDMetaAccount.metaId),
                walletIdentifier
            )
            let wallet = try XCTUnwrap(context.fetch(request).first)
            let chainAccounts = wallet.chainAccounts?.allObjects as? [CDChainAccount] ?? []

            return chainAccounts.map {
                RawChainAccountSnapshot(
                    accountId: $0.accountId,
                    chainId: $0.chainId,
                    publicKey: $0.publicKey
                )
            }
            .sorted { ($0.chainId ?? "") < ($1.chainId ?? "") }
        }
    }

    private func setRawWalletOrder(
        identifier: String,
        order: Int32,
        in facade: UserDataStorageTestFacade
    ) throws {
        try performCoreData(in: facade) { context in
            let request = NSFetchRequest<CDMetaAccount>(entityName: "CDMetaAccount")
            request.predicate = NSPredicate(
                format: "%K == %@",
                #keyPath(CDMetaAccount.metaId),
                identifier
            )
            let wallet = try XCTUnwrap(context.fetch(request).first)
            wallet.order = order
            try context.save()
        }
    }

    private func rawWalletSnapshots(
        in facade: UserDataStorageTestFacade
    ) throws -> [RawWalletSnapshot] {
        try performCoreData(in: facade) { context in
            let request = NSFetchRequest<CDMetaAccount>(entityName: "CDMetaAccount")
            let wallets = try context.fetch(request)

            return try wallets.map { wallet in
                RawWalletSnapshot(
                    identifier: try XCTUnwrap(wallet.metaId),
                    isSelected: wallet.isSelected,
                    order: wallet.order,
                    substrateAccountId: wallet.substrateAccountId,
                    substratePublicKey: wallet.substratePublicKey,
                    tonAddress: wallet.value(forKey: "tonAddress") as? Data,
                    tonPublicKey: wallet.value(forKey: "tonPublicKey") as? Data,
                    tonContractVersion: wallet.value(forKey: "tonContractVersion") as? String
                )
            }
            .sorted { $0.identifier < $1.identifier }
        }
    }

    private func performCoreData<T>(
        in facade: UserDataStorageTestFacade,
        _ body: @escaping (NSManagedObjectContext) throws -> T
    ) throws -> T {
        let coreDataExpectation = expectation(description: "Core Data operation completes")
        var operationResult: Result<T, Error>?

        facade.databaseService.performAsync { context, error in
            do {
                if let error {
                    throw error
                }
                guard let context else {
                    throw WalletCorruptionTestFixtureError(
                        message: "Core Data callback completed without a context or error"
                    )
                }
                operationResult = .success(try body(context))
            } catch {
                operationResult = .failure(error)
            }

            coreDataExpectation.fulfill()
        }

        wait(for: [coreDataExpectation], timeout: Constants.defaultExpectationDuration)
        guard let operationResult else {
            throw WalletCorruptionTestFixtureError(
                message: "Core Data callback did not produce a result"
            )
        }
        return try operationResult.get()
    }
}

private struct WalletCorruptionTestFixtureError: Error, CustomStringConvertible {
    let message: String

    var description: String {
        message
    }
}

/// Corruptions that the current Core Data model can persist. Required-field `nil` cases are
/// exercised directly against unsaved entities in `MetaAccountMapperTests`.
private enum PersistedSupportedWalletCorruption: CaseIterable {
    case malformedSubstrateAccountId
    case shortSubstrateAccountId
    case emptySubstratePublicKey
    case shortSubstratePublicKey
    case ecdsaWithWrongSubstratePublicKeyLength
    case invalidSubstrateCryptoType
    case malformedEthereumAddress
    case shortEthereumAddress
    case emptyEthereumPublicKey
    case emptyChainAccountId
    case malformedChainAccountId
    case emptyChainId
    case whitespaceChainId
    case paddedChainId
    case emptyChainPublicKey
    case shortChainPublicKey
    case ecdsaWithWrongChainPublicKeyLength
    case invalidChainCryptoType
    case emptyMetaId
    case whitespaceMetaId
    case paddedMetaId
    case emptyName
    case whitespaceName

    var identifier: String {
        switch self {
        case .malformedSubstrateAccountId:
            return "malformed-substrate-id"
        case .shortSubstrateAccountId:
            return "short-substrate-id"
        case .emptySubstratePublicKey:
            return "empty-substrate-public-key"
        case .shortSubstratePublicKey:
            return "short-substrate-public-key"
        case .ecdsaWithWrongSubstratePublicKeyLength:
            return "ecdsa-wrong-substrate-public-key-length"
        case .invalidSubstrateCryptoType:
            return "invalid-substrate-crypto-type"
        case .malformedEthereumAddress:
            return "malformed-ethereum-address"
        case .shortEthereumAddress:
            return "short-ethereum-address"
        case .emptyEthereumPublicKey:
            return "empty-ethereum-public-key"
        case .emptyChainAccountId:
            return "empty-child-account-id"
        case .malformedChainAccountId:
            return "malformed-child-account-id"
        case .emptyChainId:
            return "empty-child-chain-id"
        case .whitespaceChainId:
            return "whitespace-child-chain-id"
        case .paddedChainId:
            return "padded-child-chain-id"
        case .emptyChainPublicKey:
            return "empty-child-public-key"
        case .shortChainPublicKey:
            return "short-child-public-key"
        case .ecdsaWithWrongChainPublicKeyLength:
            return "ecdsa-wrong-child-public-key-length"
        case .invalidChainCryptoType:
            return "invalid-child-crypto-type"
        case .emptyMetaId:
            return "empty-meta-id"
        case .whitespaceMetaId:
            return "whitespace-meta-id"
        case .paddedMetaId:
            return "padded-meta-id"
        case .emptyName:
            return "empty-name"
        case .whitespaceName:
            return "whitespace-name"
        }
    }
}

private struct RawStoredWalletSnapshot: Equatable {
    let objectIdentifier: String
    let metaId: String?
    let name: String?
    let isSelected: Bool
    let order: Int32
    let substrateAccountId: String?
    let substratePublicKey: Data?
    let substrateCryptoType: Int16
    let ethereumAddress: String?
    let ethereumPublicKey: Data?
    let chainAccounts: [RawStoredChainAccountSnapshot]
    let assetKeysOrder: [String]?
    let canExportEthereumMnemonic: Bool
    let unusedChainIds: [String]?
    let selectedCurrency: RawStoredCurrencySnapshot?
    let networkManagmentFilter: String?
    let hasBackup: Bool
    let favouriteChainIds: [String]?
    let zeroBalanceAssetsHidden: Bool?
    let tonAddress: Data?
    let tonPublicKey: Data?
    let tonContractVersion: String?
    let assetsVisibility: [RawStoredAssetVisibilitySnapshot]
}

private struct RawStoredChainAccountSnapshot: Equatable {
    let accountId: String?
    let publicKey: Data?
    let cryptoType: Int16
    let ethereumBased: Bool
    let chainId: String?
    let ecosystem: String?

    var sortKey: String {
        [
            chainId ?? "<nil>",
            accountId ?? "<nil>",
            publicKey?.base64EncodedString() ?? "<nil>",
            String(cryptoType),
            String(ethereumBased),
            ecosystem ?? "<nil>"
        ].joined(separator: "|")
    }
}

private struct RawStoredCurrencySnapshot: Equatable {
    let id: String?
    let symbol: String?
    let name: String?
    let icon: String?
    let isSelected: Bool
}

private struct RawStoredAssetVisibilitySnapshot: Equatable {
    let assetId: String?
    let hidden: Bool
}

private struct RawWalletSnapshot: Equatable {
    struct Payload: Equatable {
        let substrateAccountId: String?
        let substratePublicKey: Data?
        let tonAddress: Data?
        let tonPublicKey: Data?
        let tonContractVersion: String?
    }

    let identifier: String
    let isSelected: Bool
    let order: Int32
    let substrateAccountId: String?
    let substratePublicKey: Data?
    let tonAddress: Data?
    let tonPublicKey: Data?
    let tonContractVersion: String?

    var payload: Payload {
        Payload(
            substrateAccountId: substrateAccountId,
            substratePublicKey: substratePublicKey,
            tonAddress: tonAddress,
            tonPublicKey: tonPublicKey,
            tonContractVersion: tonContractVersion
        )
    }
}

private struct RawChainAccountSnapshot: Equatable {
    let accountId: String?
    let chainId: String?
    let publicKey: Data?
}

private enum ControllableWalletCoreDataServiceError: Error {
    case missingRequest
    case requestAlreadyResolved
    case injectedFailure
}

private final class ControllableWalletCoreDataService: CoreDataServiceProtocol {
    let configuration: CoreDataServiceConfigurationProtocol

    private let lock = NSLock()
    private let requestExpectations: [XCTestExpectation]
    private var requests: [CoreDataContextInvocationBlock] = []
    private var resolvedRequestIndexes = Set<Int>()

    var requestCount: Int {
        lock.lock()
        defer { lock.unlock() }

        return requests.count
    }

    init(
        configuration: CoreDataServiceConfigurationProtocol,
        requestExpectations: [XCTestExpectation]
    ) {
        self.configuration = configuration
        self.requestExpectations = requestExpectations
    }

    func performAsync(block: @escaping CoreDataContextInvocationBlock) {
        lock.lock()
        let requestIndex = requests.count
        requests.append(block)
        let requestExpectation = requestExpectations[safe: requestIndex]
        lock.unlock()

        requestExpectation?.fulfill()
    }

    func resolveRequest(
        at index: Int,
        using sourceService: CoreDataServiceProtocol
    ) throws {
        lock.lock()
        guard requests.indices.contains(index) else {
            lock.unlock()
            throw ControllableWalletCoreDataServiceError.missingRequest
        }
        guard resolvedRequestIndexes.insert(index).inserted else {
            lock.unlock()
            throw ControllableWalletCoreDataServiceError.requestAlreadyResolved
        }
        let request = requests[index]
        lock.unlock()

        sourceService.performAsync(block: request)
    }

    func failRequest(at index: Int, with error: Error) throws {
        lock.lock()
        guard requests.indices.contains(index) else {
            lock.unlock()
            throw ControllableWalletCoreDataServiceError.missingRequest
        }
        guard resolvedRequestIndexes.insert(index).inserted else {
            lock.unlock()
            throw ControllableWalletCoreDataServiceError.requestAlreadyResolved
        }
        let request = requests[index]
        lock.unlock()

        request(nil, error)
    }

    func close() throws {}

    func drop() throws {}
}

private final class ControllableWalletStorageFacade: StorageFacadeProtocol {
    let databaseService: CoreDataServiceProtocol

    init(databaseService: CoreDataServiceProtocol) {
        self.databaseService = databaseService
    }

    func createRepository<T, U>(
        filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor],
        mapper: AnyCoreDataMapper<T, U>
    ) -> CoreDataRepository<T, U> where T: Identifiable, U: NSManagedObject {
        CoreDataRepository(
            databaseService: databaseService,
            mapper: mapper,
            filter: filter,
            sortDescriptors: sortDescriptors
        )
    }

    func createAsyncRepository<T, U>(
        filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor],
        mapper: AnyCoreDataMapper<T, U>
    ) -> AsyncCoreDataRepositoryDefault<T, U> where T: Identifiable, U: NSManagedObject {
        AsyncCoreDataRepositoryDefault(
            databaseService: databaseService,
            mapper: mapper,
            filter: filter,
            sortDescriptors: sortDescriptors
        )
    }
}
