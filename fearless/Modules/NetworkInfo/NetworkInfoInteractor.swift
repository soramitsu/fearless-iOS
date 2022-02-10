import UIKit
import RobinHood
import SoraKeystore
import IrohaCrypto

final class NetworkInfoInteractor {
    weak var presenter: NetworkInfoInteractorOutputProtocol!

    private(set) var chain: ChainModel
    let repository: AnyDataProviderRepository<ChainModel>
    let substrateOperationFactory: SubstrateOperationFactoryProtocol
    let operationManager: OperationManagerProtocol
    let eventCenter: EventCenterProtocol

    init(
        chain: ChainModel,
        repository: AnyDataProviderRepository<ChainModel>,
        substrateOperationFactory: SubstrateOperationFactoryProtocol,
        operationManager: OperationManagerProtocol,
        eventCenter: EventCenterProtocol
    ) {
        self.chain = chain
        self.repository = repository
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

        let updatedNode = ChainNodeModel(url: newURL, name: newName, apikey: nil)

        var updatedNodes: [ChainNodeModel]
        if let customNodes = chain.customNodes {
            updatedNodes = Array(customNodes)
        } else {
            updatedNodes = []
        }
        updatedNodes = updatedNodes.filter { $0.url != node.url }
        updatedNodes.append(updatedNode)

        let updatedChain = chain.replacingCustomNodes(updatedNodes)

        let fetchNetworkOperation = substrateOperationFactory.fetchChainOperation(newURL)

        let saveOperation = repository.saveOperation {
            guard case .success = fetchNetworkOperation.result else {
                self.presenter?.didReceive(error: AddConnectionError.invalidConnection, for: newURL)
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

                self.presenter.didCompleteConnectionUpdate(with: newURL)
            }
        }

        saveOperation.addDependency(fetchNetworkOperation)

        operationManager.enqueue(operations: [fetchNetworkOperation, saveOperation], in: .transient)
    }
}
