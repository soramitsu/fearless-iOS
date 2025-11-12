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
        let codingPath = chainAsset.fearlessStoragePath

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
        let source = EmptyStreamableSource<AccountInfoStorageWrapper>()
        let repository = EmptyRepository<AccountInfoStorageWrapper>()
        let observable = DummyRepositoryObservable<AccountInfoStorageWrapper>()

        return StreamableProvider(
            source: AnyStreamableSource(source),
            repository: AnyDataProviderRepository(repository),
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: operationManager,
            serialQueue: processingQueue
        )
    }
}
