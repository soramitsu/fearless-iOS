import UIKit
import SSFModels

protocol ReceiveAndRequestAssetInteractorOutput: AnyObject {
    func didReceivePricesData(result: Result<[PriceData], Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset)
}

final class ReceiveAndRequestAssetInteractor {
    // MARK: - Private properties

    private weak var output: ReceiveAndRequestAssetInteractorOutput?

    private let priceLocalSubscriber: PriceLocalStorageSubscriber
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let chainAsset: ChainAsset

    private var pricesProvider: AnySingleValueProvider<[PriceData]>?

    init(
        priceLocalSubscriber: PriceLocalStorageSubscriber,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        chainAsset: ChainAsset
    ) {
        self.priceLocalSubscriber = priceLocalSubscriber
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.chainAsset = chainAsset
    }

    // MARK: - Private methods

    private func subscribeToAccountInfo(for chainAssets: [ChainAsset]) {
        accountInfoSubscriptionAdapter.subscribe(
            chainsAssets: chainAssets,
            handler: self,
            deliveryOn: .main
        )
    }

    private func subscribeToPrices(for chainAssets: [ChainAsset]) {
        guard chainAssets.isNotEmpty else {
            output?.didReceivePricesData(result: .success([]))
            return
        }
        pricesProvider = try? priceLocalSubscriber.subscribeToPrices(for: chainAssets, listener: self)
    }
}

// MARK: - ReceiveAndRequestAssetInteractorInput

extension ReceiveAndRequestAssetInteractor: ReceiveAndRequestAssetInteractorInput {
    func setup(with output: ReceiveAndRequestAssetInteractorOutput) {
        self.output = output

        guard chainAsset.chain.isSora else {
            return
        }
        subscribeToPrices(for: chainAsset.chain.chainAssets)
        subscribeToAccountInfo(for: chainAsset.chain.chainAssets)
    }
}

// MARK: - AccountInfoSubscriptionAdapterHandler

extension ReceiveAndRequestAssetInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainAsset: ChainAsset
    ) {
        output?.didReceiveAccountInfo(result: result, for: chainAsset)
    }
}

// MARK: - PriceLocalStorageSubscriber

extension ReceiveAndRequestAssetInteractor: PriceLocalSubscriptionHandler {
    func handlePrices(result: Result<[PriceData], Error>) {
        output?.didReceivePricesData(result: result)
    }
}
