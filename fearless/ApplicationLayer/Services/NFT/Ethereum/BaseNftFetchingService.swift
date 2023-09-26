import Foundation
import SSFModels
import RobinHood

class BaseNftFetchingService {
    let chainRepository: AnyDataProviderRepository<ChainModel>
    let operationQueue: OperationQueue

    init(
        chainRepository: AnyDataProviderRepository<ChainModel>,
        operationQueue: OperationQueue
    ) {
        self.chainRepository = chainRepository
        self.operationQueue = operationQueue
    }

    func fetchSupportedChains() async throws -> [ChainModel] {
        try await withCheckedThrowingContinuation { continuation in
            let fetchChainsOperation = chainRepository.fetchAllOperation(with: RepositoryFetchOptions())

            fetchChainsOperation.completionBlock = {
                do {
                    let chains = try fetchChainsOperation.extractNoCancellableResultData()
                    let filteredChains = chains.filter { $0.supportsNft }
                    return continuation.resume(with: .success(filteredChains))
                } catch {
                    return continuation.resume(with: .failure(error))
                }
            }

            operationQueue.addOperation(fetchChainsOperation)
        }
    }
}
