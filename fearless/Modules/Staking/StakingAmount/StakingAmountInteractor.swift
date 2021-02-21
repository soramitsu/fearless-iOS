import UIKit
import RobinHood
import SoraKeystore

final class StakingAmountInteractor {
    weak var presenter: StakingAmountInteractorOutputProtocol!

    private let repository: AnyDataProviderRepository<ManagedAccountItem>
    private let priceProvider: SingleValueProvider<PriceData>
    private let operationManager: OperationManagerProtocol

    init(repository: AnyDataProviderRepository<ManagedAccountItem>,
         priceProvider: SingleValueProvider<PriceData>,
         operationManager: OperationManagerProtocol) {
        self.repository = repository
        self.priceProvider = priceProvider
        self.operationManager = operationManager
    }

    private func subscribeToPriceChanges() {
        let updateClosure = { [weak self] (changes: [DataProviderChange<PriceData>]) in
            if changes.isEmpty {
                self?.presenter.didReceive(price: nil)
            } else {
                for change in changes {
                    switch change {
                    case .insert(let item), .update(let item):
                        self?.presenter.didReceive(price: item)
                    case .delete:
                        self?.presenter.didReceive(price: nil)
                    }
                }
            }
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.presenter.didReceive(error: error)
            return
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: false,
                                                  waitsInProgressSyncOnAdd: false)
        priceProvider.addObserver(self,
                                  deliverOn: .main,
                                  executing: updateClosure,
                                  failing: failureClosure,
                                  options: options)
    }
}

extension StakingAmountInteractor: StakingAmountInteractorInputProtocol {
    func setup() {
        subscribeToPriceChanges()
    }

    func fetchAccounts() {
        let operation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let accounts = try operation.extractNoCancellableResultData()
                    self?.presenter.didReceive(accounts: accounts)
                } catch {
                    self?.presenter.didReceive(error: error)
                }
            }
        }

        operationManager.enqueue(operations: [operation], in: .transient)
    }
}
