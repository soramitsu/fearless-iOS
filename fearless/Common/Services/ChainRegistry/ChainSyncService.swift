import Foundation
import RobinHood

protocol ChainSyncServiceProtocol {
    func syncUp()
}

final class ChainSyncService {
    let url: URL
    let repository: AnyDataProviderRepository<ChainModel>
    let dataFetchFactory: DataOperationFactoryProtocol
    let operationQueue: OperationQueue

    init(
        url: URL,
        dataFetchFactory: DataOperationFactoryProtocol,
        repository: AnyDataProviderRepository<ChainModel>,
        operationQueue: OperationQueue
    ) {
        self.url = url
        self.dataFetchFactory = dataFetchFactory
        self.repository = repository
        self.operationQueue = operationQueue
    }
}

extension ChainSyncService: ChainSyncServiceProtocol {
    func syncUp() {
        let remoteFetchOperation = dataFetchFactory.fetchData(from: url)
        let localFetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        let processingOperation: BaseOperation<([ChainModel], [ChainModel])> = ClosureOperation {
            let remoteData = try remoteFetchOperation.extractNoCancellableResultData()
            let remoteChains = try JSONDecoder().decode([ChainModel].self, from: remoteData)

            let remoteMapping = remoteChains.reduce(into: [ChainModel.Id: ChainModel]()) { mapping, item in
                mapping[item.chainId] = item
            }

            let localChains = try localFetchOperation.extractNoCancellableResultData()
            let localMapping = localChains.reduce(into: [ChainModel.Id: ChainModel]()) { mapping, item in
                mapping[item.chainId] = item
            }

            let updateOrNewItems: [ChainModel] = remoteChains.compactMap { remoteItem in
                if let localItem = localMapping[remoteItem.chainId] {
                    return localItem != remoteItem ? remoteItem : nil
                } else {
                    return remoteItem
                }
            }

            let removedItems = localChains.compactMap { localItem in
                remoteMapping[localItem.chainId] == nil ? localItem : nil
            }

            return (updateOrNewItems, removedItems)
        }

        processingOperation.addDependency(remoteFetchOperation)
        processingOperation.addDependency(localFetchOperation)

        let localSaveOperation = repository.saveOperation({
            let (newOrUpdatedItems, _) = try processingOperation.extractNoCancellableResultData()
            return newOrUpdatedItems
        }, {
            let (_, removedItems) = try processingOperation.extractNoCancellableResultData()
            return removedItems.map(\.identifier)
        })

        localSaveOperation.addDependency(processingOperation)

        operationQueue.addOperations([
            remoteFetchOperation, localFetchOperation, processingOperation, localSaveOperation
        ], waitUntilFinished: false)
    }
}
