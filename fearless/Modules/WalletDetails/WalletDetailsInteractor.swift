import RobinHood
final class WalletDetailsInteractor {
    weak var presenter: WalletDetailsInteractorOutputProtocol!

    private let selectedMetaAccount: MetaAccountModel
    private let chainsRepository: AnyDataProviderRepository<ChainModel>
    private let operationManager: OperationManagerProtocol
    private let walletDetailsChangeCompletion: (MetaAccountModel) -> Void

    init(
        selectedMetaAccount: MetaAccountModel,
        chainsRepository: AnyDataProviderRepository<ChainModel>,
        operationManager: OperationManagerProtocol,
        walletDetailsChangeCompletion: @escaping (MetaAccountModel) -> Void
    ) {
        self.selectedMetaAccount = selectedMetaAccount
        self.chainsRepository = chainsRepository
        self.operationManager = operationManager
        self.walletDetailsChangeCompletion = walletDetailsChangeCompletion
    }
}

extension WalletDetailsInteractor: AccountFetching {}

extension WalletDetailsInteractor: WalletDetailsInteractorInputProtocol {
    func setup() {
        fetchChainsWithAccounts()
    }

    func update(_ walletName: String) {
        let updateOperation = ClosureOperation<MetaAccountModel> { [self] in
            selectedMetaAccount.replacingName(walletName)
        }
        let saveOperation: ClosureOperation<MetaAccountModel> = ClosureOperation { [weak self] in
            let accountItem = try updateOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            self?.walletDetailsChangeCompletion(accountItem)
            return accountItem
        }
        saveOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                switch saveOperation.result {
                case .success:
                    break
                case let .failure(error):
                    self?.presenter.didReceive(error: error)

                case .none:
                    let error = BaseOperationError.parentOperationCancelled
                    self?.presenter.didReceive(error: error)
                }
            }
        }
        saveOperation.addDependency(updateOperation)
        operationManager.enqueue(operations: [updateOperation, saveOperation], in: .transient)
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

        operationManager.enqueue(operations: [fetchOperation], in: .transient)
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
