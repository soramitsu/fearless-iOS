import UIKit
import RobinHood

final class ChainSelectionInteractor {
    weak var presenter: ChainSelectionInteractorOutputProtocol!

    let selectedMetaAccount: MetaAccountModel
    let repository: AnyDataProviderRepository<ChainModel>
    let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    let operationQueue: OperationQueue

    private var accountInfoProviders: [AnyDataProvider<DecodedAccountInfo>]?

    init(
        selectedMetaAccount: MetaAccountModel,
        repository: AnyDataProviderRepository<ChainModel>,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        operationQueue: OperationQueue
    ) {
        self.selectedMetaAccount = selectedMetaAccount
        self.repository = repository
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.operationQueue = operationQueue
    }

    private func fetchChainsAndSubscribeBalance() {
        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        fetchOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                self?.handleChains(result: fetchOperation.result)
            }
        }

        operationQueue.addOperation(fetchOperation)
    }

    private func handleChains(result: Result<[ChainModel], Error>?) {
        switch result {
        case let .success(chains):
            presenter.didReceiveChains(result: .success(chains))
            subscribeToAccountInfo(for: chains)
        case let .failure(error):
            presenter.didReceiveChains(result: .failure(error))
        case .none:
            presenter.didReceiveChains(result: .failure(BaseOperationError.parentOperationCancelled))
        }
    }

    private func subscribeToAccountInfo(for chains: [ChainModel]) {
        accountInfoSubscriptionAdapter.subscribe(chains: chains, handler: self)
    }
}

extension ChainSelectionInteractor: ChainSelectionInteractorInputProtocol {
    func setup() {
        fetchChainsAndSubscribeBalance()
    }
}

extension ChainSelectionInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainId: ChainModel.Id
    ) {
        presenter.didReceiveAccountInfo(result: result, for: chainId)
    }
}
