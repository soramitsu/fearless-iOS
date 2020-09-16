import UIKit
import RobinHood
import SoraKeystore

final class NetworkManagementInteractor {
    weak var presenter: NetworkManagementInteractorOutputProtocol!

    let repositoryObservable: AnyDataProviderRepositoryObservable<ManagedConnectionItem>
    let repository: AnyDataProviderRepository<ManagedConnectionItem>
    private(set) var settings: SettingsManagerProtocol
    let operationManager: OperationManagerProtocol
    let eventCenter: EventCenterProtocol

    init(repository: AnyDataProviderRepository<ManagedConnectionItem>,
         repositoryObservable: AnyDataProviderRepositoryObservable<ManagedConnectionItem>,
         settings: SettingsManagerProtocol,
         operationManager: OperationManagerProtocol,
         eventCenter: EventCenterProtocol) {
        self.repository = repository
        self.repositoryObservable = repositoryObservable
        self.settings = settings
        self.operationManager = operationManager
        self.eventCenter = eventCenter
    }

    private func provideDefaultConnections() {
        presenter.didReceiveDefaultConnections(ConnectionItem.supportedConnections)
    }

    private func provideCustomConnections() {
        let options = RepositoryFetchOptions()
        let operation = repository.fetchAllOperation(with: options)

        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let items = try operation
                        .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                    let changes = items.map { DataProviderChange.insert(newItem: $0) }

                    self?.presenter.didReceiveCustomConnection(changes: changes)
                } catch {
                    self?.presenter.didReceiveCustomConnection(error: error)
                }
            }
        }

        operationManager.enqueue(operations: [operation], in: .sync)
    }

    private func provideSelectedItem() {
        presenter.didReceiveSelectedConnection(settings.selectedConnection)
    }
}

extension NetworkManagementInteractor: NetworkManagementInteractorInputProtocol {
    func setup() {
        provideDefaultConnections()
        provideCustomConnections()
        provideSelectedItem()
    }
}
