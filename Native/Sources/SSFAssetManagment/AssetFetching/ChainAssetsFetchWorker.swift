import Foundation
import RobinHood
import SSFModels
import SSFUtils

// sourcery: AutoMockable
protocol ChainAssetsFetchWorkerProtocol {
    func getChainAssetsModels() async -> [ChainAsset]
}

final class ChainAssetsFetchWorker: ChainAssetsFetchWorkerProtocol {
    private let chainRepository: AnyDataProviderRepository<ChainModel>
    private let operationManager: OperationManagerProtocol

    init(
        chainRepository: AnyDataProviderRepository<ChainModel>,
        operationManager: OperationManagerProtocol = OperationManagerFacade.sharedManager
    ) {
        self.chainRepository = chainRepository
        self.operationManager = operationManager
    }

    func getChainAssetsModels() async -> [ChainAsset] {
        let operation = chainRepository.fetchAllOperation(with: .none)
        operationManager.enqueue(operations: [operation], in: .transient)

        return await withUnsafeContinuation { continuation in
            operation.completionBlock = {
                switch operation.result {
                case let .success(chains):
                    let chainAssets = chains.map(\.chainAssets).reduce([], +)
                    continuation.resume(returning: chainAssets)

                case .failure, .none:
                    continuation.resume(returning: [])
                }
            }
        }
    }
}
