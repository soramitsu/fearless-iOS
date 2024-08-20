import UIKit
import RobinHood
import SSFModels

final class SelectAssetInteractor {
    // MARK: - Private properties

    private weak var output: SelectAssetInteractorOutput?

    private let chainAssetFetching: ChainAssetFetchingProtocol
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let wallet: MetaAccountModel

    private let priceLocalSubscriber: PriceLocalStorageSubscriber

    private var pricesProvider: AnySingleValueProvider<[PriceData]>?
    private var chainAssets: [ChainAsset]?

    private lazy var accountInfosDeliveryQueue = {
        DispatchQueue(label: "co.jp.soramitsu.wallet.chainAssetList.deliveryQueue")
    }()

    init(
        chainAssetFetching: ChainAssetFetchingProtocol,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        priceLocalSubscriber: PriceLocalStorageSubscriber,
        chainAssets: [ChainAsset]?,
        wallet: MetaAccountModel
    ) {
        self.chainAssetFetching = chainAssetFetching
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.priceLocalSubscriber = priceLocalSubscriber
        self.chainAssets = chainAssets
        self.wallet = wallet
    }

    private func fetchChainAssets() {
        if let chainAssets = self.chainAssets {
            subscribeToAccountInfo(for: chainAssets)
            subscribeToPrice(for: chainAssets)
            output?.didReceiveChainAssets(result: .success(chainAssets))
            return
        }
        chainAssetFetching.fetch(
            shouldUseCache: true,
            filters: [.enabled(wallet: wallet)],
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

    func update(with chainAssets: [ChainAsset]) {
        self.chainAssets = chainAssets
        output?.didReceiveChainAssets(result: .success(chainAssets))
        if chainAssets.isEmpty {
            output?.didReceiveChainAssets(result: .failure(BaseOperationError.parentOperationCancelled))
        }
        subscribeToAccountInfo(for: chainAssets)
        subscribeToPrice(for: chainAssets)
    }
}

extension SelectAssetInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainAsset: ChainAsset) {
        output?.didReceiveAccountInfo(result: result, for: chainAsset)
    }
}

extension SelectAssetInteractor: PriceLocalSubscriptionHandler {
    func handlePrices(result: Result<[PriceData], Error>) {
        output?.didReceivePricesData(result: result)
    }
}

private extension SelectAssetInteractor {
    func subscribeToPrice(for chainAssets: [ChainAsset]) {
        guard chainAssets.isNotEmpty else {
            output?.didReceivePricesData(result: .success([]))
            return
        }
        pricesProvider = priceLocalSubscriber.subscribeToPrices(for: chainAssets, listener: self)
    }

    func subscribeToAccountInfo(for chainAssets: [ChainAsset]) {
        accountInfoSubscriptionAdapter.subscribe(
            chainsAssets: chainAssets,
            handler: self,
            deliveryOn: accountInfosDeliveryQueue
        )
    }
}
