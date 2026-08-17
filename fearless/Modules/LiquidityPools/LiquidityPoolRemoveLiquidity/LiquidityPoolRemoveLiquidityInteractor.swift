import UIKit
import SSFPools
import SSFPolkaswap
import SSFModels
import BigInt

protocol LiquidityPoolRemoveLiquidityInteractorOutput: AnyObject {
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
    private let chain: ChainModel
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let wallet: MetaAccountModel

    init(
        lpOperationService: PoolsOperationService,
        lpDataService: PolkaswapLiquidityPoolService,
        liquidityPair: LiquidityPair,
        chain: ChainModel,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        wallet: MetaAccountModel
    ) {
        self.lpOperationService = lpOperationService
        self.lpDataService = lpDataService
        self.liquidityPair = liquidityPair
        self.chain = chain
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.wallet = wallet
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

                for await reserves in reservesStream {
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

        guard let reservesId = try? Data(hexStringSSF: reservesIdString) else {
            output?.didReceiveTotalIssuanceError(error: CommonError.internal)
            return
        }

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
        guard MultiChainFeaturePolicy.current.polkaswapMutationsEnabled else {
            output?.didReceiveSubmitError(
                error: NSError(
                    domain: "jp.co.soramitsu.fearless.liquidity",
                    code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Liquidity actions are temporarily disabled by the remote safety switch."
                    ]
                )
            )
            return
        }
        guard ReviewedLiquidityPoolExecutionAuthority.allowsSubmission(remoteEnabled: true) else {
            output?.didReceiveSubmitError(
                error: NSError(
                    domain: "jp.co.soramitsu.fearless.liquidity",
                    code: 2,
                    userInfo: [
                        NSLocalizedDescriptionKey: ReviewedLiquidityPoolExecutionAuthority.unavailableReason
                    ]
                )
            )
            return
        }
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
