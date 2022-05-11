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

    private var priceProviders: [AnySingleValueProvider<PriceData>]?
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
        var providers: [AnySingleValueProvider<PriceData>] = []

        guard priceProviders == nil else {
            priceProviders?.forEach { $0.refresh() }
            return
        }

        for chain in chains {
            for asset in chain.assets {
                if
                    let priceId = asset.asset.priceId,
                    let dataProvider = subscribeToPrice(for: priceId) {
                    providers.append(dataProvider)
                } else {
                    presenter?.didReceivePriceData(result: .success(nil), for: asset.asset.id)
                }
            }
        }

        priceProviders = providers
    }

    private func subscribeToAccountInfo(for chains: [ChainModel]) {
        accountInfoSubscriptionAdapter.subscribe(chains: chains, handler: self)
    }

    private func refreshChain(_: ChainModel) {}

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

    private func updatePrices() {
        priceProviders?.forEach { $0.refresh() }
    }
}

extension ChainAccountBalanceListInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId: AssetModel.PriceId) {
        switch result {
        case let .success(priceData):
            updatePrice(with: priceData, priceId: priceId)
        case .failure:
            updatePrice(with: nil, priceId: priceId)
        }

        presenter?.didReceivePriceData(result: result, for: priceId)
    }

    private func updatePrice(
        with priceData: PriceData?,
        priceId: AssetModel.PriceId
    ) {
        let chainAsset = chains?
            .compactMap { Array($0.assets) }
            .reduce([], +)
            .first(where: { $0?.asset.priceId == priceId })
        if let asset = chainAsset?.asset {
            let price = priceData?.price ?? ""
            let updatedAsset = asset.replacingPrice(Decimal(string: price))

            let saveOperation = assetRepository.saveOperation {
                [updatedAsset]
            } _: {
                []
            }

            operationQueue.addOperation(saveOperation)
        }
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
            priceProviders = nil
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
