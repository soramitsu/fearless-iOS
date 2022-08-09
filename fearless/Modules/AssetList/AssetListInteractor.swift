import Foundation
import RobinHood

final class AssetListInteractor {
    private let chainAssetFetching: ChainAssetFetchingProtocol
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let assetRepository: AnyDataProviderRepository<AssetModel>
    private let operationQueue: OperationQueue
    private var pricesProvider: AnySingleValueProvider<[PriceData]>?
    private var chainAssets: [ChainAsset]?

    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    weak var presenter: AssetListInteractorOutput?

    init(
        chainAssetFetching: ChainAssetFetchingProtocol,
        pricesProvider: AnySingleValueProvider<[PriceData]>?,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        assetRepository: AnyDataProviderRepository<AssetModel>,
        operationQueue: OperationQueue
    ) {
        self.chainAssetFetching = chainAssetFetching
        self.pricesProvider = pricesProvider
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.assetRepository = assetRepository
        self.operationQueue = operationQueue
    }
}

extension AssetListInteractor: AssetListInteractorInput {
    func updateChainAssets(
        using filters: [ChainAssetsFetching.Filter],
        sorts: [ChainAssetsFetching.SortDescriptor]
    ) {
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
                    self?.presenter?.didReceiveChainAssets(result: .success(chainAssets))
                }
            case let .failure(error):
                DispatchQueue.main.async {
                    self?.presenter?.didReceiveChainAssets(result: .failure(error))
                }
            }
        }
    }
}

private extension AssetListInteractor {
    func subscribeToPrice(for chainAssets: [ChainAsset]) {
        var pricesIds: [AssetModel.PriceId] = []

        chainAssets.forEach { chainAsset in
            if let priceId = chainAsset.asset.priceId {
                pricesIds.append(priceId)
            }
        }
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

extension AssetListInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrices(result: Result<[PriceData], Error>) {
        switch result {
        case let .success(prices):
            DispatchQueue.global().async {
                self.updatePrices(with: prices)
            }
        case .failure:
            break
        }
        presenter?.didReceivePricesData(result: result)
    }
}

extension AssetListInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainAsset: ChainAsset) {
        presenter?.didReceiveAccountInfo(result: result, for: chainAsset)
    }
}
