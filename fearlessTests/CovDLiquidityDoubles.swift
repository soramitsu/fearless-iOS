import BigInt
import Foundation
import SSFModels
import SSFPolkaswap
import SSFPools
import UIKit

@testable import fearless

/// Records router calls that are dynamically dispatched (protocol requirements).
class CovDRouterSpy: SheetAlertPresentable, AnyDismissable, AllDonePresentable {
    private(set) var infoTitles: [String] = []
    private(set) var alertTitles: [String] = []
    private(set) var dismissCount = 0
    private(set) var errors: [String] = []
    private(set) var doneHashes: [String] = []

    func present(viewModel: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) {
        alertTitles.append(viewModel.title)
    }

    func present(
        message _: String?,
        title: String,
        closeAction _: String?,
        from _: ControllerBackedProtocol?,
        actions _: [SheetAlertPresentableAction]
    ) {
        alertTitles.append(title)
    }

    func presentInfo(message _: String?, title: String, from _: ControllerBackedProtocol?) {
        infoTitles.append(title)
    }

    func dismiss(view _: ControllerBackedProtocol?) {
        dismissCount += 1
    }

    @discardableResult
    func present(error: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        errors.append(error.localizedDescription)
        return true
    }

    func presentDone(
        chainAsset _: ChainAsset,
        title _: String?,
        description _: String?,
        extrinsicHash: String,
        from _: ControllerBackedProtocol,
        closure _: (() -> Void)?
    ) {
        doneHashes.append(extrinsicHash)
    }
}

final class CovDSupplyRouterSpy: CovDRouterSpy, LiquidityPoolSupplyRouterInput {
    private(set) var confirmations: [LiquidityPoolSupplyConfirmInputData] = []
    private(set) var selectAssetCount = 0

    func showSelectAsset(
        from _: ControllerBackedProtocol?,
        wallet _: MetaAccountModel,
        chainAssets _: [ChainAsset]?,
        selectedAssetId _: AssetModel.Id?,
        contextTag _: Int?,
        output _: SelectAssetModuleOutput
    ) {
        selectAssetCount += 1
    }

    func showConfirmation(
        chain _: ChainModel,
        wallet _: MetaAccountModel,
        liquidityPair _: LiquidityPair,
        inputData: LiquidityPoolSupplyConfirmInputData,
        didSubmitTransactionClosure _: @escaping (String) -> Void,
        from _: ControllerBackedProtocol?
    ) {
        confirmations.append(inputData)
    }
}

final class CovDRemoveRouterSpy: CovDRouterSpy, LiquidityPoolRemoveLiquidityRouterInput {
    private(set) var confirmations: [RemoveLiquidityInfo] = []
    private(set) var completions: [String] = []

    func showConfirmation(
        chain _: ChainModel,
        wallet _: MetaAccountModel,
        liquidityPair _: LiquidityPair,
        info: RemoveLiquidityInfo,
        didSubmitTransactionClosure _: @escaping (String) -> Void,
        from _: ControllerBackedProtocol?
    ) {
        confirmations.append(info)
    }

    func complete(on _: ControllerBackedProtocol?, title: String, chainAsset _: ChainAsset) {
        completions.append(title)
    }
}

final class CovDSupplyConfirmRouterSpy: CovDRouterSpy, LiquidityPoolSupplyConfirmRouterInput {
    private(set) var completions: [String] = []

    func complete(on _: ControllerBackedProtocol?, title: String, chainAsset _: ChainAsset) {
        completions.append(title)
    }
}

final class CovDDetailsRouterSpy: CovDRouterSpy, LiquidityPoolDetailsRouterInput {
    private(set) var supplyPairs: [String] = []
    private(set) var removePairs: [String] = []

    func showSupplyFlow(
        liquidityPair: LiquidityPair,
        chain _: ChainModel,
        wallet _: MetaAccountModel,
        availablePairs _: [LiquidityPair]?,
        didSubmitTransactionClosure _: @escaping (String) -> Void,
        from _: ControllerBackedProtocol?
    ) {
        supplyPairs.append(liquidityPair.pairId)
    }

    func showRemoveFlow(
        liquidityPair: LiquidityPair,
        chain _: ChainModel,
        wallet _: MetaAccountModel,
        didSubmitTransactionClosure _: @escaping (String) -> Void,
        from _: ControllerBackedProtocol?
    ) {
        removePairs.append(liquidityPair.pairId)
    }
}

final class CovDSupplyInteractorSpy: LiquidityPoolSupplyInteractorInput {
    private(set) weak var output: LiquidityPoolSupplyInteractorOutput?
    private(set) var feeRequests: [SupplyLiquidityInfo] = []
    private(set) var fetchPoolsCount = 0

    func setup(with output: LiquidityPoolSupplyInteractorOutput) { self.output = output }
    func estimateFee(supplyLiquidityInfo: SupplyLiquidityInfo) { feeRequests.append(supplyLiquidityInfo) }
    func fetchPools() { fetchPoolsCount += 1 }
}

final class CovDRemoveInteractorSpy: LiquidityPoolRemoveLiquidityInteractorInput {
    private(set) weak var output: LiquidityPoolRemoveLiquidityInteractorOutput?
    private(set) var setupCount = 0
    private(set) var feeRequests: [RemoveLiquidityInfo] = []
    private(set) var submissions: [RemoveLiquidityInfo] = []

    func setup(with output: LiquidityPoolRemoveLiquidityInteractorOutput) {
        setupCount += 1
        self.output = output
    }

    func estimateFee(removeLiquidityInfo: RemoveLiquidityInfo) { feeRequests.append(removeLiquidityInfo) }
    func submit(removeLiquidityInfo: RemoveLiquidityInfo) { submissions.append(removeLiquidityInfo) }
}

final class CovDSupplyConfirmInteractorSpy: LiquidityPoolSupplyConfirmInteractorInput {
    private(set) weak var output: LiquidityPoolSupplyConfirmInteractorOutput?
    private(set) var feeRequests: [SupplyLiquidityInfo] = []
    private(set) var submissions: [SupplyLiquidityInfo] = []

    func setup(with output: LiquidityPoolSupplyConfirmInteractorOutput) { self.output = output }
    func estimateFee(supplyLiquidityInfo: SupplyLiquidityInfo) { feeRequests.append(supplyLiquidityInfo) }
    func submit(supplyLiquidityInfo: SupplyLiquidityInfo) { submissions.append(supplyLiquidityInfo) }
}

final class CovDDetailsInteractorSpy: LiquidityPoolDetailsInteractorInput {
    private(set) weak var output: LiquidityPoolDetailsInteractorOutput?

    func setup(with output: LiquidityPoolDetailsInteractorOutput) { self.output = output }
}

enum CovDLiquidityFixtures {
    static let xor = CovDFixtures.xorAssetId
    static let val = CovDFixtures.valAssetId
    static let pswap = CovDFixtures.pswapAssetId

    /// XOR (utility), VAL and PSWAP with currency ids and exact cached USD prices.
    static func chain(chainId: String = "covd-lp-\(UUID().uuidString)") -> ChainModel {
        let suffix = UUID().uuidString
        ExactAssetPriceCache.shared.upsert([
            CovDFixtures.price("3", priceId: "covd-xor-\(suffix)"),
            CovDFixtures.price("2", priceId: "covd-val-\(suffix)"),
            CovDFixtures.price("0.5", priceId: "covd-pswap-\(suffix)")
        ])
        return CovDFixtures.soraChain(chainId: chainId, assets: [
            CovDFixtures.asset(id: "xor", symbol: "XOR", currencyId: xor, priceId: "covd-xor-\(suffix)", isUtility: true),
            CovDFixtures.asset(id: "val", symbol: "VAL", currencyId: val, priceId: "covd-val-\(suffix)"),
            CovDFixtures.asset(id: "pswap", symbol: "PSWAP", currencyId: pswap, priceId: "covd-pswap-\(suffix)")
        ])
    }

    static func pair(_ chain: ChainModel, reservesId: String? = nil) -> LiquidityPair {
        LiquidityPair(
            pairId: "\(xor)-\(val)",
            chainId: chain.chainId,
            baseAssetId: xor,
            targetAssetId: val,
            reserves: nil,
            apy: nil,
            reservesId: reservesId
        )
    }

    static func accountPool(_ chain: ChainModel, base: Decimal? = 4, target: Decimal? = 8, reservesId: String? = nil) -> AccountPool {
        AccountPool(
            poolId: "\(xor)-\(val)",
            accountId: "0xaccount",
            chainId: chain.chainId,
            baseAssetId: xor,
            targetAssetId: val,
            baseAssetPooled: base,
            targetAssetPooled: target,
            accountPoolShare: Decimal(string: "0.25"),
            reservesId: reservesId
        )
    }

    static func chainAsset(_ chain: ChainModel, _ currencyId: String) -> ChainAsset {
        chain.chainAssets.first { $0.asset.currencyId == currencyId }!
    }

    static func planks(_ value: Decimal) -> BigUInt {
        value.toSubstrateAmount(precision: 18) ?? .zero
    }
}
