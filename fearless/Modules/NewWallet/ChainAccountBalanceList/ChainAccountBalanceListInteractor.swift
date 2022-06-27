import UIKit
import RobinHood
import IrohaCrypto
import SoraFoundation
import SoraKeystore

final class ChainAccountBalanceListInteractor {
    weak var presenter: ChainAccountBalanceListInteractorOutputProtocol?

    private var selectedMetaAccount: MetaAccountModel
    private let chainRepository: AnyDataProviderRepository<ChainModel>
    private let assetRepository: AnyDataProviderRepository<AssetModel>
    private var accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let operationQueue: OperationQueue
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    private let eventCenter: EventCenterProtocol
    private let metaAccountRepository: AnyDataProviderRepository<MetaAccountModel>
    private let jsonDataProviderFactory: JsonDataProviderFactoryProtocol

    private var chains: [ChainModel]?

    private var pricesProvider: AnySingleValueProvider<[PriceData]>?
    private var fiatInfoProvider: AnySingleValueProvider<[Currency]>?
    private lazy var currency: Currency = {
        selectedMetaAccount.selectedCurrency
    }()

    init(
        selectedMetaAccount: MetaAccountModel,
        chainRepository: AnyDataProviderRepository<ChainModel>,
        assetRepository: AnyDataProviderRepository<AssetModel>,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        operationQueue: OperationQueue,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        eventCenter: EventCenterProtocol,
        metaAccountRepository: AnyDataProviderRepository<MetaAccountModel>,
        jsonDataProviderFactory: JsonDataProviderFactoryProtocol
    ) {
        self.selectedMetaAccount = selectedMetaAccount
        self.chainRepository = chainRepository
        self.assetRepository = assetRepository
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.operationQueue = operationQueue
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.eventCenter = eventCenter
        self.metaAccountRepository = metaAccountRepository
        self.jsonDataProviderFactory = jsonDataProviderFactory
    }

    private func fetchChainsAndSubscribeBalance() {
        let fetchOperation = chainRepository.fetchAllOperation(with: RepositoryFetchOptions())

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
            var chains = chains.filter { !$0.assets.isEmpty }
            guard !chains.isEmpty else {
                presenter?.didReceiveChains(result: .failure(BaseOperationError.unexpectedDependentResult))
                return
            }

            self.chains = chains

            presenter?.didReceiveChains(result: .success(chains))
            subscribeToAccountInfo(for: chains)
            subscribeToPrice(for: chains)
        case let .failure(error):
            presenter?.didReceiveChains(result: .failure(error))
        case .none:
            presenter?.didReceiveChains(result: .failure(BaseOperationError.parentOperationCancelled))
        }
    }

    private func subscribeToPrice(for chains: [ChainModel]) {
        var pricesIds: [AssetModel.PriceId] = []
        for chain in chains {
            for asset in chain.assets {
                if let priceId = asset.asset.priceId {
                    pricesIds.append(priceId)
                } else {
                    presenter?.didReceiveAssetIdWithoutPriceId(asset.asset.id)
                }
            }
        }

        pricesProvider = subscribeToPrices(for: pricesIds)
    }

    private func subscribeToAccountInfo(for chains: [ChainModel]) {
        let chainAssets = chains.map(\.chainAssets).reduce([], +)
        accountInfoSubscriptionAdapter.subscribe(chainsAssets: chainAssets, handler: self)
    }

    private func replaceAccountInfoSubscriptionAdapter() {
        if let account = SelectedWalletSettings.shared.value {
            accountInfoSubscriptionAdapter = AccountInfoSubscriptionAdapter(
                walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
                selectedMetaAccount: account
            )
        }
    }

    private func subscribeToFiats() {
        fiatInfoProvider = nil

        guard let fiatUrl = ApplicationConfig.shared.fiatsURL else { return }
        fiatInfoProvider = jsonDataProviderFactory.getJson(for: fiatUrl)

        let updateClosure: ([DataProviderChange<[Currency]>]) -> Void = { [weak self] changes in
            if let result = changes.reduceToLastChange() {
                self?.presenter?.didReceiveSupportedCurrencys(.success(result))
            }
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.presenter?.didReceiveSupportedCurrencys(.failure(error))
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: true,
            waitsInProgressSyncOnAdd: false
        )

        fiatInfoProvider?.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }

    private func save(_ currency: Currency) {
        let updatedAccount = selectedMetaAccount.replacingCurrency(currency)

        let operation = metaAccountRepository.saveOperation {
            [updatedAccount]
        } _: {
            []
        }

        operation.completionBlock = { [weak self] in
            SelectedWalletSettings.shared.performSave(value: updatedAccount) { result in
                switch result {
                case let .success(account):
                    self?.eventCenter.notify(with: MetaAccountModelChangedEvent(account: account))
                case .failure:
                    break
                }
            }
        }

        operationQueue.addOperation(operation)
    }
}

extension ChainAccountBalanceListInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrices(result: Result<[PriceData], Error>) {
        switch result {
        case let .success(prices):
            updatePrices(with: prices)
        case .failure:
            break
        }
        presenter?.didReceivePricesData(result: result)
    }

    private func updatePrices(with priceData: [PriceData]) {
        let updatedAssets = priceData.compactMap { priceData -> AssetModel? in
            let chainAsset = chains?
                .compactMap { Array($0.assets) }
                .reduce([], +)
                .first(where: { $0?.asset.priceId == priceData.priceId })

            guard let asset = chainAsset?.asset else {
                return nil
            }
            return asset.replacingPrice(Decimal(string: priceData.price))
        }

        let saveOperation = assetRepository.saveOperation {
            updatedAssets
        } _: {
            []
        }

        operationQueue.addOperation(saveOperation)
    }
}

extension ChainAccountBalanceListInteractor: ChainAccountBalanceListInteractorInputProtocol {
    func setup() {
        eventCenter.add(observer: self, dispatchIn: .main)
        fetchChainsAndSubscribeBalance()
        presenter?.didReceiveSelectedAccount(selectedMetaAccount)
        presenter?.didRecieveSelectedCurrency(currency)
    }

    func refresh() {
        fetchChainsAndSubscribeBalance()
    }

    func didReceive(currency: Currency) {
        save(currency)
    }

    func fetchFiats() {
        subscribeToFiats()
    }
}

extension ChainAccountBalanceListInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainAsset: ChainAsset) {
        presenter?.didReceiveAccountInfo(result: result, for: chainAsset)
    }
}

extension ChainAccountBalanceListInteractor: EventVisitorProtocol {
    func processSelectedAccountChanged(event _: SelectedAccountChanged) {
        replaceAccountInfoSubscriptionAdapter()
        refresh()
    }

    func processChainsUpdated(event _: ChainsUpdatedEvent) {
        refresh()
    }

    func processSelectedConnectionChanged(event _: SelectedConnectionChanged) {
        refresh()
    }

    func processMetaAccountChanged(event: MetaAccountModelChangedEvent) {
        if selectedMetaAccount.metaId == event.account.metaId {
            selectedMetaAccount = event.account
            currency = event.account.selectedCurrency
            presenter?.didReceiveSelectedAccount(selectedMetaAccount)
            presenter?.didRecieveSelectedCurrency(currency)
            pricesProvider = nil
            refresh()
        }
    }

    func processWalletNameChanged(event: WalletNameChanged) {
        presenter?.didReceiveSelectedAccount(event.wallet)
    }
}

extension ChainAccountBalanceListInteractor: ApplicationHandlerDelegate {
    func didReceiveDidBecomeActive(notification _: Notification) {
        refresh()
    }
}

extension ChainAccountBalanceListInteractor: AnyProviderAutoCleaning {}
