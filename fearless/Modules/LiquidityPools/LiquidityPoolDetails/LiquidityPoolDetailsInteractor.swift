import UIKit
import SSFModels
import SSFPolkaswap
import SSFPools
import SSFStorageQueryKit

protocol LiquidityPoolDetailsInteractorOutput: AnyObject {
    func didReceiveLiquidityPair(liquidityPair: LiquidityPair?)
    func didReceiveUserPool(pool: AccountPool?)
    func didReceivePoolReserves(reserves: CachedStorageResponse<PolkaswapPoolReservesInfo>?)
    func didReceivePoolAPY(apy: PoolApyInfo?)

    func didReceiveLiquidityPairError(error: Error)
    func didReceiveUserPoolError(error: Error)
    func didReceivePoolReservesError(error: Error)
    func didReceivePoolApyError(error: Error)
}

final class LiquidityPoolDetailsInteractor {
    // MARK: - Private properties

    private weak var output: LiquidityPoolDetailsInteractorOutput?

    private let assetIdPair: AssetIdPair
    private let chain: ChainModel
    private let wallet: MetaAccountModel
    private let liquidityPoolService: PolkaswapLiquidityPoolService

    init(
        assetIdPair: AssetIdPair,
        chain: ChainModel,
        wallet: MetaAccountModel,
        liquidityPoolService: PolkaswapLiquidityPoolService
    ) {
        self.assetIdPair = assetIdPair
        self.chain = chain
        self.wallet = wallet
        self.liquidityPoolService = liquidityPoolService
    }
}

// MARK: - LiquidityPoolDetailsInteractorInput

extension LiquidityPoolDetailsInteractor: LiquidityPoolDetailsInteractorInput {
    func setup(with output: LiquidityPoolDetailsInteractorOutput) {
        self.output = output

        fetchPoolInfo()
        fetchUserPool()
        fetchReserves()
    }

    func fetchPoolInfo() {
        Task {
            do {
                let poolStream = try await liquidityPoolService.subscribeLiquidityPool(assetIdPair: assetIdPair)

                for try await pool in poolStream {
                    await MainActor.run {
                        output?.didReceiveLiquidityPair(liquidityPair: pool.value)
                    }

                    if let reservesId = pool.value?.reservesId {
                        fetchApy(reservesId: reservesId)
                    }
                }
            } catch {
                await MainActor.run {
                    output?.didReceiveLiquidityPairError(error: error)
                }
            }
        }
    }

    func fetchUserPool() {
        guard let accountId = wallet.fetch(for: chain.accountRequest())?.accountId else {
            output?.didReceiveUserPoolError(error: ChainAccountFetchingError.accountNotExists)
            return
        }

        Task {
            do {
                let accountPoolStream = try await liquidityPoolService.subscribeUserPools(accountId: accountId)
                for try await accountPools in accountPoolStream {
                    guard let pool = accountPools.value?.first(where: { $0.poolId == assetIdPair.poolId }) else {
                        return
                    }

                    await MainActor.run {
                        output?.didReceiveUserPool(pool: pool)
                    }
                }
            } catch {
                await MainActor.run {
                    output?.didReceiveUserPoolError(error: error)
                }
            }
        }
    }

    private func fetchReserves() {
        Task {
            do {
                let reservesStream = try await liquidityPoolService.subscribePoolReserves(assetIdPair: assetIdPair)

                for try await reserves in reservesStream {
                    await MainActor.run {
                        output?.didReceivePoolReserves(reserves: reserves)
                    }
                }
            } catch {
                await MainActor.run {
                    output?.didReceivePoolReservesError(error: error)
                }
            }
        }
    }

    func fetchApy(reservesId: String) {
        Task {
            let address = try AddressFactory.address(for: Data(hex: reservesId), chain: chain)
            let apyStream = try await liquidityPoolService.subscribePoolsAPY(poolIds: [address])
            do {
                for try await apy in apyStream {
                    await MainActor.run {
                        output?.didReceivePoolAPY(apy: apy.first(where: { $0.value?.poolId == address })?.value)
                    }
                }
            } catch {
                await MainActor.run {
                    output?.didReceivePoolApyError(error: error)
                }
            }
        }
    }
}
