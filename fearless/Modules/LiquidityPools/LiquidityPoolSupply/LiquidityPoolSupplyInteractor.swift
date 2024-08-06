import UIKit
import SSFPools
import SSFPolkaswap
import SSFModels
import BigInt
import SSFStorageQueryKit

protocol LiquidityPoolSupplyInteractorOutput: AnyObject {
    func didReceiveFee(_ fee: BigUInt)
    func didReceiveFeeError(_ error: Error)
    func didReceivePricesData(result: Result<[PriceData], Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset)
    func didReceivePoolAPY(apyInfo: PoolApyInfo?)
    func didReceivePoolApyError(error: Error)
    func didReceiveLiquidityPairs(pairs: [LiquidityPair]?)
    func didReceiveLiquidityPairsError(error: Error)
    func didReceivePoolReserves(reserves: PolkaswapPoolReservesInfo?)
    func didReceivePoolReservesError(error: Error)
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

    private func subscribeToPrices() {
        let chainAssets = chain.chainAssets
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
        subscribeToPrices()
        subscribeToAccountInfo()
        fetchApy()
        fetchReserves()
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

    func fetchPools() {
        Task {
            do {
                let availablePoolsStream = try await lpDataService.subscribeAvailablePools()

                for try await availablePools in availablePoolsStream {
                    await MainActor.run {
                        output?.didReceiveLiquidityPairs(pairs: availablePools.value)
                    }
                }
            } catch {
                await MainActor.run {
                    output?.didReceiveLiquidityPairsError(error: error)
                }
            }
        }
    }

    func fetchApy() {
        guard let reservesId = liquidityPair.reservesId else {
            return
        }

        Task {
            let address = try AddressFactory.address(for: Data(hex: reservesId), chain: chain)
            let apyStream = try await lpDataService.subscribePoolsAPY(poolIds: [address])
            do {
                for try await apy in apyStream {
                    await MainActor.run {
                        output?.didReceivePoolAPY(apyInfo: apy.first(where: { $0.value?.poolId == address })?.value)
                    }
                }
            } catch {
                await MainActor.run {
                    output?.didReceivePoolApyError(error: error)
                }
            }
        }
    }

    private func fetchReserves() {
        let assetIdPair = AssetIdPair(baseAssetIdCode: liquidityPair.baseAssetId, targetAssetIdCode: liquidityPair.targetAssetId)

        Task {
            do {
                let reservesStream = try await lpDataService.subscribePoolReserves(assetIdPair: assetIdPair)

                for try await reserves in reservesStream {
                    await MainActor.run {
                        output?.didReceivePoolReserves(reserves: reserves.value)
                    }
                }
            } catch {
                await MainActor.run {
                    output?.didReceivePoolReservesError(error: error)
                }
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
