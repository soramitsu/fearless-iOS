import Foundation
@testable import fearless
import RobinHood
import BigInt
import SSFModels
import SSFRuntimeCodingService

final class WalletLocalSubscriptionFactoryStub: WalletLocalSubscriptionFactoryProtocol {
    var operationManager: RobinHood.OperationManagerProtocol
    var processingQueue: DispatchQueue?

    init() {
        self.operationManager = OperationManagerFacade.sharedManager
    }

    func getAccountProvider(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) throws -> StreamableProvider<AccountInfoStorageWrapper> {
        let codingPath = chainAsset.storagePath

        let localKey = try LocalStorageKeyFactory().createFromStoragePath(
            codingPath,
            chainAssetKey: chainAsset.uniqueKey(accountId: accountId)
        )

        return getProvider(for: localKey)
    }

    func getRuntimeProvider(for chainId: ChainModel.Id) -> RuntimeProviderProtocol? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        return chainRegistry.getRuntimeProvider(for: chainId)
    }

    private func getProvider(for key: String) -> StreamableProvider<AccountInfoStorageWrapper> {
        let facade = SubstrateDataStorageFacade.shared

        let mapper: CodableCoreDataMapper<AccountInfoStorageWrapper, fearless.CDAccountInfo> =
            CodableCoreDataMapper(entityIdentifierFieldName: #keyPath(fearless.CDAccountInfo.identifier))

        let filter = NSPredicate.filterStorageItemsBy(identifier: key)
        let storage: CoreDataRepository<AccountInfoStorageWrapper, fearless.CDAccountInfo> =
            facade.createRepository(filter: filter)
        let source = EmptyStreamableSource<AccountInfoStorageWrapper>()
        let observable = CoreDataContextObservable(
            service: facade.databaseService,
            mapper: AnyCoreDataMapper(mapper),
            predicate: { ($0 as? fearless.CDAccountInfo)?.identifier == key },
            processingQueue: processingQueue
        )

        return StreamableProvider(
            source: AnyStreamableSource(source),
            repository: AnyDataProviderRepository(storage),
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: operationManager,
            serialQueue: processingQueue
        )
    }
}
