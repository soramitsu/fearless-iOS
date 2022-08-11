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

    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    weak var presenter: ChainAssetListInteractorOutput?

    init(
        chainAssetFetching: ChainAssetFetchingProtocol,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        assetRepository: AnyDataProviderRepository<AssetModel>,
        operationQueue: OperationQueue
    ) {
        self.chainAssetFetching = chainAssetFetching
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.assetRepository = assetRepository
        self.operationQueue = operationQueue
    }

    var filters: [ChainAssetsFetching.Filter] = []
    var sorts: [ChainAssetsFetching.SortDescriptor] = []
}

// MARK: - ChainAssetListInteractorInput

extension ChainAssetListInteractor: ChainAssetListInteractorInput {
    func setup(with output: ChainAssetListInteractorOutput) {
        self.output = output
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
                self?.subscribeToAccountInfo(for: chainAssets)
                self?.subscribeToPrice(for: chainAssets)
                DispatchQueue.main.async {
                    self?.output?.didReceiveChainAssets(result: .success(chainAssets))
                }
            case let .failure(error):
                DispatchQueue.main.async {
                    self?.output?.didReceiveChainAssets(result: .failure(error))
                }
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
        accountInfoSubscriptionAdapter.subscribe(chainsAssets: chainAssets, handler: self)
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
