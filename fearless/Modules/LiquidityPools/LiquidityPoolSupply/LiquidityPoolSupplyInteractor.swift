import UIKit
import SSFPools
import SSFPolkaswap
import SSFModels
import BigInt

protocol LiquidityPoolSupplyInteractorOutput: AnyObject {
    func didReceiveDexId(_ dexId: String)
    func didReceiveDexIdError(_ error: Error)
    func didReceiveFee(_ fee: BigUInt)
    func didReceiveFeeError(_ error: Error)
    func didReceivePricesData(result: Result<[PriceData], Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset)
}

final class LiquidityPoolSupplyInteractor {
    // MARK: - Private properties

    private weak var output: LiquidityPoolSupplyInteractorOutput?
    private let lpOperationService: PoolsOperationService
    private let lpDataService: PolkaswapLiquidityPoolService
    private let liquidityPair: LiquidityPair
    private let priceLocalSubscriber: PriceLocalStorageSubscriber
    private let chain: ChainModel
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol

    private var pricesProvider: AnySingleValueProvider<[PriceData]>?

    init(
        lpOperationService: PoolsOperationService,
        lpDataService: PolkaswapLiquidityPoolService,
        liquidityPair: LiquidityPair,
        priceLocalSubscriber: PriceLocalStorageSubscriber,
        chain: ChainModel,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    ) {
        self.lpOperationService = lpOperationService
        self.lpDataService = lpDataService
        self.liquidityPair = liquidityPair
        self.priceLocalSubscriber = priceLocalSubscriber
        self.chain = chain
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
    }

    private func fetchDexId() {
        Task {
            do {
                let dexId = try await lpDataService.fetchDexId(baseAssetId: liquidityPair.baseAssetId)
                output?.didReceiveDexId(dexId)
            } catch {
                output?.didReceiveDexIdError(error)
            }
        }
    }

    private func subscribeToPrices() {
        let chainAssets = chain.chainAssets
        pricesProvider = priceLocalSubscriber.subscribeToPrices(for: chainAssets, listener: self)

        guard chainAssets.isNotEmpty else {
            output?.didReceivePricesData(result: .success([]))
            return
        }
        pricesProvider = priceLocalSubscriber.subscribeToPrices(for: chainAssets, listener: self)
    }

    private func subscribeToAccountInfo() {
        let chainAssets = chain.chainAssets
        accountInfoSubscriptionAdapter.subscribe(
            chainsAssets: chainAssets,
            handler: self,
            deliveryOn: .main
        )
    }
}

// MARK: - LiquidityPoolSupplyInteractorInput

extension LiquidityPoolSupplyInteractor: LiquidityPoolSupplyInteractorInput {
    func setup(with output: LiquidityPoolSupplyInteractorOutput) {
        self.output = output
        fetchDexId()
        subscribeToPrices()
        subscribeToAccountInfo()
    }

    func estimateFee(supplyLiquidityInfo: SupplyLiquidityInfo) {
        Task {
            do {
                let fee = try await lpOperationService.estimateFee(liquidityOperation: .substrateSupplyLiquidity(supplyLiquidityInfo))
                output?.didReceiveFee(fee)
            } catch {
                output?.didReceiveFeeError(error)
            }
        }
    }
}

// MARK: - PriceLocalStorageSubscriber

extension LiquidityPoolSupplyInteractor: PriceLocalSubscriptionHandler {
    func handlePrices(result: Result<[PriceData], Error>) {
        output?.didReceivePricesData(result: result)
    }
}

// MARK: - AccountInfoSubscriptionAdapterHandler

extension LiquidityPoolSupplyInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainAsset: ChainAsset
    ) {
        output?.didReceiveAccountInfo(result: result, for: chainAsset)
    }
}
