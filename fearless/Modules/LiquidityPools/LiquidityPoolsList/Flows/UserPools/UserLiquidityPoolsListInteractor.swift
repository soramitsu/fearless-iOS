import Foundation
import SSFPools
import SSFPolkaswap
import SSFModels
import SSFStorageQueryKit

protocol UserLiquidityPoolsListInteractorOutput: AnyObject {
    func didReceiveLiquidityPairs(pools: [LiquidityPair]?)
    func didReceivePoolsReserves(reserves: CachedStorageResponse<[PolkaswapPoolReservesInfo]>?)
    func didReceivePoolsAPY(apy: [PoolApyInfo])
    func didReceiveUserPools(accountPools: [AccountPool]?)

    func didReceiveLiquidityPairsError(error: Error)
    func didReceivePoolsReservesError(error: Error)
    func didReceivePoolsApyError(error: Error)
    func didReceiveUserPoolsError(error: Error)
}

final class UserLiquidityPoolsListInteractor {
    private let liquidityPoolService: PolkaswapLiquidityPoolService
    private weak var output: UserLiquidityPoolsListInteractorOutput?
    private let chain: ChainModel
    private let wallet: MetaAccountModel

    private var receivedPoolIds: [String] = []

    private var poolsTask: Task<Void, Never>?
    private var apyTask: Task<Void, Never>?

    init(
        liquidityPoolService: PolkaswapLiquidityPoolService,
        chain: ChainModel,
        wallet: MetaAccountModel
    ) {
        self.liquidityPoolService = liquidityPoolService
        self.chain = chain
        self.wallet = wallet
    }
}

extension UserLiquidityPoolsListInteractor: UserLiquidityPoolsListInteractorInput {
    func setup(with output: UserLiquidityPoolsListInteractorOutput) {
        self.output = output
    }

    func cancelTasks() {
        [poolsTask, apyTask].compactMap { $0 }.forEach { $0.cancel() }
    }

    func fetchPools() {
        guard let accountId = wallet.fetch(for: chain.accountRequest())?.accountId else {
            output?.didReceiveLiquidityPairsError(error: ChainAccountFetchingError.accountNotExists)
            return
        }

        poolsTask = Task {
            do {
                let userPoolsStream = try await liquidityPoolService.subscribeUserPools(accountId: accountId)

                for try await userPools in userPoolsStream {
                    await MainActor.run {
                        output?.didReceiveUserPools(accountPools: userPools.value)
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

    func fetchApy(pools: [AccountPool]) {
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

        apyTask = Task {
            do {
                let apyStream = try await liquidityPoolService.subscribePoolsAPY(poolIds: poolIds)
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
