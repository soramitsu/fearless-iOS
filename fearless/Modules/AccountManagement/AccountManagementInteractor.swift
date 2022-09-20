import UIKit
import RobinHood
import SoraKeystore

final class AccountManagementInteractor {
    weak var presenter: AccountManagementInteractorOutputProtocol?

    let repositoryObservable: AnyDataProviderRepositoryObservable<ManagedMetaAccountModel>
    let repository: AnyDataProviderRepository<ManagedMetaAccountModel>
    let settings: SelectedWalletSettings
    let operationQueue: OperationQueue
    let eventCenter: EventCenterProtocol
    let getBalanceProvider: GetBalanceProviderProtocol

    init(
        repository: AnyDataProviderRepository<ManagedMetaAccountModel>,
        repositoryObservable: AnyDataProviderRepositoryObservable<ManagedMetaAccountModel>,
        settings: SelectedWalletSettings,
        operationQueue: OperationQueue,
        eventCenter: EventCenterProtocol,
        getBalanceProvider: GetBalanceProviderProtocol
    ) {
        self.repository = repository
        self.repositoryObservable = repositoryObservable
        self.settings = settings
        self.operationQueue = operationQueue
        self.eventCenter = eventCenter
        self.getBalanceProvider = getBalanceProvider
    }

    private func provideInitialList() {
        let options = RepositoryFetchOptions()
        let operation = repository.fetchAllOperation(with: options)

        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let items = try operation
                        .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                    self?.getBalances(for: items)
                    let changes = items.map { DataProviderChange.insert(newItem: $0) }
                    self?.presenter?.didReceive(changes: changes)
                } catch {
                    self?.presenter?.didReceive(error: error)
                }
            }
        }

        operationQueue.addOperation(operation)
    }

    private func getBalances(for items: [ManagedMetaAccountModel]) {
        getBalanceProvider.getBalances(for: items, handler: self)
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
            guard let strongSelf = self else { return }
            strongSelf.presenter?.didReceive(changes: changes)
            let accounts = changes.compactMap(\.item)
            strongSelf.getBalances(for: accounts)
        }

        provideInitialList()

        eventCenter.add(observer: self)
    }

    func select(item: ManagedMetaAccountModel) {
        let oldMetaAccount = settings.value

        guard item.info.identifier != oldMetaAccount?.identifier else {
            return
        }

        settings.save(value: item.info, runningCompletionIn: .main) { [weak self] result in
            switch result {
            case .success:
                self?.eventCenter.notify(with: SelectedAccountChanged())

                self?.presenter?.didCompleteSelection(of: item.info)
            case let .failure(error):
                self?.presenter?.didReceive(error: error)
            }
        }
    }

    func save(items: [ManagedMetaAccountModel]) {
        let operation = repository.saveOperation({ items }, { [] })
        operationQueue.addOperation(operation)
    }

    func remove(item: ManagedMetaAccountModel) {
        let operation = repository.saveOperation({ [] }, { [item.identifier] })
        operationQueue.addOperation(operation)
    }

    func update(item: ManagedMetaAccountModel) {
        let operation = repository.saveOperation({ [item] }, { [] })
        operationQueue.addOperation(operation)
    }
}

extension AccountManagementInteractor: EventVisitorProtocol {
    func processWalletNameChanged(event: WalletNameChanged) {
        let operation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        operation.completionBlock = { [weak self] in
            let items = try? operation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            if let changedItem = items?.first(where: { $0.info.metaId == event.wallet.metaId }) {
                let newItem = ManagedMetaAccountModel(
                    info: event.wallet,
                    isSelected: changedItem.isSelected,
                    order: changedItem.order
                )
                self?.update(item: newItem)
            }
        }
        operationQueue.addOperation(operation)
    }
}

extension AccountManagementInteractor: GetBalanceManagedMetaAccountsHandler {
    func handleManagedMetaAccountsBalance(managedMetaAccounts: [ManagedMetaAccountModel]) {
        DispatchQueue.main.async {
            let changes = managedMetaAccounts.map { DataProviderChange.update(newItem: $0) }
            self.presenter?.didReceive(changes: changes)
        }
    }
}
