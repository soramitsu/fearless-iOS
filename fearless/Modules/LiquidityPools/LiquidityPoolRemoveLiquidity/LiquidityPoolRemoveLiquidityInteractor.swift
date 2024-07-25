import UIKit
import SSFPools
import SSFPolkaswap
import SSFModels
import BigInt

protocol LiquidityPoolRemoveLiquidityInteractorOutput: AnyObject {
    func didReceivePricesData(result: Result<[PriceData], Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset)
    func didReceiveUserPool(pool: AccountPool?)
    func didReceiveUserPoolError(error: Error)
    func didReceiveFee(_ fee: BigUInt)
    func didReceiveFeeError(_ error: Error)
    func didReceivePoolReserves(reserves: PolkaswapPoolReservesInfo?)
    func didReceivePoolReservesError(error: Error)
    func didReceiveTotalIssuance(totalIssuance: BigUInt?)
    func didReceiveTotalIssuanceError(error: Error)
    func didReceiveTransactionHash(_ hash: String)
    func didReceiveSubmitError(error: Error)
}

final class LiquidityPoolRemoveLiquidityInteractor {
    // MARK: - Private properties

    private weak var output: LiquidityPoolRemoveLiquidityInteractorOutput?
    private let lpOperationService: PoolsOperationService
    private let lpDataService: PolkaswapLiquidityPoolService
    private let liquidityPair: LiquidityPair
    private let priceLocalSubscriber: PriceLocalStorageSubscriber
    private let chain: ChainModel
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let wallet: MetaAccountModel

    private var pricesProvider: AnySingleValueProvider<[PriceData]>?

    init(
        lpOperationService: PoolsOperationService,
        lpDataService: PolkaswapLiquidityPoolService,
        liquidityPair: LiquidityPair,
        priceLocalSubscriber: PriceLocalStorageSubscriber,
        chain: ChainModel,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        wallet: MetaAccountModel
    ) {
        self.lpOperationService = lpOperationService
        self.lpDataService = lpDataService
        self.liquidityPair = liquidityPair
        self.priceLocalSubscriber = priceLocalSubscriber
        self.chain = chain
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.wallet = wallet
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

    private func fetchReserves() {
        Task {
            do {
                let assetIdPair = AssetIdPair(baseAssetIdCode: liquidityPair.baseAssetId, targetAssetIdCode: liquidityPair.targetAssetId)
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

    private func fetchUserPool() {
        guard let accountId = wallet.fetch(for: chain.accountRequest())?.accountId else {
            output?.didReceiveUserPoolError(error: ChainAccountFetchingError.accountNotExists)
            return
        }

        Task {
            do {
                let assetIdPair = AssetIdPair(baseAssetIdCode: liquidityPair.baseAssetId, targetAssetIdCode: liquidityPair.targetAssetId)
                let accountPool = try await lpDataService.fetchUserPool(assetIdPair: assetIdPair, accountId: accountId)
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

    private func fetchTotalIssuance() {
        guard let reservesIdString = liquidityPair.reservesId else {
            return
        }

        let reservesId = Data(hex: reservesIdString)

        Task {
            do {
                let totalIssuance = try await lpDataService.fetchTotalIssuance(reservesId: reservesId)
                output?.didReceiveTotalIssuance(totalIssuance: totalIssuance)
            } catch {
                output?.didReceiveTotalIssuanceError(error: error)
            }
        }
    }
}

// MARK: - LiquidityPoolRemoveLiquidityInteractorInput

extension LiquidityPoolRemoveLiquidityInteractor: LiquidityPoolRemoveLiquidityInteractorInput {
    func setup(with output: LiquidityPoolRemoveLiquidityInteractorOutput) {
        self.output = output
        fetchReserves()
        fetchUserPool()
        fetchTotalIssuance()
        subscribeToPrices()
        subscribeToAccountInfo()
    }

    func estimateFee(removeLiquidityInfo: RemoveLiquidityInfo) {
        Task {
            do {
                let fee = try await lpOperationService.estimateFee(liquidityOperation: .substrateRemoveLiquidity(removeLiquidityInfo))
                output?.didReceiveFee(fee)
            } catch {
                output?.didReceiveFeeError(error)
            }
        }
    }

    func submit(removeLiquidityInfo: RemoveLiquidityInfo) {
        Task {
            do {
                let hash = try await lpOperationService.submit(liquidityOperation: .substrateRemoveLiquidity(removeLiquidityInfo))
                await MainActor.run {
                    output?.didReceiveTransactionHash(hash)
                }
            } catch {
                await MainActor.run {
                    output?.didReceiveSubmitError(error: error)
                }
            }
        }
    }
}

// MARK: - PriceLocalStorageSubscriber

extension LiquidityPoolRemoveLiquidityInteractor: PriceLocalSubscriptionHandler {
    func handlePrices(result: Result<[PriceData], Error>) {
        output?.didReceivePricesData(result: result)
    }
}

// MARK: - AccountInfoSubscriptionAdapterHandler

extension LiquidityPoolRemoveLiquidityInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainAsset: ChainAsset
    ) {
        output?.didReceiveAccountInfo(result: result, for: chainAsset)
    }
}
