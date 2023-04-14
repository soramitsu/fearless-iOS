import UIKit
import SSFXCM

protocol CrossChainInteractorOutput: AnyObject {
    func didReceiveAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId: AccountId,
        chainAsset: ChainAsset
    )
    func didReceivePricesData(
        result: Result<PriceData?, Error>,
        priceId: AssetModel.PriceId?
    )
    func didReceiveAvailableDestChainAssets(_ chainAssets: [ChainAsset])
    func didReceiveFee(result: Result<XcmFeeResponse, Error>)
}

final class CrossChainInteractor {
    internal let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol

    // MARK: - Private properties

    private weak var output: CrossChainInteractorOutput?

    private let chainAssetFetching: ChainAssetFetchingProtocol
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let xcmFeeService: XcmFeeFetching
    private var pricesProvider: AnySingleValueProvider<[PriceData]>?

    init(
        chainAssetFetching: ChainAssetFetchingProtocol,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        xcmFeeService: XcmFeeFetching
    ) {
        self.chainAssetFetching = chainAssetFetching
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.xcmFeeService = xcmFeeService
    }

    // MARK: - Private methods

    private func subscribeToAccountInfo(for chainAssets: [ChainAsset]) {
        accountInfoSubscriptionAdapter.subscribe(
            chainsAssets: chainAssets,
            handler: self,
            deliveryOn: .main
        )
    }

    private func fetchPrices(for chainAssets: [ChainAsset]) {
        let pricesIds = chainAssets.compactMap(\.asset.priceId).uniq(predicate: { $0 })
        guard pricesIds.isNotEmpty else {
            output?.didReceivePricesData(result: .success(nil), priceId: nil)
            return
        }
        pricesProvider = subscribeToPrices(for: pricesIds)
    }

    private func getAvailableDestChainAssets(for _: ChainAsset) {
        chainAssetFetching.fetch(
            filters: [ /* .assetName(chainAsset.asset.name) */ ],
            sortDescriptors: []
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case let .success(availableChainAssets):
                    self?.output?.didReceiveAvailableDestChainAssets(availableChainAssets)
                default:
                    self?.output?.didReceiveAvailableDestChainAssets([])
                }
            }
        }
    }
}

// MARK: - CrossChainInteractorInput

extension CrossChainInteractor: CrossChainInteractorInput {
    func setup(with output: CrossChainInteractorOutput) {
        self.output = output
    }

    func didReceive(originalChainAsset: ChainAsset?, destChainAsset: ChainAsset?) {
        let chainAssets: [ChainAsset] = [originalChainAsset, destChainAsset].compactMap { $0 }
        fetchPrices(for: chainAssets)
        subscribeToAccountInfo(for: chainAssets)
        guard let originalChainAsset = originalChainAsset else {
            return
        }
        getAvailableDestChainAssets(for: originalChainAsset)

        guard let destinationChainAsset = destChainAsset else {
            return
        }

        estimateFee(originalChainId: originalChainAsset.chain.chainId, destinationChainId: destinationChainAsset.chain.chainId)
    }

    func estimateFee(originalChainId: String, destinationChainId: String) {
        xcmFeeService.estimateFee(
            originChainId: originalChainId,
            destinationChainId: destinationChainId
        ) { [weak self] result in
            self?.output?.didReceiveFee(result: result)
        }
    }
}

// MARK: - AccountInfoSubscriptionAdapterHandler

extension CrossChainInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId: AccountId,
        chainAsset: ChainAsset
    ) {
        output?.didReceiveAccountInfo(
            result: result,
            accountId: accountId,
            chainAsset: chainAsset
        )
    }
}

// MARK: - PriceLocalStorageSubscriber

extension CrossChainInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(
        result: Result<PriceData?, Error>,
        priceId: AssetModel.PriceId
    ) {
        output?.didReceivePricesData(
            result: result,
            priceId: priceId
        )
    }
}
