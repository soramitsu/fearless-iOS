import UIKit
import SoraKeystore
import RobinHood

final class ControllerAccountInteractor {
    weak var presenter: ControllerAccountInteractorOutputProtocol!

    let singleValueProviderFactory: SingleValueProviderFactoryProtocol
    let substrateProviderFactory: SubstrateDataProviderFactoryProtocol
    let settings: SettingsManagerProtocol
    let accountRepository: AnyDataProviderRepository<AccountItem>
    let operationManager: OperationManagerProtocol

    private var stashItemProvider: StreamableProvider<StashItem>?

    init(
        singleValueProviderFactory: SingleValueProviderFactoryProtocol,
        substrateProviderFactory: SubstrateDataProviderFactoryProtocol,
        settings: SettingsManagerProtocol,
        accountRepository: AnyDataProviderRepository<AccountItem>,
        operationManager: OperationManagerProtocol
    ) {
        self.singleValueProviderFactory = singleValueProviderFactory
        self.substrateProviderFactory = substrateProviderFactory
        self.settings = settings
        self.accountRepository = accountRepository
        self.operationManager = operationManager
    }
}

extension ControllerAccountInteractor: ControllerAccountInteractorInputProtocol {
    func setup() {
        if let address = settings.selectedAccount?.address {
            stashItemProvider = subscribeToStashItemProvider(for: address)
        }
    }

    func fetchAccounts() {
        let operation = accountRepository.fetchAllOperation(with: RepositoryFetchOptions())
        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let accounts = try operation.extractNoCancellableResultData()
                    self?.presenter.didReceiveAccounts(result: .success(accounts))
                } catch {
                    self?.presenter.didReceiveAccounts(result: .failure(error))
                }
            }
        }

        operationManager.enqueue(operations: [operation], in: .transient)
    }
}

extension ControllerAccountInteractor: SubstrateProviderSubscriber, SubstrateProviderSubscriptionHandler {
    func handleStashItem(result: Result<StashItem?, Error>) {
        presenter.didReceiveStashItem(result: result)
    }
}
