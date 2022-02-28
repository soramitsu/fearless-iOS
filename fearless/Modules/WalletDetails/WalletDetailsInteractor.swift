import RobinHood
final class WalletDetailsInteractor {
    weak var presenter: WalletDetailsInteractorOutputProtocol!

    private let selectedMetaAccount: MetaAccountModel
    private let chainsRepository: AnyDataProviderRepository<ChainModel>
    private let operationManager: OperationManagerProtocol
    private let eventCenter: EventCenterProtocol
    private let repository: AnyDataProviderRepository<MetaAccountModel>
    private let availableExportOptionsProvider = AvailableExportOptionsProvider()

    init(
        selectedMetaAccount: MetaAccountModel,
        chainsRepository: AnyDataProviderRepository<ChainModel>,
        operationManager: OperationManagerProtocol,
        eventCenter: EventCenterProtocol,
        repository: AnyDataProviderRepository<MetaAccountModel>
    ) {
        self.selectedMetaAccount = selectedMetaAccount
        self.chainsRepository = chainsRepository
        self.operationManager = operationManager
        self.eventCenter = eventCenter
        self.repository = repository
    }
}

extension WalletDetailsInteractor: AccountFetching {}

extension WalletDetailsInteractor: WalletDetailsInteractorInputProtocol {
    func setup() {
        fetchChainsWithAccounts()
    }

    func update(walletName: String) {
        let updateOperation = ClosureOperation<MetaAccountModel> { [self] in
            selectedMetaAccount.replacingName(walletName)
        }
        let saveOperation: ClosureOperation<MetaAccountModel> = ClosureOperation { [weak self] in
            let accountItem = try updateOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            return accountItem
        }
        saveOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                switch saveOperation.result {
                case let .success(wallet):
                    self?.eventCenter.notify(with: WalletNameChanged(wallet: wallet))
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

    func getAvailableExportOptions(for chain: ChainModel, address: String) {
        fetchChainAccount(
            chain: chain,
            address: address,
            from: repository,
            operationManager: operationManager
        ) { [weak self] result in
            switch result {
            case let .success(chainResponse):
                guard let self = self, let response = chainResponse else {
                    self?.presenter?.didReceiveExportOptions(options: [.keystore], for: chain)
                    return
                }
                let options = self.availableExportOptionsProvider
                    .getAvailableExportOptions(
                        for: address,
                        accountId: response.accountId
                    )
                self.presenter?.didReceiveExportOptions(options: options, for: chain)
            default:
                self?.presenter?.didReceiveExportOptions(options: [.keystore], for: chain)
            }
        }
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
