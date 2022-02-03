import UIKit
import RobinHood

final class NodeSelectionInteractor {
    weak var presenter: NodeSelectionInteractorOutputProtocol?

    let chain: ChainModel
    let repository: AnyDataProviderRepository<ChainModel>
    let operationManager: OperationManagerProtocol

    init(
        chain: ChainModel,
        repository: AnyDataProviderRepository<ChainModel>,
        operationManager: OperationManagerProtocol
    ) {
        self.chain = chain
        self.repository = repository
        self.operationManager = operationManager
    }
}

extension NodeSelectionInteractor: NodeSelectionInteractorInputProtocol {
    func setup() {
        presenter?.didReceive(chain: chain)
    }

    func selectNode(_ node: ChainNodeModel) {
        let saveOperation = repository.saveOperation { [weak self] in
            guard let self = self else {
                return []
            }
            let updatedChain = self.chain.replacingSelectedNode(node)
            return [updatedChain]
        } _: {
            []
        }

        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        let logOperation = ClosureOperation {
            let chains = try fetchOperation.extractNoCancellableResultData()
            print("chains: ", chains)
        }

        logOperation.addDependency(fetchOperation)
        fetchOperation.addDependency(saveOperation)

        operationManager.enqueue(operations: [saveOperation, fetchOperation, logOperation], in: .transient)
    }
}
