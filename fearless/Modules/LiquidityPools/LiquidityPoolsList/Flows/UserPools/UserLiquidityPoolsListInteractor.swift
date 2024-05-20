import Foundation
import SSFPools
import SSFPolkaswap
import SSFModels
import SSFStorageQueryKit

protocol UserLiquidityPoolsListInteractorOutput {
    func didReceiveLiquidityPairs(pools: [LiquidityPair]?)
    func didReceivePoolsReserves(reserves: CachedStorageResponse<[PolkaswapPoolReservesInfo]>?)
    func didReceivePoolsAPY(apy: [PoolApyInfo])
    func didReceiveUserPools(accountPools: [AccountPool]?)
    func didReceivePrices(result: Result<[PriceData], Error>)

    func didReceiveLiquidityPairsError(error: Error)
    func didReceivePoolsReservesError(error: Error)
    func didReceivePoolsApyError(error: Error)
    func didReceiveUserPoolsError(error: Error)
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

//    private func fetchReserves(pools: [AccountPool]) {
//        Task {
//            do {
//                let reservesStream = try await liquidityPoolService.subscribePoolsReserves(pools: pools)
//
//                for try await reserves in reservesStream {
//                    await MainActor.run {
//                        output?.didReceivePoolsReserves(reserves: reserves)
//                    }
//                }
//            } catch {
//                await MainActor.run {
//                    output?.didReceivePoolsReservesError(error: error)
//                }
//            }
//        }
//    }

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

    func fetchUserPools() {
        guard let accountId = wallet.fetch(for: chain.accountRequest())?.accountId else {
            output?.didReceiveLiquidityPairsError(error: ChainAccountFetchingError.accountNotExists)
            return
        }

        Task {
            do {
                let accountPools = try await liquidityPoolService.fetchUserPools(accountId: accountId)
                await MainActor.run {
                    output?.didReceiveUserPools(accountPools: accountPools)
                }

//                if let pools = accountPools {
//                    fetchReserves(pools: pools)
//                }
            } catch {
                await MainActor.run {
                    output?.didReceiveUserPoolsError(error: error)
                }
            }
        }
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
                        output?.didReceiveLiquidityPairs(pools: userPools.value)
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
