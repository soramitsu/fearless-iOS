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
    func didReceivePrices(result: Result<[PriceData], Error>)

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
    private let priceLocalSubscriber: PriceLocalStorageSubscriber
    private var priceProvider: AnySingleValueProvider<[PriceData]>?

    init(
        assetIdPair: AssetIdPair,
        chain: ChainModel,
        wallet: MetaAccountModel,
        liquidityPoolService: PolkaswapLiquidityPoolService,
        priceLocalSubscriber: PriceLocalStorageSubscriber
    ) {
        self.assetIdPair = assetIdPair
        self.chain = chain
        self.wallet = wallet
        self.liquidityPoolService = liquidityPoolService
        self.priceLocalSubscriber = priceLocalSubscriber
    }

    private func subscribeForPrices() {
        let chainAssets = chain.chainAssets
        priceProvider = priceLocalSubscriber.subscribeToPrices(for: chainAssets, listener: self)
    }
}

// MARK: - LiquidityPoolDetailsInteractorInput

extension LiquidityPoolDetailsInteractor: LiquidityPoolDetailsInteractorInput {
    func setup(with output: LiquidityPoolDetailsInteractorOutput) {
        self.output = output

        fetchPoolInfo()
        fetchUserPool()
        fetchReserves()
        subscribeForPrices()
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
                let accountPool = try await liquidityPoolService.fetchUserPool(assetIdPair: assetIdPair, accountId: accountId)
                await MainActor.run {
                    output?.didReceiveUserPool(pool: accountPool)
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
            do {
                let apy = try await liquidityPoolService.fetchPoolsAPY()
                let address = try AddressFactory.address(for: Data(hex: reservesId), chain: chain)
                await MainActor.run {
                    output?.didReceivePoolAPY(apy: apy.first(where: { $0.poolId == address }))
                }
            } catch {
                await MainActor.run {
                    output?.didReceivePoolApyError(error: error)
                }
            }
        }
    }
}

extension LiquidityPoolDetailsInteractor: PriceLocalSubscriptionHandler {
    func handlePrices(result: Result<[PriceData], Error>) {
        output?.didReceivePrices(result: result)
    }
}
