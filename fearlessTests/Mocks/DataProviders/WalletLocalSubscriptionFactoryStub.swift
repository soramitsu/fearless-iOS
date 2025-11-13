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

    func getRuntimeProvider(for chainId: ChainModel.Id) -> SSFRuntimeCodingService.RuntimeProviderProtocol? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        return chainRegistry.getRuntimeProvider(for: chainId)
    }

    private func getProvider(for key: String) -> StreamableProvider<AccountInfoStorageWrapper> {
        // Local minimal in-file stubs to avoid target-membership issues
        final class TestEmptyRepository<T: Identifiable>: DataProviderRepositoryProtocol {
            typealias Model = T
            func fetchOperation(by modelIdsClosure: @escaping () throws -> [String], options: RepositoryFetchOptions) -> BaseOperation<[T]> { ClosureOperation { [] } }
            func fetchOperation(by modelIdClosure: @escaping () throws -> String, options: RepositoryFetchOptions) -> BaseOperation<T?> { ClosureOperation { nil } }
            func fetchAllOperation(with options: RepositoryFetchOptions) -> BaseOperation<[T]> { ClosureOperation { [] } }
            func fetchOperation(by request: RepositorySliceRequest, options: RepositoryFetchOptions) -> BaseOperation<[T]> { ClosureOperation { [] } }
            func saveOperation(_ updateModelsBlock: @escaping () throws -> [T], _ deleteIdsBlock: @escaping () throws -> [String]) -> BaseOperation<Void> { ClosureOperation { () } }
            func saveBatchOperation(_ updateModelsBlock: @escaping () throws -> [T], _ deleteIdsBlock: @escaping () throws -> [String]) -> BaseOperation<Void> { ClosureOperation { () } }
            func replaceOperation(_ newModelsBlock: @escaping () throws -> [T]) -> BaseOperation<Void> { ClosureOperation { () } }
            func fetchCountOperation() -> BaseOperation<Int> { ClosureOperation { 0 } }
            func deleteAllOperation() -> BaseOperation<Void> { ClosureOperation { () } }
        }

        final class TestRepositoryObservable<T>: DataProviderRepositoryObservable {
            typealias Model = T
            func start(completionBlock: @escaping (Error?) -> Void) { completionBlock(nil) }
            func stop(completionBlock: @escaping (Error?) -> Void) { completionBlock(nil) }
            func addObserver(_ observer: AnyObject, deliverOn queue: DispatchQueue, executing updateBlock: @escaping ([DataProviderChange<T>]) -> Void) {}
            func removeObserver(_ observer: AnyObject) {}
        }

        let source = EmptyStreamableSource<AccountInfoStorageWrapper>()
        let repository = TestEmptyRepository<AccountInfoStorageWrapper>()
        let observable = TestRepositoryObservable<AccountInfoStorageWrapper>()

        return StreamableProvider(
            source: AnyStreamableSource(source),
            repository: AnyDataProviderRepository(repository),
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: operationManager,
            serialQueue: processingQueue
        )
    }
}
