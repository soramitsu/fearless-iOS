import RobinHood
final class WalletDetailsInteractor {
    weak var presenter: WalletDetailsInteractorOutputProtocol!

    private let selectedMetaAccount: MetaAccountModel
    private let chainsRepository: AnyDataProviderRepository<ChainModel>
    private let operationQueue: OperationQueue

    init(
        selectedMetaAccount: MetaAccountModel,
        chainsRepository: AnyDataProviderRepository<ChainModel>,
        operationQueue: OperationQueue
    ) {
        self.selectedMetaAccount = selectedMetaAccount
        self.chainsRepository = chainsRepository
        self.operationQueue = operationQueue
    }
}

extension WalletDetailsInteractor: AccountFetching {}

extension WalletDetailsInteractor: WalletDetailsInteractorInputProtocol {
    func setup() {
        fetchChainsWithAccounts()
    }
}

private extension WalletDetailsInteractor {
    func fetchChainsWithAccounts() {
        let fetchOperation = chainsRepository.fetchAllOperation(with: RepositoryFetchOptions())

        fetchOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                self?.handleChains(result: fetchOperation.result)
            }
        }

        operationQueue.addOperation(fetchOperation)
    }

    func handleChains(result: Result<[ChainModel], Error>?) {
        switch result {
        case let .success(chains):
            var chainsWithAccounts: [ChainModel: ChainAccountResponse] = [:]
            chains.forEach { chain in
                if let chainAccount = selectedMetaAccount.fetch(for: chain.accountRequest()) {
                    chainsWithAccounts[chain] = chainAccount
                }
            }
            presenter.didReceive(chainsWithAccounts: chainsWithAccounts)
        case .failure, .none:
            return
        }
    }
}
