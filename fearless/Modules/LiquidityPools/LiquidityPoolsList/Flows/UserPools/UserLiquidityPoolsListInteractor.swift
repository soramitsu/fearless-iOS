import Foundation
import SSFPools
import SSFPolkaswap
import SSFModels
import SSFStorageQueryKit

protocol UserLiquidityPoolsListInteractorOutput {
    func didReceiveUserPools(pools: [LiquidityPair]?)
    func didReceivePoolsReserves(reserves: CachedStorageResponse<[PolkaswapPoolReservesInfo]>?)
    func didReceivePoolsAPY(apy: [PoolApyInfo])
    func didReceivePrices(result: Result<[PriceData], Error>)

    func didReceiveLiquidityPairsError(error: Error)
    func didReceivePoolsReservesError(error: Error)
    func didReceivePoolsApyError(error: Error)
}

final class UserLiquidityPoolsListInteractor {
    private let liquidityPoolService: PolkaswapLiquidityPoolService
    private var output: UserLiquidityPoolsListInteractorOutput?
    private let priceLocalSubscriber: PriceLocalStorageSubscriber
    private let chain: ChainModel
    private let wallet: MetaAccountModel
    private var priceProvider: AnySingleValueProvider<[PriceData]>?

    init(
        liquidityPoolService: PolkaswapLiquidityPoolService,
        priceLocalSubscriber: PriceLocalStorageSubscriber,
        chain: ChainModel,
        wallet: MetaAccountModel
    ) {
        self.liquidityPoolService = liquidityPoolService
        self.priceLocalSubscriber = priceLocalSubscriber
        self.chain = chain
        self.wallet = wallet
    }

    private func subscribeForPrices() {
        let chainAssets = chain.chainAssets
        priceProvider = priceLocalSubscriber.subscribeToPrices(for: chainAssets, listener: self)
    }
}

extension UserLiquidityPoolsListInteractor: UserLiquidityPoolsListInteractorInput {
    func setup(with output: UserLiquidityPoolsListInteractorOutput) {
        self.output = output

        fetchPools()
        fetchApy()
        subscribeForPrices()
    }

    func fetchPools() {
        guard let accountId = wallet.fetch(for: chain.accountRequest())?.accountId else {
            output?.didReceiveLiquidityPairsError(error: ChainAccountFetchingError.accountNotExists)
            return
        }
        Task {
            do {
                let userPoolsStream = try await liquidityPoolService.subscribeUserPools(accountId: accountId)

                for try await userPools in userPoolsStream {
                    await MainActor.run {
                        output?.didReceiveUserPools(pools: userPools.value)
                    }
                }
            } catch {
                output?.didReceiveLiquidityPairsError(error: error)
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
                output?.didReceivePoolsApyError(error: error)
            }
        }
    }
}

extension UserLiquidityPoolsListInteractor: PriceLocalSubscriptionHandler {
    func handlePrices(result: Result<[PriceData], Error>) {
        output?.didReceivePrices(result: result)
    }
}
