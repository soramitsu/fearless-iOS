import UIKit
import RobinHood
import SoraKeystore

final class AccountManagementInteractor {
    weak var presenter: AccountManagementInteractorOutputProtocol?

    let repositoryObservable: AnyDataProviderRepositoryObservable<ManagedAccountItem>
    let repository: AnyDataProviderRepository<ManagedAccountItem>
    private(set) var settings: SettingsManagerProtocol
    let operationManager: OperationManagerProtocol
    let eventCenter: EventCenterProtocol

    init(repository: AnyDataProviderRepository<ManagedAccountItem>,
         repositoryObservable: AnyDataProviderRepositoryObservable<ManagedAccountItem>,
         settings: SettingsManagerProtocol,
         operationManager: OperationManagerProtocol,
         eventCenter: EventCenterProtocol) {
        self.repository = repository
        self.repositoryObservable = repositoryObservable
        self.settings = settings
        self.operationManager = operationManager
        self.eventCenter = eventCenter
    }

    private func provideInitialList() {
        let options = RepositoryFetchOptions()
        let operation = repository.fetchAllOperation(with: options)

        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let items = try operation
                        .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                    let changes = items.map { DataProviderChange.insert(newItem: $0) }

                    self?.presenter?.didReceive(changes: changes)
                } catch {
                    self?.presenter?.didReceive(error: error)
                }
            }
        }

        operationManager.enqueue(operations: [operation], in: .sync)
    }
}

extension AccountManagementInteractor: AccountManagementInteractorInputProtocol {
    func setup() {
        repositoryObservable.start { [weak self] error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.presenter?.didReceive(error: error)
                }
            }
        }

        repositoryObservable.addObserver(self, deliverOn: .main) { [weak self] changes in
            self?.presenter?.didReceive(changes: changes)
        }

        if let selectedAccountItem = settings.selectedAccount {
            presenter?.didReceiveSelected(item: selectedAccountItem)
        }

        provideInitialList()
    }

    func select(item: ManagedAccountItem) {
        if item.networkType != settings.selectedConnection.type {
            guard let newConnection = ConnectionItem
                .supportedConnections.first(where: { $0.type == item.networkType }) else {
                return
            }

            settings.selectedConnection = newConnection
        }

        let newSelectedAccountItem = AccountItem(address: item.address,
                                             cryptoType: item.cryptoType,
                                             username: item.username,
                                             publicKeyData: item.publicKeyData)

        settings.selectedAccount = newSelectedAccountItem
        presenter?.didReceiveSelected(item: newSelectedAccountItem)

        eventCenter.notify(with: SelectedAccountChanged())
    }

    func save(items: [ManagedAccountItem]) {
        let operation = repository.saveOperation({ items }, { [] })
        operationManager.enqueue(operations: [operation], in: .sync)
    }

    func remove(item: ManagedAccountItem) {
        let operation = repository.saveOperation({ [] }, { [item.address] })
        operationManager.enqueue(operations: [operation], in: .sync)
    }
}
