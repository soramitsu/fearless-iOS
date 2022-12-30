import Foundation
import RobinHood

protocol WalletLocalSubscriptionFactoryProtocol {
    var operationManager: OperationManagerProtocol { get }
    var processingQueue: DispatchQueue? { get }

    func getAccountProvider(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) throws -> StreamableProvider<ChainStorageItem>

    func getRuntimeProvider(for chainId: ChainModel.Id) -> RuntimeProviderProtocol?
}

final class WalletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol {
    static let processingQueue = DispatchQueue(
        label: "co.jp.WalletLocalSubscriptionFactory.processingQueue.\(UUID().uuidString)"
    )

    static let shared = WalletLocalSubscriptionFactory(
        operationManager: OperationManagerFacade.sharedManager,
        processingQueue: WalletLocalSubscriptionFactory.processingQueue,
        chainRegistry: ChainRegistryFacade.sharedRegistry,
        logger: Logger.shared
    )

    let operationManager: OperationManagerProtocol
    let processingQueue: DispatchQueue?
    private let chainRegistry: ChainRegistryProtocol
    private let logger: Logger

    init(
        operationManager: OperationManagerProtocol,
        processingQueue: DispatchQueue? = nil,
        chainRegistry: ChainRegistryProtocol,
        logger: Logger
    ) {
        self.operationManager = operationManager
        self.processingQueue = processingQueue
        self.chainRegistry = chainRegistry
        self.logger = logger
    }

    func getAccountProvider(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) throws -> StreamableProvider<ChainStorageItem> {
        let codingPath = chainAsset.storagePath

        let localKey = try LocalStorageKeyFactory().createFromStoragePath(
            codingPath,
            chainAssetKey: chainAsset.uniqueKey(accountId: accountId)
        )

        return getProvider(for: localKey)
    }

    func getRuntimeProvider(for chainId: ChainModel.Id) -> RuntimeProviderProtocol? {
        chainRegistry.getRuntimeProvider(for: chainId)
    }

    private func getProvider(for key: String) -> StreamableProvider<ChainStorageItem> {
        let facade = SubstrateDataStorageFacade.shared

        let mapper: CodableCoreDataMapper<ChainStorageItem, CDChainStorageItem> =
            CodableCoreDataMapper(entityIdentifierFieldName: #keyPath(CDChainStorageItem.identifier))

        let filter = NSPredicate.filterStorageItemsBy(identifier: key)
        let storage: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            facade.createRepository(filter: filter)
        let source = EmptyStreamableSource<ChainStorageItem>()
        let observable = CoreDataContextObservable(
            service: facade.databaseService,
            mapper: AnyCoreDataMapper(mapper),
            predicate: { $0.identifier == key },
            processingQueue: processingQueue
        )

        observable.start { error in
            if let error = error {
                self.logger.error("Can't start storage observing: \(error)")
            }
        }

        return StreamableProvider(
            source: AnyStreamableSource(source),
            repository: AnyDataProviderRepository(storage),
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: operationManager,
            serialQueue: processingQueue
        )
    }
}
