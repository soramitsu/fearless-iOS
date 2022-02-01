import Foundation
import RobinHood

class SubstrateLocalSubscriptionFactory {
    private var providers: [String: WeakWrapper] = [:]

    let chainRegistry: ChainRegistryProtocol
    let storageFacade: StorageFacadeProtocol
    let operationManager: OperationManagerProtocol
    let logger: LoggerProtocol
    let stremableProviderFactory: SubstrateDataProviderFactoryProtocol

    init(
        chainRegistry: ChainRegistryProtocol,
        storageFacade: StorageFacadeProtocol,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.storageFacade = storageFacade
        self.operationManager = operationManager
        self.logger = logger
        stremableProviderFactory = SubstrateDataProviderFactory(
            facade: storageFacade,
            operationManager: operationManager,
            logger: logger
        )
    }

    func saveProvider(_ provider: AnyObject, for key: String) {
        providers[key] = WeakWrapper(target: provider)
    }

    func getProvider(for key: String) -> AnyObject? { providers[key]?.target }

    func clearIfNeeded() {
        providers = providers.filter { $0.value.target != nil }
    }

    func getDataProvider<T>(
        for localKey: String,
        chainId: ChainModel.Id,
        storageCodingPath: StorageCodingPath,
        shouldUseFallback: Bool
    ) throws -> AnyDataProvider<ChainStorageDecodedItem<T>> where T: Equatable & Decodable {
        clearIfNeeded()

        if let dataProvider = getProvider(for: localKey) as? DataProvider<ChainStorageDecodedItem<T>> {
            return AnyDataProvider(dataProvider)
        }

        guard let runtimeCodingProvider = chainRegistry.getRuntimeProvider(for: chainId) else {
            throw ChainRegistryError.runtimeMetadaUnavailable
        }

        let repository = InMemoryDataProviderRepository<ChainStorageDecodedItem<T>>()

        let streamableProvider = stremableProviderFactory.createStorageProvider(for: localKey)

        let trigger = DataProviderProxyTrigger()
        let source: StorageProviderSource<T> = StorageProviderSource(
            itemIdentifier: localKey,
            codingPath: storageCodingPath,
            runtimeService: runtimeCodingProvider,
            provider: streamableProvider,
            trigger: trigger,
            shouldUseFallback: shouldUseFallback
        )

        let dataProvider = DataProvider(
            source: AnyDataProviderSource(source),
            repository: AnyDataProviderRepository(repository),
            updateTrigger: trigger
        )

        saveProvider(dataProvider, for: localKey)

        return AnyDataProvider(dataProvider)
    }
}
