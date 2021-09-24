import UIKit
import RobinHood

final class ChainSelectionInteractor {
    weak var presenter: ChainSelectionInteractorOutputProtocol!

    let selectedMetaAccount: MetaAccountModel
    let repository: AnyDataProviderRepository<ChainModel>
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let operationQueue: OperationQueue

    private var accountInfoProviders: [AnyDataProvider<DecodedAccountInfo>]?

    init(
        selectedMetaAccount: MetaAccountModel,
        repository: AnyDataProviderRepository<ChainModel>,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.selectedMetaAccount = selectedMetaAccount
        self.repository = repository
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
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
        var providers: [AnyDataProvider<DecodedAccountInfo>] = []

        for chain in chains {
            if
                let accountId = selectedMetaAccount.fetch(for: chain.accountRequest())?.accountId,
                let dataProvider = subscribeToAccountInfoProvider(for: accountId, chainId: chain.chainId) {
                providers.append(dataProvider)
            } else {
                presenter.didReceiveAccountInfo(
                    result: .failure(ChainAccountFetchingError.accountNotExists),
                    for: chain.chainId
                )
            }
        }

        accountInfoProviders = providers
    }
}

extension ChainSelectionInteractor: ChainSelectionInteractorInputProtocol {
    func setup() {
        fetchChainsAndSubscribeBalance()
    }
}

extension ChainSelectionInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainId: ChainModel.Id
    ) {
        presenter.didReceiveAccountInfo(result: result, for: chainId)
    }
}
