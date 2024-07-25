import UIKit
import RobinHood
import SSFModels

final class NodeSelectionInteractor {
    weak var presenter: NodeSelectionInteractorOutputProtocol?

    internal var chain: ChainModel
    private let repository: AsyncAnyRepository<ChainModel>
    private let eventCenter: EventCenterProtocol
    private let chainRegistry: ChainRegistryProtocol

    init(
        chain: ChainModel,
        repository: AsyncAnyRepository<ChainModel>,
        eventCenter: EventCenterProtocol,
        chainRegistry: ChainRegistryProtocol
    ) {
        self.chain = chain
        self.repository = repository
        self.eventCenter = eventCenter
        self.chainRegistry = chainRegistry
    }

    private func applyChanges(for chain: ChainModel) async {
        self.chain = chain

        let event = ChainsUpdatedEvent(updatedChains: [chain])
        eventCenter.notify(with: event)
    }
}

extension NodeSelectionInteractor: NodeSelectionInteractorInputProtocol {
    func setup() {
        presenter?.didReceive(chain: chain)
        eventCenter.add(observer: self)
    }

    func deleteNode(_ node: ChainNodeModel) {
        Task {
            guard let customNodes = chain.customNodes else {
                return
            }

            let updatedChain = chain.replacingCustomNodes(customNodes.filter { $0 != node })
            await repository.save(models: [updatedChain])
            await applyChanges(for: updatedChain)
        }
    }

    func selectNode(_ node: ChainNodeModel?) {
        chainRegistry.resetConnection(for: chain.chainId)

        Task {
            let updatedChain = self.chain.replacingSelectedNode(node)
            await repository.save(models: [updatedChain])
            await applyChanges(for: updatedChain)
        }
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
