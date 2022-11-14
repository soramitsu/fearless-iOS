import Foundation
import SoraKeystore
import RobinHood

final class CrowdloanChainSettings: PersistentValueSettings<ChainModel> {
    let settings: SettingsManagerProtocol
    let operationQueue: OperationQueue
    var onUpdate: (() -> Void)?

    init(
        storageFacade: StorageFacadeProtocol,
        settings: SettingsManagerProtocol,
        operationQueue: OperationQueue,
        eventCenter: EventCenterProtocol
    ) {
        self.settings = settings
        self.operationQueue = operationQueue

        super.init(storageFacade: storageFacade)

        eventCenter.add(observer: self)
    }

    override func performSetup(completionClosure: @escaping (Result<ChainModel?, Error>) -> Void) {
        let maybeChainId = settings.crowdloanChainId

        let filter: NSPredicate = {
            if let chainId = maybeChainId {
                return NSCompoundPredicate(orPredicateWithSubpredicates: [
                    NSPredicate.chainBy(identifier: chainId),
                    NSPredicate.relayChains()
                ])

            } else {
                return NSPredicate.relayChains()
            }
        }()

        let factory = ChainRepositoryFactory(storageFacade: storageFacade)
        let repository = AnyDataProviderRepository(factory.createRepository(for: filter))

        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        let mappingOperation = ClosureOperation<ChainModel?> {
            let chains = try fetchOperation.extractNoCancellableResultData()

            if let selectedChain = chains.first(where: { $0.chainId == maybeChainId }) {
                return selectedChain
            }

            if let firstRelayChain = chains.first(where: { $0.hasCrowdloans }) {
                self.settings.crowdloanChainId = firstRelayChain.chainId
                return firstRelayChain
            }

            return nil
        }

        mappingOperation.addDependency(fetchOperation)

        mappingOperation.completionBlock = {
            do {
                let result = try mappingOperation.extractNoCancellableResultData()
                completionClosure(.success(result))
            } catch {
                completionClosure(.failure(error))
            }
        }

        operationQueue.addOperations([fetchOperation, mappingOperation], waitUntilFinished: false)
    }

    override func performSave(
        value: ChainModel,
        completionClosure: @escaping (Result<ChainModel, Error>
        ) -> Void
    ) {
        settings.crowdloanChainId = value.chainId
        completionClosure(.success(value))
    }
}

extension CrowdloanChainSettings: EventVisitorProtocol {
    func processChainSyncDidComplete(event: ChainSyncDidComplete) {
        guard let updatedChain = event.newOrUpdatedChains.first(where: { $0.chainId == value?.chainId }) else {
            return
        }

        performSave(value: updatedChain) { [weak self] _ in
            self?.onUpdate?()
        }
    }
}
