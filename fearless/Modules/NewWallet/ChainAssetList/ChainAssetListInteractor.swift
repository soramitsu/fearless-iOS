import UIKit
import RobinHood

final class ChainAssetListInteractor {
    // MARK: - Private properties

    private weak var output: ChainAssetListInteractorOutput?

    private let chainAssetFetching: ChainAssetFetchingProtocol
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let assetRepository: AnyDataProviderRepository<AssetModel>
    private let operationQueue: OperationQueue
    private var pricesProvider: AnySingleValueProvider<[PriceData]>?
    private var chainAssets: [ChainAsset]?
    private var filters: [ChainAssetsFetching.Filter] = []
    private var sorts: [ChainAssetsFetching.SortDescriptor] = []
    private let eventCenter: EventCenter
    private let networkIssuesCenter: NetworkIssuesCenterProtocol
    private var wallet: MetaAccountModel

    private lazy var accountInfosDeliveryQueue = {
        DispatchQueue(label: "co.jp.soramitsu.wallet.chainAssetList.deliveryQueue")
    }()

    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    weak var presenter: ChainAssetListInteractorOutput?

    init(
        wallet: MetaAccountModel,
        chainAssetFetching: ChainAssetFetchingProtocol,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        assetRepository: AnyDataProviderRepository<AssetModel>,
        operationQueue: OperationQueue,
        eventCenter: EventCenter,
        networkIssuesCenter: NetworkIssuesCenterProtocol
    ) {
        self.wallet = wallet
        self.chainAssetFetching = chainAssetFetching
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.assetRepository = assetRepository
        self.operationQueue = operationQueue
        self.eventCenter = eventCenter
        self.networkIssuesCenter = networkIssuesCenter
    }
}

// MARK: - ChainAssetListInteractorInput

extension ChainAssetListInteractor: ChainAssetListInteractorInput {
    func setup(with output: ChainAssetListInteractorOutput) {
        self.output = output

        eventCenter.add(observer: self, dispatchIn: .main)
        networkIssuesCenter.addIssuesListener(self, getExisting: true)
    }

    func updateChainAssets(
        using filters: [ChainAssetsFetching.Filter],
        sorts: [ChainAssetsFetching.SortDescriptor]
    ) {
        self.filters = filters
        self.sorts = sorts
        chainAssetFetching.fetch(
            filters: filters,
            sortDescriptors: sorts
        ) { [weak self] result in
            guard let result = result else {
                return
            }

            switch result {
            case let .success(chainAssets):
                self?.output?.didReceiveChainAssets(result: .success(chainAssets))
                self?.subscribeToAccountInfo(for: chainAssets)
                self?.subscribeToPrice(for: chainAssets)
            case let .failure(error):
                self?.output?.didReceiveChainAssets(result: .failure(error))
            }
        }
    }
}

private extension ChainAssetListInteractor {
    func subscribeToPrice(for chainAssets: [ChainAsset]) {
        let pricesIds = chainAssets.compactMap(\.asset.priceId)
        pricesProvider = subscribeToPrices(for: pricesIds)
    }

    func subscribeToAccountInfo(for chainAssets: [ChainAsset]) {
        accountInfoSubscriptionAdapter.subscribe(
            chainsAssets: chainAssets,
            handler: self,
            deliveryOn: accountInfosDeliveryQueue
        )
    }

    func updatePrices(with priceData: [PriceData]) {
        let updatedAssets = priceData.compactMap { priceData -> AssetModel? in
            let chainAsset = chainAssets?.first(where: { $0.asset.priceId == priceData.priceId })

            guard let asset = chainAsset?.asset else {
                return nil
            }
            return asset.replacingPrice(priceData)
        }

        let saveOperation = assetRepository.saveOperation {
            updatedAssets
        } _: {
            []
        }

        operationQueue.addOperation(saveOperation)
    }
}

extension ChainAssetListInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrices(result: Result<[PriceData], Error>) {
        switch result {
        case let .success(prices):
            DispatchQueue.global().async {
                self.updatePrices(with: prices)
            }
        case .failure:
            break
        }

        output?.didReceivePricesData(result: result)
    }
}

extension ChainAssetListInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainAsset: ChainAsset) {
        output?.didReceiveAccountInfo(result: result, for: chainAsset)
    }
}

extension ChainAssetListInteractor: EventVisitorProtocol {
    func processMetaAccountChanged(event: MetaAccountModelChangedEvent) {
        output?.didReceiveWallet(wallet: event.account)
        if wallet.selectedCurrency != event.account.selectedCurrency {
            pricesProvider?.refresh()
        }
        wallet = event.account
    }
}

extension ChainAssetListInteractor: NetworkIssuesCenterListener {
    func handleChainsWithIssues(_ chains: [ChainModel]) {
        output?.didReceiveChainsWithNetworkIssues(chains)
    }
}
