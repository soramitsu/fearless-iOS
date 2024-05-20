import Foundation
import SSFPools
import SSFPolkaswap
import SSFModels
import SSFStorageQueryKit

protocol AvailableLiquidityPoolsListInteractorOutput {
    func didReceiveLiquidityPairs(pairs: [LiquidityPair]?)
    func didReceivePoolsReserves(reserves: CachedStorageResponse<[PolkaswapPoolReservesInfo]>)
    func didReceivePoolsAPY(apy: [PoolApyInfo]?)
    func didReceivePrices(result: Result<[PriceData], Error>)

    func didReceiveLiquidityPairsError(error: Error)
    func didReceivePoolsReservesError(error: Error)
    func didReceivePoolsApyError(error: Error)
}

final class AvailableLiquidityPoolsListInteractor {
    private let liquidityPoolService: PolkaswapLiquidityPoolService
    private var output: AvailableLiquidityPoolsListInteractorOutput?
    private let priceLocalSubscriber: PriceLocalStorageSubscriber
    private let chain: ChainModel
    private var priceProvider: AnySingleValueProvider<[PriceData]>?

    init(
        liquidityPoolService: PolkaswapLiquidityPoolService,
        priceLocalSubscriber: PriceLocalStorageSubscriber,
        chain: ChainModel
    ) {
        self.liquidityPoolService = liquidityPoolService
        self.priceLocalSubscriber = priceLocalSubscriber
        self.chain = chain
    }

    private func fetchReserves(pools: [LiquidityPair]) {
        Task {
            do {
                let reservesStream = try await liquidityPoolService.subscribePoolsReserves(pools: pools)

                for try await reserves in reservesStream {
                    await MainActor.run {
                        output?.didReceivePoolsReserves(reserves: reserves)
                    }
                }
            } catch {
                await MainActor.run {
                    output?.didReceivePoolsReservesError(error: error)
                }
            }
        }
    }

    private func subscribeForPrices() {
        let chainAssets = chain.chainAssets
        priceProvider = priceLocalSubscriber.subscribeToPrices(for: chainAssets, listener: self)
    }
}

extension AvailableLiquidityPoolsListInteractor: AvailableLiquidityPoolsListInteractorInput {
    func setup(with output: AvailableLiquidityPoolsListInteractorOutput) {
        self.output = output

        fetchPools()
        fetchApy()
        subscribeForPrices()
    }

    func fetchPools() {
        Task {
            do {
                let availablePoolsStream = try await liquidityPoolService.subscribeAvailablePools()

                for try await availablePools in availablePoolsStream {
                    await MainActor.run {
                        output?.didReceiveLiquidityPairs(pairs: availablePools.value)
                    }

                    if let pools = availablePools.value {
                        fetchReserves(pools: pools)
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
        Task {
            do {
                let apy = try await liquidityPoolService.fetchPoolsAPY()

                await MainActor.run {
                    output?.didReceivePoolsAPY(apy: apy)
                }
            } catch {
                await MainActor.run {
                    output?.didReceivePoolsApyError(error: error)
                }
            }
        }
    }
}

extension AvailableLiquidityPoolsListInteractor: PriceLocalSubscriptionHandler {
    func handlePrices(result: Result<[PriceData], Error>) {
        output?.didReceivePrices(result: result)
    }
}
