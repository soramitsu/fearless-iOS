import RobinHood
final class WalletDetailsInteractor {
    weak var presenter: WalletDetailsInteractorOutputProtocol!

    private let flow: WalletDetailsFlow
    private let chainsRepository: AnyDataProviderRepository<ChainModel>
    private let operationManager: OperationManagerProtocol
    private let eventCenter: EventCenterProtocol
    private let repository: AnyDataProviderRepository<MetaAccountModel>
    private let availableExportOptionsProvider: AvailableExportOptionsProviderProtocol

    init(
        flow: WalletDetailsFlow,
        chainsRepository: AnyDataProviderRepository<ChainModel>,
        operationManager: OperationManagerProtocol,
        eventCenter: EventCenterProtocol,
        repository: AnyDataProviderRepository<MetaAccountModel>,
        availableExportOptionsProvider: AvailableExportOptionsProviderProtocol
    ) {
        self.flow = flow
        self.chainsRepository = chainsRepository
        self.operationManager = operationManager
        self.eventCenter = eventCenter
        self.repository = repository
        self.availableExportOptionsProvider = availableExportOptionsProvider
    }
}

extension WalletDetailsInteractor: AccountFetching {}

extension WalletDetailsInteractor: WalletDetailsInteractorInputProtocol {
    func markUnused(chain: ChainModel) {
        var unusedChainIds = flow.wallet.unusedChainIds ?? []
        unusedChainIds.append(chain.chainId)
        let updatedAccount = flow.wallet.replacingUnusedChainIds(unusedChainIds)

        let saveOperation = repository.saveOperation {
            [updatedAccount]
        } _: {
            []
        }

        saveOperation.completionBlock = { [weak self] in
            self?.fetchChainsWithAccounts()

            self?.eventCenter.notify(with: ChainsUpdatedEvent(updatedChains: [chain]))
        }

        operationManager.enqueue(operations: [saveOperation], in: .transient)
    }

    func setup() {
        switch flow {
        case .normal:
            fetchChainsWithAccounts()
        case let .export(_, accounts):
            presenter.didReceive(chains: accounts.map(\.chain))
        }
    }

    func update(walletName: String) {
        let updateOperation = ClosureOperation<MetaAccountModel> { [self] in
            self.flow.wallet.replacingName(walletName)
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

    func getAvailableExportOptions(for chainAccount: ChainAccountInfo) {
        guard let address = chainAccount.account.toAddress() else {
            presenter.didReceive(error: ChainAccountFetchingError.accountNotExists)
            return
        }

        fetchChainAccount(
            chain: chainAccount.chain,
            address: address,
            from: repository,
            operationManager: operationManager
        ) { [weak self] result in
            switch result {
            case let .success(chainResponse):
                guard let self = self, let response = chainResponse else {
                    self?.presenter?.didReceiveExportOptions(options: [.keystore], for: chainAccount)
                    return
                }
                let accountId = response.isChainAccount ? response.accountId : nil
                let options = self.availableExportOptionsProvider
                    .getAvailableExportOptions(
                        for: self.flow.wallet,
                        accountId: accountId,
                        isEthereum: response.isEthereumBased
                    )
                self.presenter?.didReceiveExportOptions(options: options, for: chainAccount)
            default:
                self?.presenter?.didReceiveExportOptions(options: [.keystore], for: chainAccount)
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
            presenter.didReceive(chains: chains)
        case .failure, .none:
            return
        }
    }
}
