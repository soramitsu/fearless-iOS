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

    private var receivedPoolIds: [String] = []

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
        fetchUserPools()
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
                    print("received fetch pool response")
                    await MainActor.run {
                        output?.didReceiveLiquidityPairs(pools: userPools.value)
                    }

                    if let pools = userPools.value {
                        fetchApy(pools: pools)
                    }
                }
            } catch {
                output?.didReceiveLiquidityPairsError(error: error)
            }
        }
    }

    func fetchApy(pools: [LiquidityPair]) {
        let poolIds: [String] = pools.compactMap {
            guard
                let reservesId = $0.reservesId,
                let address = try? AddressFactory.address(for: Data(hex: reservesId), chain: chain)
            else {
                return nil
            }

            return address
        }

        guard poolIds != receivedPoolIds else {
            return
        }

        Task {
            let apyStream = try await liquidityPoolService.subscribePoolsAPY(poolIds: poolIds)
            do {
                for try await apy in apyStream {
                    if apy.first?.type == .remote {
                        receivedPoolIds.append(contentsOf: apy.compactMap { $0.value?.poolId })
                    }

                    await MainActor.run {
                        output?.didReceivePoolsAPY(apy: apy.compactMap { $0.value })
                    }
                }
            } catch {
                await MainActor.run {
                    output?.didReceivePoolsApyError(error: error)
                }
            }
        }
    }
}

extension UserLiquidityPoolsListInteractor: PriceLocalSubscriptionHandler {
    func handlePrices(result: Result<[PriceData], Error>) {
        output?.didReceivePrices(result: result)
    }
}
