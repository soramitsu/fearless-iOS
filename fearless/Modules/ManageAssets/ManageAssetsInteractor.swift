import UIKit
import RobinHood

final class ManageAssetsInteractor {
    weak var presenter: ManageAssetsInteractorOutputProtocol?

    private let selectedMetaAccount: MetaAccountModel
    private let repository: AnyDataProviderRepository<ChainModel>
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let operationQueue: OperationQueue

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
            let accountSupportsEthereum = SelectedWalletSettings.shared.value?.ethereumPublicKey != nil

            let filteredChains: [ChainModel] = accountSupportsEthereum ? chains : chains.filter { $0.isEthereumBased == false }
            presenter?.didReceiveChains(result: .success(filteredChains))
            subscribeToAccountInfo(for: filteredChains)
        case let .failure(error):
            presenter?.didReceiveChains(result: .failure(error))
        case .none:
            presenter?.didReceiveChains(result: .failure(BaseOperationError.parentOperationCancelled))
        }
    }

    private func subscribeToAccountInfo(for chains: [ChainModel]) {
        accountInfoSubscriptionAdapter.subscribe(chains: chains, handler: self)
    }
}

extension ManageAssetsInteractor: ManageAssetsInteractorInputProtocol {
    func setup() {
        fetchChainsAndSubscribeBalance()
    }
}

extension ManageAssetsInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainId: ChainModel.Id
    ) {
        presenter?.didReceiveAccountInfo(result: result, for: chainId)
    }
}
