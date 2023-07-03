import UIKit
import RobinHood
import SSFModels

final class AddCustomNodeInteractor {
    weak var presenter: AddCustomNodeInteractorOutputProtocol?
    var chain: ChainModel
    private let repository: AnyDataProviderRepository<ChainModel>
    private let nodeRepository: AnyDataProviderRepository<ChainNodeModel>
    private let operationManager: OperationManagerProtocol
    private let eventCenter: EventCenterProtocol
    private let substrateOperationFactory: SubstrateOperationFactoryProtocol

    init(
        chain: ChainModel,
        repository: AnyDataProviderRepository<ChainModel>,
        nodeRepository: AnyDataProviderRepository<ChainNodeModel>,
        operationManager: OperationManagerProtocol,
        eventCenter: EventCenterProtocol,
        substrateOperationFactory: SubstrateOperationFactoryProtocol
    ) {
        self.chain = chain
        self.repository = repository
        self.nodeRepository = nodeRepository
        self.operationManager = operationManager
        self.eventCenter = eventCenter
        self.substrateOperationFactory = substrateOperationFactory
    }
}

extension AddCustomNodeInteractor: AddCustomNodeInteractorInputProtocol {
    func addConnection(url: URL, name: String) {
        presenter?.didStartAdding(url: url)

        let node = ChainNodeModel(url: url, name: name, apikey: nil)

        var updatedNodes: [ChainNodeModel]
        if let customNodes = chain.customNodes {
            updatedNodes = Array(customNodes)
        } else {
            updatedNodes = []
        }
        updatedNodes.append(node)

        let updatedChain = chain.replacingCustomNodes(updatedNodes)

        let fetchNetworkOperation = substrateOperationFactory.fetchChainOperation(url)
        let fetchNodeOperation = nodeRepository.fetchOperation(
            by: url.absoluteString,
            options: RepositoryFetchOptions()
        )

        let saveOperation = repository.saveOperation {
            guard try fetchNodeOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled) == nil
            else {
                throw AddConnectionError.alreadyExists
            }

            guard case .success = fetchNetworkOperation.result else {
                throw AddConnectionError.invalidConnection
            }

            return [updatedChain]
        } _: {
            []
        }

        saveOperation.completionBlock = { [weak self] in
            guard let self = self else { return }

            DispatchQueue.main.async {
                switch saveOperation.result {
                case .success:
                    self.chain = updatedChain

                    let event = ChainsUpdatedEvent(updatedChains: [updatedChain])
                    self.eventCenter.notify(with: event)

                    self.presenter?.didCompleteAdding(url: url)
                case let .failure(error):
                    self.presenter?.didReceiveError(error: error, for: url)
                case .none:
                    self.presenter?.didReceiveError(error: BaseOperationError.parentOperationCancelled, for: url)
                }
            }
        }

        saveOperation.addDependency(fetchNetworkOperation)

        operationManager.enqueue(operations: [fetchNodeOperation, fetchNetworkOperation, saveOperation], in: .transient)
    }
}
