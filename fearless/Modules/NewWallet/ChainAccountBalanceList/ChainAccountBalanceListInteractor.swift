import UIKit
import RobinHood
import IrohaCrypto
import SoraFoundation

final class ChainAccountBalanceListInteractor {
    weak var presenter: ChainAccountBalanceListInteractorOutputProtocol?

    let selectedMetaAccount: MetaAccountModel
    let repository: AnyDataProviderRepository<ChainModel>
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let operationQueue: OperationQueue
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let eventCenter: EventCenterProtocol

    private var accountInfoProviders: [AnyDataProvider<DecodedAccountInfo>]?
    private var priceProviders: [AnySingleValueProvider<PriceData>]?

    init(
        selectedMetaAccount: MetaAccountModel,
        repository: AnyDataProviderRepository<ChainModel>,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        operationQueue: OperationQueue,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        eventCenter: EventCenterProtocol
    ) {
        self.selectedMetaAccount = selectedMetaAccount
        self.repository = repository
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.operationQueue = operationQueue
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.eventCenter = eventCenter
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
            subscribeToPrice(for: filteredChains)
        case let .failure(error):
            presenter?.didReceiveChains(result: .failure(error))
        case .none:
            presenter?.didReceiveChains(result: .failure(BaseOperationError.parentOperationCancelled))
        }
    }

    private func subscribeToPrice(for chains: [ChainModel]) {
        var providers: [AnySingleValueProvider<PriceData>] = []

        for chain in chains {
            for asset in chain.assets {
                if
                    let priceId = asset.asset.priceId,
                    let dataProvider = subscribeToPrice(for: priceId) {
                    providers.append(dataProvider)
                }
            }
        }

        priceProviders = providers
    }

    private func subscribeToAccountInfo(for chains: [ChainModel]) {
        var providers: [AnyDataProvider<DecodedAccountInfo>] = []

        for chain in chains {
            if
                let accountId = selectedMetaAccount.fetch(for: chain.accountRequest())?.accountId,
                let dataProvider = subscribeToAccountInfoProvider(for: accountId, chainId: chain.chainId) {
                providers.append(dataProvider)
            } else {
                presenter?.didReceiveAccountInfo(
                    result: .failure(ChainAccountFetchingError.accountNotExists),
                    for: chain.chainId
                )
            }
        }

        accountInfoProviders = providers
    }

    private func refreshChain(_: ChainModel) {}
}

extension ChainAccountBalanceListInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId: AssetModel.PriceId) {
        presenter?.didReceivePriceData(result: result, for: priceId)
    }
}

extension ChainAccountBalanceListInteractor: ChainAccountBalanceListInteractorInputProtocol {
    func setup() {
        eventCenter.add(observer: self, dispatchIn: .main)

        fetchChainsAndSubscribeBalance()

        presenter?.didReceiveSelectedAccount(selectedMetaAccount)
    }

    func refresh() {
        if let accountInfoProviders = accountInfoProviders {
            for accountInfoProvider in accountInfoProviders {
                accountInfoProvider.removeObserver(self)
            }
        }

        if let priceProviders = priceProviders {
            for priceProvider in priceProviders {
                priceProvider.removeObserver(self)
            }
        }

        fetchChainsAndSubscribeBalance()
    }
}

extension ChainAccountBalanceListInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainId: ChainModel.Id
    ) {
        presenter?.didReceiveAccountInfo(result: result, for: chainId)
    }
}

extension ChainAccountBalanceListInteractor: EventVisitorProtocol {
    func processSelectedAccountChanged(event _: SelectedAccountChanged) {
        refresh()
    }

    func processChainSyncDidComplete(event _: ChainSyncDidComplete) {
        refresh()
    }

    func processChainsUpdated(event _: ChainsUpdatedEvent) {
        refresh()
    }

    func processSelectedConnectionChanged(event _: SelectedConnectionChanged) {
        refresh()
    }
}

extension ChainAccountBalanceListInteractor: ApplicationHandlerDelegate {
    func didReceiveDidBecomeActive(notification _: Notification) {
        refresh()
    }
}

extension ChainAccountBalanceListInteractor: AnyProviderAutoCleaning {}
