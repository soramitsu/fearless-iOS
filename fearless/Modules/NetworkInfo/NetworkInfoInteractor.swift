import UIKit
import RobinHood
import SoraKeystore
import IrohaCrypto
import SSFModels

final class NetworkInfoInteractor {
    weak var presenter: NetworkInfoInteractorOutputProtocol!

    private(set) var chain: ChainModel
    let nodeRepository: AnyDataProviderRepository<ChainNodeModel>
    let substrateOperationFactory: SubstrateOperationFactoryProtocol
    let operationManager: OperationManagerProtocol
    let eventCenter: EventCenterProtocol

    init(
        chain: ChainModel,
        nodeRepository: AnyDataProviderRepository<ChainNodeModel>,
        substrateOperationFactory: SubstrateOperationFactoryProtocol,
        operationManager: OperationManagerProtocol,
        eventCenter: EventCenterProtocol
    ) {
        self.chain = chain
        self.nodeRepository = nodeRepository
        self.substrateOperationFactory = substrateOperationFactory
        self.operationManager = operationManager
        self.eventCenter = eventCenter
    }
}

extension NetworkInfoInteractor: NetworkInfoInteractorInputProtocol {
    func updateNode(_ node: ChainNodeModel, newURL: URL, newName: String) {
        guard node.url != newURL || node.name != newName else {
            presenter.didCompleteConnectionUpdate(with: newURL)
            return
        }

        presenter.didStartConnectionUpdate(with: newURL)

        let updatedNode = ChainNodeModel(
            url: newURL,
            name: newName,
            apikey: nil
        )

        var updatedNodes: [ChainNodeModel]
        if let customNodes = chain.customNodes {
            updatedNodes = Array(customNodes)
        } else {
            updatedNodes = []
        }
        updatedNodes = updatedNodes.filter { $0 != node }
        updatedNodes.append(updatedNode)

        chain = chain.replacingCustomNodes(updatedNodes)

        if chain.selectedNode == node {
            chain = chain.replacingSelectedNode(updatedNode)
        }

        let fetchNetworkOperation = substrateOperationFactory.fetchChainOperation(newURL)

        let nodeSaveOperation = nodeRepository.saveOperation {
            guard case .success = fetchNetworkOperation.result else {
                throw AddConnectionError.invalidConnection
            }
            return [updatedNode]
        } _: {
            []
        }

        nodeSaveOperation.completionBlock = { [weak self] in
            guard let self = self else { return }

            DispatchQueue.main.async {
                switch nodeSaveOperation.result {
                case .success:
                    let event = ChainsUpdatedEvent(updatedChains: [self.chain])
                    self.eventCenter.notify(with: event)
                    self.presenter.didCompleteConnectionUpdate(with: newURL)
                case let .failure(error):
                    self.presenter.didReceive(error: error, for: newURL)
                case .none:
                    self.presenter.didReceive(error: BaseOperationError.parentOperationCancelled, for: newURL)
                }
            }
        }

        nodeSaveOperation.addDependency(fetchNetworkOperation)
        operationManager.enqueue(operations: [fetchNetworkOperation, nodeSaveOperation], in: .transient)
    }
}
