import RobinHood
import SSFModels

final class WalletDetailsInteractor {
    weak var presenter: WalletDetailsInteractorOutputProtocol!

    private var flow: WalletDetailsFlow {
        didSet {
            presenter.didReceive(updatedFlow: flow)
        }
    }

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
        self.eventCenter.add(observer: self)
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
            SelectedWalletSettings.shared.performSave(value: updatedAccount) { result in
                switch result {
                case let .success(account):
                    DispatchQueue.main.async {
                        if case .normal = self?.flow {
                            self?.flow = .normal(wallet: account)
                        }

                        self?.eventCenter.notify(with: MetaAccountModelChangedEvent(account: account))
                    }

                case .failure:
                    break
                }
            }
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
        let updatedWallet = flow.wallet.replacingName(walletName)
        let saveOperation = repository.saveOperation {
            [updatedWallet]
        } _: {
            []
        }

        saveOperation.completionBlock = { [eventCenter] in
            eventCenter.notify(with: WalletNameChanged(wallet: updatedWallet))
        }

        operationManager.enqueue(operations: [saveOperation], in: .transient)
    }

    func getAvailableExportOptions(for chainAccount: ChainAccountInfo) {
        guard let address = chainAccount.account.toAddress() else {
            presenter.didReceive(error: ChainAccountFetchingError.accountNotExists)
            return
        }

        fetchChainAccountFor(
            meta: flow.wallet,
            chain: chainAccount.chain,
            address: address
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

extension WalletDetailsInteractor: EventVisitorProtocol {
    func processSelectedAccountChanged(event: SelectedAccountChanged) {
        if case .normal = flow {
            DispatchQueue.main.async {
                self.flow = .normal(wallet: event.account)
            }
        }
    }
}
