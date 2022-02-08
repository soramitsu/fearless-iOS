import UIKit
import RobinHood

final class NodeSelectionInteractor {
    weak var presenter: NodeSelectionInteractorOutputProtocol?

    var chain: ChainModel
    let repository: AnyDataProviderRepository<ChainModel>
    let operationManager: OperationManagerProtocol
    let eventCenter: EventCenterProtocol

    init(
        chain: ChainModel,
        repository: AnyDataProviderRepository<ChainModel>,
        operationManager: OperationManagerProtocol,
        eventCenter: EventCenterProtocol
    ) {
        self.chain = chain
        self.repository = repository
        self.operationManager = operationManager
        self.eventCenter = eventCenter
    }
}

extension NodeSelectionInteractor: NodeSelectionInteractorInputProtocol {
    func setup() {
        presenter?.didReceive(chain: chain)
    }

    func selectNode(_ node: ChainNodeModel?) {
        let saveOperation = repository.saveOperation { [weak self] in
            guard let self = self else {
                return []
            }
            let updatedChain = self.chain.replacingSelectedNode(node)
            return [updatedChain]
        } _: {
            []
        }

        saveOperation.completionBlock = { [weak self] in
            guard let self = self else { return }
            self.chain = self.chain.replacingSelectedNode(node)

            DispatchQueue.main.async {
                self.presenter?.didReceive(chain: self.chain)
            }

            let event = ChainsUpdatedEvent(updatedChains: [self.chain])
            self.eventCenter.notify(with: event)
        }

        operationManager.enqueue(operations: [saveOperation], in: .transient)
    }

    func setAutomaticSwitchNodes(_ automatic: Bool) {
        if automatic {
            selectNode(nil)
        } else {
            selectNode(chain.nodes.first)
        }
    }
}
