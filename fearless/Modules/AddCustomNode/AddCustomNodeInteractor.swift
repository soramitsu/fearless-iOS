import UIKit
import RobinHood

final class AddCustomNodeInteractor {
    weak var presenter: AddCustomNodeInteractorOutputProtocol?
    var chain: ChainModel
    private let repository: AnyDataProviderRepository<ChainModel>
    private let operationManager: OperationManagerProtocol
    private let eventCenter: EventCenterProtocol
    private let substrateOperationFactory: SubstrateOperationFactoryProtocol

    init(
        chain: ChainModel,
        repository: AnyDataProviderRepository<ChainModel>,
        operationManager: OperationManagerProtocol,
        eventCenter: EventCenterProtocol,
        substrateOperationFactory: SubstrateOperationFactoryProtocol
    ) {
        self.chain = chain
        self.repository = repository
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

        let saveOperation = repository.saveOperation {
            guard case .success = fetchNetworkOperation.result else {
                self.presenter?.didReceiveError(error: AddConnectionError.invalidConnection, for: url)
                return []
            }

            return [updatedChain]
        } _: {
            []
        }

        saveOperation.completionBlock = { [weak self] in
            guard let self = self else { return }
            self.chain = updatedChain

            DispatchQueue.main.async {
                let event = ChainsUpdatedEvent(updatedChains: [updatedChain])
                self.eventCenter.notify(with: event)

                self.presenter?.didCompleteAdding(url: url)
            }
        }

        saveOperation.addDependency(fetchNetworkOperation)

        operationManager.enqueue(operations: [fetchNetworkOperation, saveOperation], in: .transient)
    }
}
