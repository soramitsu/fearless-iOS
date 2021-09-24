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

    init(
        repository: AnyDataProviderRepository<ManagedMetaAccountModel>,
        repositoryObservable: AnyDataProviderRepositoryObservable<ManagedMetaAccountModel>,
        settings: SelectedWalletSettings,
        operationQueue: OperationQueue,
        eventCenter: EventCenterProtocol
    ) {
        self.repository = repository
        self.repositoryObservable = repositoryObservable
        self.settings = settings
        self.operationQueue = operationQueue
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

        operationQueue.addOperation(operation)
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

        provideInitialList()
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
}
