import CoreData
import IrohaCrypto
import RobinHood
import SQLite3
import SSFModels
import XCTest
@testable import fearless

final class TransformableArchiveSafetyTests: XCTestCase {
    private static let invalidArchiveHex = "00FF00"

    func testObjectiveCExceptionBoundaryReturnsOnlySanitizedError() throws {
        let secretReason = "archive payload and wallet metadata"
        do {
            _ = try FearlessObjectiveCExceptionCatcher.performObjectRead {
                NSException(
                    name: .invalidArgumentException,
                    reason: secretReason,
                    userInfo: ["private": secretReason]
                ).raise()
                return nil
            }
            XCTFail("Raised Objective-C exception must become a Swift error")
        } catch {
            let sanitizedError = error as NSError
            XCTAssertEqual(
                sanitizedError.domain,
                FearlessObjectiveCExceptionErrorDomain
            )
            XCTAssertEqual(sanitizedError.code, 1)
            XCTAssertEqual(
                Set(
                    sanitizedError.userInfo.keys.map(
                        String.init(describing:)
                    )
                ),
                Set([NSLocalizedDescriptionKey])
            )
            XCTAssertFalse(
                sanitizedError.localizedDescription.contains(secretReason)
            )
            XCTAssertFalse(
                String(describing: sanitizedError.userInfo)
                    .contains(secretReason)
            )
        }
    }

    func testObjectiveCExceptionBoundaryAllowsSuccessfulVoidOperation() throws {
        var didRun = false

        try SafeObjectiveCExceptionBoundary.perform {
            didRun = true
        }

        XCTAssertTrue(didRun)
    }

    func testPersistentCorruptFavouriteChainIdsDefaultsOnlyPreferenceWithoutMutation() throws {
        try assertPersistentCorruptWalletTransformable(
            attribute: "favouriteChainIds",
            column: "ZFAVOURITECHAINIDS"
        )
    }

    func testPersistentCorruptAssetKeysOrderDefaultsOnlyPreferenceWithoutMutation() throws {
        try assertPersistentCorruptWalletTransformable(
            attribute: "assetKeysOrder",
            column: "ZASSETKEYSORDER"
        )
    }

    func testPersistentCorruptUnusedChainIdsDefaultsOnlyPreferenceWithoutMutation() throws {
        try assertPersistentCorruptWalletTransformable(
            attribute: "unusedChainIds",
            column: "ZUNUSEDCHAINIDS"
        )
    }

    func testPersistentWrongStoredTypeDefaultsOnlyPreferenceWithoutMutation() throws {
        let wrongTypeArchive = try NSKeyedArchiver.archivedData(
            withRootObject: NSString(string: "not-an-array"),
            requiringSecureCoding: true
        )

        try assertPersistentCorruptWalletTransformable(
            attribute: "assetKeysOrder",
            column: "ZASSETKEYSORDER",
            archiveHex: wrongTypeArchive.map {
                String(format: "%02X", $0)
            }.joined()
        )
    }

    func testPersistentValidWalletArchivesPreserveEveryPreference() throws {
        try withCorruptedUserStore(
            updateSQL:
                "UPDATE ZCDMETAACCOUNT SET ZORDER = ZORDER"
        ) { context, _, facade in
            let wallet = try perform(in: context) {
                let entity = try fetchSingle(CDMetaAccount.self, in: context)
                return try MetaAccountMapper().transform(entity: entity)
            }

            XCTAssertEqual(wallet.assetKeysOrder, ["asset-a"])
            XCTAssertEqual(wallet.unusedChainIds, ["unused-chain"])
            XCTAssertEqual(wallet.favouriteChainIds, ["favourite-chain"])

            let repository = AccountRepositoryFactory(storageFacade: facade)
                .createMetaAccountRepository(
                    for: nil,
                    sortDescriptors: []
                )
            let operation = repository.fetchAllOperation(
                with: RepositoryFetchOptions()
            )
            let queue = OperationQueue()
            queue.addOperations([operation], waitUntilFinished: true)
            XCTAssertEqual(
                try XCTUnwrap(operation.result).get().count,
                1
            )
        }
    }

    func testPersistentCorruptChainOptionsDefaultsWithoutMutatingCache() throws {
        try withCorruptedSubstrateStore(
            updateSQL:
                "UPDATE ZCDCHAIN SET ZOPTIONS = X'\(Self.invalidArchiveHex)'"
        ) { context, storeURL, facade in
            let mappedChain = try perform(in: context) {
                let entity = try fetchSingle(CDChain.self, in: context)
                return try ChainModelMapper().transform(entity: entity)
            }

            XCTAssertNil(mappedChain.options)
            XCTAssertEqual(mappedChain.chainId, "transformable-chain")

            let repository: CoreDataRepository<ChainModel, CDChain> =
                facade.createRepository(
                    filter: nil,
                    sortDescriptors: [],
                    mapper: AnyCoreDataMapper(ChainModelMapper())
                )
            XCTAssertEqual(try fetchAll(from: repository).count, 1)
            try assertBlobAndRowRemain(
                storeURL: storeURL,
                table: "ZCDCHAIN",
                column: "ZOPTIONS"
            )
        }
    }

    func testPersistentCorruptExternalApiTypesSkipsOnlyExplorerWithoutMutatingCache() throws {
        try withCorruptedSubstrateStore(
            updateSQL:
                "UPDATE ZCDEXTERNALAPI SET ZTYPES = X'\(Self.invalidArchiveHex)'"
        ) { context, storeURL, facade in
            let mappedChain = try perform(in: context) {
                let entity = try fetchSingle(CDChain.self, in: context)
                return try ChainModelMapper().transform(entity: entity)
            }

            XCTAssertEqual(mappedChain.externalApi?.explorers, [])
            XCTAssertEqual(mappedChain.assets.count, 1)

            let repository: CoreDataRepository<ChainModel, CDChain> =
                facade.createRepository(
                    filter: nil,
                    sortDescriptors: [],
                    mapper: AnyCoreDataMapper(ChainModelMapper())
                )
            XCTAssertEqual(try fetchAll(from: repository).count, 1)
            try assertBlobAndRowRemain(
                storeURL: storeURL,
                table: "ZCDEXTERNALAPI",
                column: "ZTYPES"
            )
        }
    }

    func testPersistentCorruptAssetPurchaseProvidersDefaultsWithoutMutatingCache() throws {
        try withCorruptedSubstrateStore(
            updateSQL:
                "UPDATE ZCDASSET SET ZPURCHASEPROVIDERS = X'\(Self.invalidArchiveHex)'"
        ) { context, storeURL, facade in
            let mappedAsset = try perform(in: context) {
                let entity = try fetchSingle(CDAsset.self, in: context)
                return try AssetModelMapper().transform(entity: entity)
            }
            XCTAssertNil(mappedAsset.purchaseProviders)

            let repository: CoreDataRepository<ChainModel, CDChain> =
                facade.createRepository(
                    filter: nil,
                    sortDescriptors: [],
                    mapper: AnyCoreDataMapper(ChainModelMapper())
                )
            let mappedChain = try XCTUnwrap(
                try fetchAll(from: repository).first
            )
            XCTAssertEqual(mappedChain.assets.count, 1)
            XCTAssertNil(mappedChain.assets.first?.purchaseProviders)
            try assertBlobAndRowRemain(
                storeURL: storeURL,
                table: "ZCDASSET",
                column: "ZPURCHASEPROVIDERS"
            )
        }
    }

    func testPersistentCorruptPolkaswapTransformablesSurfaceCatchableErrorWithoutMutation() throws {
        for column in ["ZAVAILABLESOURCES", "ZFORCESMARTIDS"] {
            try withCorruptedSubstrateStore(
                updateSQL:
                    "UPDATE ZCDPOLKASWAPREMOTESETTINGS " +
                    "SET \(column) = X'\(Self.invalidArchiveHex)'"
            ) { context, storeURL, _ in
                XCTAssertThrowsError(
                    try perform(in: context) {
                        let entity = try fetchSingle(
                            CDPolkaswapRemoteSettings.self,
                            in: context
                        )
                        return try PolkaswapSettingMapper().transform(
                            entity: entity
                        )
                    }
                ) { error in
                    guard
                        case PolkaswapSettingMapperError.requiredFieldsMissing =
                            error
                    else {
                        return XCTFail("Unexpected mapper error: \(error)")
                    }
                }

                try assertBlobAndRowRemain(
                    storeURL: storeURL,
                    table: "ZCDPOLKASWAPREMOTESETTINGS",
                    column: column
                )
            }
        }
    }

    func testProductionRuntimeRegistryRetainsEveryCurrentStoreClass() throws {
        XCTAssertEqual(
            ManagedObjectRuntimeClassRegistry.substrateV8Classes.count,
            19
        )
        XCTAssertEqual(
            ManagedObjectRuntimeClassRegistry.userV11Classes.count,
            7
        )
        XCTAssertEqual(
            ManagedObjectRuntimeClassRegistry.classesByRuntimeName.count,
            26
        )

        for model in [
            try loadUserModel(qualifyClasses: false).model,
            try loadSubstrateModel(qualifyClasses: false).model
        ] {
            for entity in model.entities {
                let entityName = try XCTUnwrap(entity.name)
                let className = try XCTUnwrap(entity.managedObjectClassName)
                let resolvedClass = try XCTUnwrap(
                    ManagedObjectRuntimeClassRegistry.resolve(
                        className: className
                    ),
                    "Registry must resolve \(entityName)"
                )

                XCTAssertTrue(
                    ManagedObjectRuntimeClassRegistry.classesByRuntimeName
                        .values.contains {
                            ObjectIdentifier($0) ==
                                ObjectIdentifier(resolvedClass)
                        }
                )
            }
        }
    }

    private func assertPersistentCorruptWalletTransformable(
        attribute: String,
        column: String,
        archiveHex: String =
            TransformableArchiveSafetyTests.invalidArchiveHex
    ) throws {
        try withCorruptedUserStore(
            updateSQL:
                "UPDATE ZCDMETAACCOUNT " +
                "SET \(column) = X'\(archiveHex)'"
        ) { context, storeURL, facade in
            let wallet = try perform(in: context) {
                let entity = try fetchSingle(
                    CDMetaAccount.self,
                    in: context
                )
                return try MetaAccountMapper().transform(entity: entity)
            }

            XCTAssertEqual(
                wallet.assetKeysOrder,
                attribute == "assetKeysOrder" ? nil : ["asset-a"]
            )
            XCTAssertEqual(
                wallet.unusedChainIds,
                attribute == "unusedChainIds" ? nil : ["unused-chain"]
            )
            XCTAssertEqual(
                wallet.favouriteChainIds,
                attribute == "favouriteChainIds" ? [] : ["favourite-chain"]
            )

            let projection = try perform(in: context) {
                let entity = try fetchSingle(CDMetaAccount.self, in: context)
                return try MetaAccountSelectionMapper().transform(
                    entity: entity
                )
            }
            XCTAssertEqual(projection.recordState, .supported)
            XCTAssertNotNil(projection.wallet)
            XCTAssertTrue(projection.recordState.allowsStoredRecordUpdates)

            let repository = AccountRepositoryFactory(storageFacade: facade)
                .createMetaAccountRepository(
                    for: nil,
                    sortDescriptors: []
                )
            let operation = repository.fetchAllOperation(
                with: RepositoryFetchOptions()
            )
            let queue = OperationQueue()
            queue.addOperations([operation], waitUntilFinished: true)
            XCTAssertEqual(
                try XCTUnwrap(operation.result).get().count,
                1
            )

            try assertBlobAndRowRemain(
                storeURL: storeURL,
                table: "ZCDMETAACCOUNT",
                column: column,
                expectedHex: archiveHex
            )
        }
    }

    private func withCorruptedUserStore(
        updateSQL: String,
        body: (
            NSManagedObjectContext,
            URL,
            PersistentFixtureStorageFacade
        ) throws -> Void
    ) throws {
        let loadedModel = try loadUserModel()
        try withCorruptedStore(
            modelURL: loadedModel.url,
            model: loadedModel.model,
            updateSQL: updateSQL,
            seed: seedUserStore,
            body: body
        )
    }

    private func withCorruptedSubstrateStore(
        updateSQL: String,
        body: (
            NSManagedObjectContext,
            URL,
            PersistentFixtureStorageFacade
        ) throws -> Void
    ) throws {
        let loadedModel = try loadSubstrateModel()
        try withCorruptedStore(
            modelURL: loadedModel.url,
            model: loadedModel.model,
            updateSQL: updateSQL,
            seed: seedSubstrateStore,
            body: body
        )
    }

    private func withCorruptedStore(
        modelURL: URL,
        model: NSManagedObjectModel,
        updateSQL: String,
        seed: (NSManagedObjectContext) throws -> Void,
        body: (
            NSManagedObjectContext,
            URL,
            PersistentFixtureStorageFacade
        ) throws -> Void
    ) throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "TransformableArchiveSafety-\(UUID().uuidString)",
                isDirectory: true
            )
        let storeURL = directoryURL.appendingPathComponent("Store.sqlite")
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        defer {
            try? FileManager.default.removeItem(at: directoryURL)
        }

        let options: [AnyHashable: Any] = [
            NSSQLitePragmasOption: ["journal_mode": "DELETE"]
        ]
        let writerCoordinator = NSPersistentStoreCoordinator(
            managedObjectModel: model
        )
        let writerStore = try writerCoordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: options
        )
        let writerContext = NSManagedObjectContext(
            concurrencyType: .privateQueueConcurrencyType
        )
        writerContext.persistentStoreCoordinator = writerCoordinator
        try perform(in: writerContext) {
            try seed(writerContext)
            try writerContext.save()
            writerContext.reset()
        }
        try writerCoordinator.remove(writerStore)

        XCTAssertEqual(try executeSQLiteUpdate(updateSQL, at: storeURL), 1)

        let readerCoordinator = NSPersistentStoreCoordinator(
            managedObjectModel: model
        )
        let readerStore = try readerCoordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: options
        )
        let readerContext = NSManagedObjectContext(
            concurrencyType: .privateQueueConcurrencyType
        )
        readerContext.persistentStoreCoordinator = readerCoordinator
        let facade = PersistentFixtureStorageFacade(
            context: readerContext,
            modelURL: modelURL
        )

        defer {
            try? perform(in: readerContext) {
                readerContext.reset()
            }
            try? readerCoordinator.remove(readerStore)
        }

        try body(readerContext, storeURL, facade)
        XCTAssertFalse(readerContext.hasChanges)
    }

    private func seedUserStore(_ context: NSManagedObjectContext) throws {
        let model = MetaAccountModel(
            metaId: "transformable-wallet",
            name: "Transformable archive fixture",
            substrateAccountId: Data(repeating: 0x11, count: 32),
            substrateCryptoType: CryptoType.sr25519.rawValue,
            substratePublicKey: Data(repeating: 0x22, count: 32),
            ethereumAddress: nil,
            ethereumPublicKey: nil,
            chainAccounts: [],
            assetKeysOrder: ["asset-a"],
            canExportEthereumMnemonic: false,
            unusedChainIds: ["unused-chain"],
            selectedCurrency: Currency.defaultCurrency(),
            networkManagmentFilter: nil,
            assetsVisibility: [],
            hasBackup: true,
            favouriteChainIds: ["favourite-chain"]
        )
        let entity = CDMetaAccount(context: context)
        try MetaAccountMapper().populate(
            entity: entity,
            from: model,
            using: context
        )
        entity.isSelected = true
        entity.order = 1
    }

    private func seedSubstrateStore(
        _ context: NSManagedObjectContext
    ) throws {
        let chain = CDChain(context: context)
        chain.chainId = "transformable-chain"
        chain.name = "Transformable archive fixture"
        chain.addressPrefix = 0
        chain.isEthereumBased = false
        chain.isTestnet = false
        chain.hasCrowdloans = false
        chain.setValue(
            NSArray(object: ChainOptions.poolStaking.rawValue),
            forKey: "options"
        )

        let node = CDChainNode(context: context)
        node.name = "Fixture node"
        node.url = try XCTUnwrap(URL(string: "wss://fixture.example"))
        node.chain = chain
        chain.nodes = NSSet(object: node)
        chain.selectedNode = node

        let explorer = CDExternalApi(context: context)
        explorer.type = "subscan"
        explorer.url = "https://explorer.example"
        explorer.setValue(NSArray(object: "extrinsic"), forKey: "types")
        explorer.chain = chain
        chain.explorers = NSSet(object: explorer)

        let asset = CDAsset(context: context)
        asset.id = "fixture-asset"
        asset.name = "Fixture Asset"
        asset.symbol = "FIX"
        asset.precision = 12
        asset.isUtility = true
        asset.isNative = true
        asset.setValue(NSArray(object: "moonpay"), forKey: "purchaseProviders")
        asset.chain = chain
        chain.assets = NSSet(object: asset)

        let polkaswap = CDPolkaswapRemoteSettings(context: context)
        polkaswap.version = "1"
        polkaswap.setValue(NSArray(), forKey: "availableSources")
        polkaswap.setValue(NSArray(), forKey: "forceSmartIds")
        polkaswap.availableDexIds = NSSet()
        polkaswap.xstusdId = "fixture-xstusd"
    }

    private func loadUserModel(
        qualifyClasses: Bool = true
    ) throws -> (
        url: URL,
        model: NSManagedObjectModel
    ) {
        let modelURL = try XCTUnwrap(
            [
                Bundle(for: UserDataStorageFacade.self),
                Bundle.main
            ].lazy.compactMap {
                UserStorageParams.modelVersion.modelURL(
                    in: $0,
                    legacyModelDirectory: UserStorageParams.modelDirectory
                )
            }.first
        )
        let loadedModel = try XCTUnwrap(
            NSManagedObjectModel(contentsOf: modelURL)
        )
        let model = try XCTUnwrap(
            loadedModel.copy() as? NSManagedObjectModel
        )
        if qualifyClasses {
            try qualifyManagedObjectClasses(in: model)
        }
        return (modelURL, model)
    }

    private func loadSubstrateModel(
        qualifyClasses: Bool = true
    ) throws -> (
        url: URL,
        model: NSManagedObjectModel
    ) {
        let modelURL = try XCTUnwrap(
            Bundle(for: SubstrateDataStorageFacade.self).url(
                forResource: "SubstrateDataModel",
                withExtension: "momd"
            )
        )
        let loadedModel = try XCTUnwrap(
            NSManagedObjectModel(contentsOf: modelURL)
        )
        let model = try XCTUnwrap(
            loadedModel.copy() as? NSManagedObjectModel
        )
        if qualifyClasses {
            try qualifyManagedObjectClasses(in: model)
        }
        return (modelURL, model)
    }

    private func qualifyManagedObjectClasses(
        in model: NSManagedObjectModel
    ) throws {
        for entity in model.entities {
            let entityName = try XCTUnwrap(entity.name)
            let storedClassName = try XCTUnwrap(
                entity.managedObjectClassName
            )
            let runtimeClass = try XCTUnwrap(
                ManagedObjectRuntimeClassRegistry.resolve(
                    className: storedClassName
                ),
                "Missing runtime class for \(entityName)"
            )
            entity.managedObjectClassName = NSStringFromClass(runtimeClass)
        }
    }

    private func perform<T>(
        in context: NSManagedObjectContext,
        _ block: () throws -> T
    ) throws -> T {
        var result: Result<T, Error>?
        context.performAndWait {
            result = Result {
                try block()
            }
        }
        return try XCTUnwrap(result).get()
    }

    private func fetchSingle<Entity: NSManagedObject>(
        _: Entity.Type,
        in context: NSManagedObjectContext
    ) throws -> Entity {
        let entityName = try XCTUnwrap(Entity.entity().name)
        let request = NSFetchRequest<Entity>(entityName: entityName)
        request.fetchLimit = 2
        request.includesPendingChanges = false
        request.includesSubentities = false
        let entities = try context.fetch(request)
        XCTAssertEqual(entities.count, 1)
        return try XCTUnwrap(entities.first)
    }

    private func fetchAll<Model: Identifiable, Entity: NSManagedObject>(
        from repository: CoreDataRepository<Model, Entity>
    ) throws -> [Model] {
        let operation = repository.fetchAllOperation(
            with: RepositoryFetchOptions()
        )
        let queue = OperationQueue()
        queue.addOperations([operation], waitUntilFinished: true)
        return try XCTUnwrap(operation.result).get()
    }

    private func assertBlobAndRowRemain(
        storeURL: URL,
        table: String,
        column: String,
        expectedHex: String =
            TransformableArchiveSafetyTests.invalidArchiveHex
    ) throws {
        XCTAssertEqual(
            try sqliteText(
                "SELECT COUNT(*) FROM \(table)",
                at: storeURL
            ),
            "1"
        )
        XCTAssertEqual(
            try sqliteText(
                "SELECT HEX(\(column)) FROM \(table)",
                at: storeURL
            ),
            expectedHex
        )
    }

    private func executeSQLiteUpdate(
        _ sql: String,
        at storeURL: URL
    ) throws -> Int {
        let database = try openSQLite(at: storeURL)
        defer {
            sqlite3_close(database)
        }

        var errorMessage: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(
            database,
            sql,
            nil,
            nil,
            &errorMessage
        )
        defer {
            sqlite3_free(errorMessage)
        }

        guard result == SQLITE_OK else {
            throw sqliteError(
                database: database,
                code: result,
                fallback: errorMessage.map { String(cString: $0) }
            )
        }

        return Int(sqlite3_changes(database))
    }

    private func sqliteText(
        _ sql: String,
        at storeURL: URL
    ) throws -> String? {
        let database = try openSQLite(at: storeURL)
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
            throw sqliteError(
                database: database,
                code: prepareResult
            )
        }
        defer {
            sqlite3_finalize(statement)
        }

        let stepResult = sqlite3_step(statement)
        guard stepResult == SQLITE_ROW else {
            throw sqliteError(database: database, code: stepResult)
        }
        guard let text = sqlite3_column_text(statement, 0) else {
            return nil
        }
        let count = Int(sqlite3_column_bytes(statement, 0))
        return String(
            decoding: UnsafeBufferPointer(start: text, count: count),
            as: UTF8.self
        )
    }

    private func openSQLite(at storeURL: URL) throws -> OpaquePointer {
        var database: OpaquePointer?
        let result = sqlite3_open_v2(
            storeURL.path,
            &database,
            SQLITE_OPEN_READWRITE,
            nil
        )
        guard result == SQLITE_OK, let database else {
            defer {
                if let database {
                    sqlite3_close(database)
                }
            }
            throw sqliteError(database: database, code: result)
        }
        return database
    }

    private func sqliteError(
        database: OpaquePointer?,
        code: Int32,
        fallback: String? = nil
    ) -> Error {
        let description = fallback ??
            database.flatMap(sqlite3_errmsg).map(String.init(cString:)) ??
            "Unknown SQLite error"
        return NSError(
            domain: "TransformableArchiveSafetyTests.SQLite",
            code: Int(code),
            userInfo: [NSLocalizedDescriptionKey: description]
        )
    }
}

private final class PersistentFixtureCoreDataService:
    CoreDataServiceProtocol {
    let configuration: CoreDataServiceConfigurationProtocol

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext, modelURL: URL) {
        self.context = context
        configuration = CoreDataServiceConfiguration(
            modelURL: modelURL,
            storageType: .inMemory
        )
    }

    func performAsync(block: @escaping CoreDataContextInvocationBlock) {
        context.perform {
            block(self.context, nil)
        }
    }

    func close() throws {}

    func drop() throws {}
}

private final class PersistentFixtureStorageFacade: StorageFacadeProtocol {
    let databaseService: CoreDataServiceProtocol

    init(context: NSManagedObjectContext, modelURL: URL) {
        databaseService = PersistentFixtureCoreDataService(
            context: context,
            modelURL: modelURL
        )
    }

    func createRepository<T, U>(
        filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor],
        mapper: AnyCoreDataMapper<T, U>
    ) -> CoreDataRepository<T, U>
        where T: Identifiable, U: NSManagedObject {
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
    ) -> AsyncCoreDataRepositoryDefault<T, U>
        where T: Identifiable, U: NSManagedObject {
        AsyncCoreDataRepositoryDefault(
            databaseService: databaseService,
            mapper: mapper,
            filter: filter,
            sortDescriptors: sortDescriptors
        )
    }
}
