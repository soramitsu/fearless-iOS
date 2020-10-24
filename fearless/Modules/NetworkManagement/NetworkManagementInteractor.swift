import UIKit
import RobinHood
import SoraKeystore
import IrohaCrypto

final class NetworkManagementInteractor {
    weak var presenter: NetworkManagementInteractorOutputProtocol!

    let connectionsObservable: AnyDataProviderRepositoryObservable<ManagedConnectionItem>
    let connectionsRepository: AnyDataProviderRepository<ManagedConnectionItem>
    let accountsRepository: AnyDataProviderRepository<ManagedAccountItem>
    private(set) var settings: SettingsManagerProtocol
    let operationManager: OperationManagerProtocol
    let eventCenter: EventCenterProtocol

    init(connectionsRepository: AnyDataProviderRepository<ManagedConnectionItem>,
         connectionsObservable: AnyDataProviderRepositoryObservable<ManagedConnectionItem>,
         accountsRepository: AnyDataProviderRepository<ManagedAccountItem>,
         settings: SettingsManagerProtocol,
         operationManager: OperationManagerProtocol,
         eventCenter: EventCenterProtocol) {
        self.connectionsRepository = connectionsRepository
        self.connectionsObservable = connectionsObservable
        self.accountsRepository = accountsRepository
        self.settings = settings
        self.operationManager = operationManager
        self.eventCenter = eventCenter
    }

    private func provideDefaultConnections() {
        presenter.didReceiveDefaultConnections(ConnectionItem.supportedConnections)
    }

    private func provideCustomConnections() {
        let options = RepositoryFetchOptions()
        let operation = connectionsRepository.fetchAllOperation(with: options)

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

    private func select(connection: ConnectionItem,
                        for accountsFetchResult: Result<[ManagedAccountItem], Error>?) {
        guard let result = accountsFetchResult else {
            presenter.didReceiveConnection(selectionError: BaseOperationError.parentOperationCancelled)
            return
        }

        switch result {
        case .success(let accounts):
            let filteredAccounts: [AccountItem] = accounts.compactMap { managedAccount in
                if managedAccount.networkType == connection.type {
                    return AccountItem(managedItem: managedAccount)
                } else {
                    return nil
                }
            }

            if filteredAccounts.isEmpty {
                presenter.didFindNoAccounts(for: connection)
            } else if filteredAccounts.count > 1 {
                presenter.didFindMultiple(accounts: filteredAccounts, for: connection)
            } else if let account = filteredAccounts.first {
                select(connection: connection, account: account)
            }

        case .failure(let error):
            presenter.didReceiveConnection(selectionError: error)
        }
    }
}

extension NetworkManagementInteractor: NetworkManagementInteractorInputProtocol {
    func setup() {
        connectionsObservable.start { [weak self] error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.presenter.didReceiveCustomConnection(error: error)
                }
            }
        }

        connectionsObservable.addObserver(self, deliverOn: .main) { [weak self] changes in
            self?.presenter.didReceiveCustomConnection(changes: changes)
        }

        provideDefaultConnections()
        provideCustomConnections()
        provideSelectedItem()
    }

    func select(connection: ConnectionItem) {
        if settings.selectedConnection.type == connection.type {
            settings.selectedConnection = connection
            presenter.didReceiveSelectedConnection(connection)

            eventCenter.notify(with: SelectedConnectionChanged())
        } else {
            let fetchOperation = accountsRepository
                .fetchAllOperation(with: RepositoryFetchOptions())

            fetchOperation.completionBlock = { [weak self] in
                DispatchQueue.main.async {
                    self?.select(connection: connection, for: fetchOperation.result)
                }
            }

            operationManager.enqueue(operations: [fetchOperation], in: .sync)
        }
    }

    func select(connection: ConnectionItem, account: AccountItem) {
        settings.selectedAccount = account
        settings.selectedConnection = connection

        presenter.didReceiveSelectedConnection(connection)

        eventCenter.notify(with: SelectedConnectionChanged())
        eventCenter.notify(with: SelectedAccountChanged())
    }

    func save(items: [ManagedConnectionItem]) {
        let operation = connectionsRepository.saveOperation({ items }, { [] })
        operationManager.enqueue(operations: [operation], in: .sync)
    }

    func remove(item: ManagedConnectionItem) {
        let operation = connectionsRepository.saveOperation({ [] }, { [item.identifier] })
        operationManager.enqueue(operations: [operation], in: .sync)
    }
}
