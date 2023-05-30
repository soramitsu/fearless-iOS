import UIKit
import RobinHood
import SSFModels

final class SelectAssetInteractor {
    // MARK: - Private properties

    private weak var output: SelectAssetInteractorOutput?

    private let operationQueue: OperationQueue
    private let chainAssetFetching: ChainAssetFetchingProtocol
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let assetRepository: AnyDataProviderRepository<AssetModel>

    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol

    private var pricesProvider: AnySingleValueProvider<[PriceData]>?
    private var chainAssets: [ChainAsset]?

    private lazy var accountInfosDeliveryQueue = {
        DispatchQueue(label: "co.jp.soramitsu.wallet.chainAssetList.deliveryQueue")
    }()

    init(
        chainAssetFetching: ChainAssetFetchingProtocol,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        assetRepository: AnyDataProviderRepository<AssetModel>,
        chainAssets: [ChainAsset]?,
        operationQueue: OperationQueue
    ) {
        self.chainAssetFetching = chainAssetFetching
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.assetRepository = assetRepository
        self.chainAssets = chainAssets
        self.operationQueue = operationQueue
    }

    private func fetchChainAssets() {
        if let chainAssets = self.chainAssets {
            subscribeToAccountInfo(for: chainAssets)
            subscribeToPrice(for: chainAssets)
            output?.didReceiveChainAssets(result: .success(chainAssets))
            return
        }
        chainAssetFetching.fetch(
            filters: [],
            sortDescriptors: []
        ) { [weak self] result in
            guard let result = result else {
                return
            }

            switch result {
            case let .success(chainAssets):
                self?.chainAssets = chainAssets
                self?.output?.didReceiveChainAssets(result: .success(chainAssets))
                if chainAssets.isEmpty {
                    self?.output?.didReceiveChainAssets(result: .failure(BaseOperationError.parentOperationCancelled))
                }
                self?.subscribeToAccountInfo(for: chainAssets)
                self?.subscribeToPrice(for: chainAssets)
            case let .failure(error):
                self?.output?.didReceiveChainAssets(result: .failure(error))
            }
        }
    }
}

// MARK: - SelectAssetInteractorInput

extension SelectAssetInteractor: SelectAssetInteractorInput {
    func setup(with output: SelectAssetInteractorOutput) {
        self.output = output
        fetchChainAssets()
    }
}

extension SelectAssetInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainAsset: ChainAsset) {
        output?.didReceiveAccountInfo(result: result, for: chainAsset)
    }
}

extension SelectAssetInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
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

private extension SelectAssetInteractor {
    func subscribeToPrice(for chainAssets: [ChainAsset]) {
        let pricesIds = chainAssets.compactMap(\.asset.priceId).uniq(predicate: { $0 })
        guard pricesIds.isNotEmpty else {
            output?.didReceivePricesData(result: .success([]))
            return
        }
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
