import UIKit
import RobinHood
import SSFModels

final class NodeSelectionInteractor {
    weak var presenter: NodeSelectionInteractorOutputProtocol?

    var chain: ChainModel
    let repository: AnyDataProviderRepository<ChainModel>
    let operationManager: OperationManagerProtocol
    let eventCenter: EventCenterProtocol
    private let chainRegistry: ChainRegistryProtocol

    init(
        chain: ChainModel,
        repository: AnyDataProviderRepository<ChainModel>,
        operationManager: OperationManagerProtocol,
        eventCenter: EventCenterProtocol,
        chainRegistry: ChainRegistryProtocol
    ) {
        self.chain = chain
        self.repository = repository
        self.operationManager = operationManager
        self.eventCenter = eventCenter
        self.chainRegistry = chainRegistry
    }

    private func fetchChainModel() {
        let operation = repository.fetchOperation(by: chain.chainId, options: RepositoryFetchOptions())

        operation.completionBlock = { [weak self] in
            guard let chainModel = try? operation.extractNoCancellableResultData() else {
                return
            }
            self?.chain = chainModel
            DispatchQueue.main.async {
                self?.presenter?.didReceive(chain: chainModel)
            }
        }

        operationManager.enqueue(operations: [operation], in: .transient)
    }
}

extension NodeSelectionInteractor: NodeSelectionInteractorInputProtocol {
    func setup() {
        presenter?.didReceive(chain: chain)
        fetchChainModel()
        eventCenter.add(observer: self)
    }

    func deleteNode(_ node: ChainNodeModel) {
        guard let customNodes = chain.customNodes else {
            return
        }

        let updatedChain = chain.replacingCustomNodes(customNodes.filter { $0 != node })

        let saveOperation = repository.saveOperation {
            [updatedChain]
        } _: {
            []
        }

        saveOperation.completionBlock = { [weak self] in
            guard let self = self else { return }

            self.chain = updatedChain

            DispatchQueue.main.async {
                self.presenter?.didReceive(chain: updatedChain)
            }

            let event = ChainsUpdatedEvent(updatedChains: [updatedChain])
            self.eventCenter.notify(with: event)
        }

        operationManager.enqueue(operations: [saveOperation], in: .transient)
    }

    func selectNode(_ node: ChainNodeModel?) {
        chainRegistry.resetConnection(for: chain.chainId)

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
            let updatedChain = self.chain.replacingSelectedNode(node)

            self.chain = updatedChain

            DispatchQueue.main.async {
                self.presenter?.didReceive(chain: updatedChain)
            }

            let event = ChainsUpdatedEvent(updatedChains: [updatedChain])
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

extension NodeSelectionInteractor: EventVisitorProtocol {
    func processChainsUpdated(event: ChainsUpdatedEvent) {
        if let updated = event.updatedChains.first(where: { [weak self] updatedChain in
            guard let self = self else { return false }
            return updatedChain.chainId == self.chain.chainId
        }) {
            chain = updated

            DispatchQueue.main.async {
                self.presenter?.didReceive(chain: self.chain)
            }
        }
    }
}
