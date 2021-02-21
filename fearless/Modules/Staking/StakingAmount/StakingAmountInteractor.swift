import UIKit
import RobinHood
import SoraKeystore

final class StakingAmountInteractor {
    weak var presenter: StakingAmountInteractorOutputProtocol!

    private let repository: AnyDataProviderRepository<ManagedAccountItem>
    private let operationManager: OperationManagerProtocol

    init(repository: AnyDataProviderRepository<ManagedAccountItem>,
         operationManager: OperationManagerProtocol) {
        self.repository = repository
        self.operationManager = operationManager
    }
}

extension StakingAmountInteractor: StakingAmountInteractorInputProtocol {
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
