import UIKit
import SSFModels
import SSFPolkaswap
import SSFPools
import BigInt

protocol LiquidityPoolSupplyConfirmInteractorOutput: AnyObject {
    func didReceiveFee(_ fee: BigUInt)
    func didReceiveFeeError(_ error: Error)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset)
    func didReceivePoolAPY(apyInfo: PoolApyInfo?)
    func didReceivePoolApyError(error: Error)
    func didReceiveTransactionHash(_ hash: String)
    func didReceiveSubmitError(error: Error)
}

final class LiquidityPoolSupplyConfirmInteractor {
    // MARK: - Private properties

    private weak var output: LiquidityPoolSupplyConfirmInteractorOutput?
    private let lpOperationService: PoolsOperationService
    private let lpDataService: PolkaswapLiquidityPoolService
    private let liquidityPair: LiquidityPair
    private let chain: ChainModel
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol

    init(
        lpOperationService: PoolsOperationService,
        lpDataService: PolkaswapLiquidityPoolService,
        liquidityPair: LiquidityPair,
        chain: ChainModel,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    ) {
        self.lpOperationService = lpOperationService
        self.lpDataService = lpDataService
        self.liquidityPair = liquidityPair
        self.chain = chain
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
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

// MARK: - LiquidityPoolSupplyConfirmInteractorInput

extension LiquidityPoolSupplyConfirmInteractor: LiquidityPoolSupplyConfirmInteractorInput {
    func setup(with output: LiquidityPoolSupplyConfirmInteractorOutput) {
        self.output = output
        fetchApy()
        subscribeToAccountInfo()
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

    func submit(supplyLiquidityInfo: SupplyLiquidityInfo) {
        Task {
            do {
                let hash = try await lpOperationService.submit(liquidityOperation: .substrateSupplyLiquidity(supplyLiquidityInfo))
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
}

// MARK: - AccountInfoSubscriptionAdapterHandler

extension LiquidityPoolSupplyConfirmInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainAsset: ChainAsset
    ) {
        output?.didReceiveAccountInfo(result: result, for: chainAsset)
    }
}
