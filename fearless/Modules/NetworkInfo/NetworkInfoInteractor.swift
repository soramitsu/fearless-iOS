import UIKit
import RobinHood
import SoraKeystore
import IrohaCrypto

final class NetworkInfoInteractor {
    weak var presenter: NetworkInfoInteractorOutputProtocol!

    let repository: AnyDataProviderRepository<ManagedConnectionItem>
    let substrateOperationFactory: SubstrateOperationFactoryProtocol
    let operationManager: OperationManagerProtocol
    private(set) var settingsManager: SettingsManagerProtocol
    let eventCenter: EventCenterProtocol

    init(repository: AnyDataProviderRepository<ManagedConnectionItem>,
         substrateOperationFactory: SubstrateOperationFactoryProtocol,
         settingsManager: SettingsManagerProtocol,
         operationManager: OperationManagerProtocol,
         eventCenter: EventCenterProtocol) {
        self.repository = repository
        self.substrateOperationFactory = substrateOperationFactory
        self.settingsManager = settingsManager
        self.operationManager = operationManager
        self.eventCenter = eventCenter
    }

    private func handleUpdate(result: Result<Void, Error>?,
                              oldItem: ConnectionItem,
                              newUrl: URL,
                              newName: String) {
        switch result {
        case .success:
            if settingsManager.selectedConnection.identifier == oldItem.identifier {
                let selectedConnection = settingsManager.selectedConnection.replacingTitle(newName)
                settingsManager.selectedConnection = selectedConnection

                eventCenter.notify(with: SelectedConnectionChanged())
            }

            presenter.didCompleteConnectionUpdate(with: newUrl)
        case .failure(let error):
            presenter.didReceive(error: error, for: newUrl)
        case .none:
            presenter.didReceive(error: BaseOperationError.parentOperationCancelled,
                                 for: newUrl)
        }
    }

    private func createSaveOperationDependingOn(fetchOldItemOperation: BaseOperation<ManagedConnectionItem?>,
                                                fetchNewItemOperation: BaseOperation<ManagedConnectionItem?>,
                                                networkTypeOperation: BaseOperation<String>,
                                                newName: String,
                                                newURL: URL) -> BaseOperation<Void> {
        let saveOperation = repository.saveOperation({
            guard let oldManagedItem = try fetchOldItemOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled) else {
                return []
            }

            if let newItem = try fetchNewItemOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled),
                newItem.identifier != oldManagedItem.identifier {
                throw AddConnectionError.alreadyExists
            }

            guard case .success(let rawType) = networkTypeOperation.result else {
                throw AddConnectionError.invalidConnection
            }

            guard let chain = Chain(rawValue: rawType) else {
                throw AddConnectionError.unsupportedChain(SNAddressType.supported)
            }

            let newManagedItem = ManagedConnectionItem(title: newName,
                                                       url: newURL,
                                                       type: SNAddressType(chain: chain),
                                                       order: oldManagedItem.order)

            return [newManagedItem]
        }, {
            guard
                let oldManagedItem = try fetchOldItemOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled),
                oldManagedItem.url != newURL else {
                return []
            }

            if let newItem = try fetchNewItemOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled),
                newItem.identifier != oldManagedItem.identifier {
                throw AddConnectionError.alreadyExists
            }

            return [oldManagedItem.identifier]
        })

        saveOperation.addDependency(fetchOldItemOperation)
        saveOperation.addDependency(fetchNewItemOperation)
        saveOperation.addDependency(networkTypeOperation)

        return saveOperation
    }
}

extension NetworkInfoInteractor: NetworkInfoInteractorInputProtocol {
    func updateConnection(_ oldConnection: ConnectionItem, newURL: URL, newName: String) {
        guard oldConnection.url != newURL || oldConnection.title != newName else {
            presenter.didCompleteConnectionUpdate(with: newURL)
            return
        }

        guard ConnectionItem.supportedConnections.first(where: { $0.url == newURL }) == nil else {
            presenter.didReceive(error: AddConnectionError.alreadyExists, for: newURL)
            return
        }

        presenter.didStartConnectionUpdate(with: newURL)

        let fetchOldItemOperation = repository.fetchOperation(by: oldConnection.identifier,
                                                           options: RepositoryFetchOptions())
        let networkTypeOperation = substrateOperationFactory.fetchChainOperation(newURL)

        let fetchNewItemOperation = repository.fetchOperation(by: newURL.absoluteString,
                                                              options: RepositoryFetchOptions())

        let saveOperation = createSaveOperationDependingOn(fetchOldItemOperation: fetchOldItemOperation,
                                                           fetchNewItemOperation: fetchNewItemOperation,
                                                           networkTypeOperation: networkTypeOperation,
                                                           newName: newName,
                                                           newURL: newURL)

        saveOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                self?.handleUpdate(result: saveOperation.result,
                                   oldItem: oldConnection,
                                   newUrl: newURL,
                                   newName: newName)
            }
        }

        let operations = [fetchOldItemOperation, fetchNewItemOperation, networkTypeOperation, saveOperation]
        operationManager.enqueue(operations: operations, in: .transient)
    }
}
