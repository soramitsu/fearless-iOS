import Foundation
import SSFExtrinsicKit
import SSFPools

enum PoolsExtrinsicBuilderError: Error {
    case invalidAmount
    case unexpectedError
}

protocol PoolsExtrinsicBuilder {
    func depositLiqudityExtrinsic(
        pairs: [LiquidityPair],
        model: SupplyLiquidityInfo
    ) throws -> ExtrinsicBuilderClosure

    func removeLiqudityExtrinsic(model: RemoveLiquidityInfo) throws -> ExtrinsicBuilderClosure
}

final class PolkaswapExtrinsicBuilder {
    private let callFactory: SubstrateCallFactory

    init(callFactory: SubstrateCallFactory) {
        self.callFactory = callFactory
    }
}

extension PolkaswapExtrinsicBuilder: PoolsExtrinsicBuilder {
    func depositLiqudityExtrinsic(
        pairs: [LiquidityPair],
        model: SupplyLiquidityInfo
    ) throws -> ExtrinsicBuilderClosure {
        guard let amountA = model.baseAssetAmount
            .toSubstrateAmount(precision: model.baseAsset.precision),
            let amountB = model.targetAssetAmount
            .toSubstrateAmount(precision: model.targetAsset.precision),
            let amountMinA = model.amountMinA
            .toSubstrateAmount(precision: model.baseAsset.precision),
            let amountMinB = model.amountMinB
            .toSubstrateAmount(precision: model.targetAsset.precision) else
        {
            throw PoolsExtrinsicBuilderError.invalidAmount
        }

        let registerCall = try callFactory.register(
            dexId: model.dexId,
            baseAssetId: model.baseAsset.id,
            targetAssetId: model.targetAsset.id
        )
        let initializeCall = try callFactory.initializePool(
            dexId: model.dexId,
            baseAssetId: model.baseAsset.id,
            targetAssetId: model.targetAsset.id
        )

        let depositCall = try callFactory.depositLiquidity(
            dexId: model.dexId,
            assetA: model.baseAsset.id,
            assetB: model.targetAsset.id,
            desiredA: amountA,
            desiredB: amountB,
            minA: amountMinA,
            minB: amountMinB
        )

        return { builder in
            let isTherePoolInNetwork = pairs.contains {
                $0.baseAssetId == model.baseAsset.id &&
                    $0.targetAssetId == model.targetAsset.id
            }

            if isTherePoolInNetwork {
                return try builder
                    .with(shouldUseAtomicBatch: true)
                    .adding(call: depositCall)
            }

            return try builder
                .with(shouldUseAtomicBatch: true)
                .adding(call: registerCall)
                .adding(call: initializeCall)
                .adding(call: depositCall)
        }
    }

    func removeLiqudityExtrinsic(model: RemoveLiquidityInfo) throws -> ExtrinsicBuilderClosure {
        guard let amountMinA = model.amountMinA
            .toSubstrateAmount(precision: model.baseAsset.precision),
            let amountMinB = model.amountMinB
            .toSubstrateAmount(precision: model.targetAsset.precision),
            let assetDesired = model.assetDesired
            .toSubstrateAmount(precision: model.baseAsset.precision) else
        {
            throw PoolsExtrinsicBuilderError.invalidAmount
        }

        let withdrawCall = try callFactory.withdrawLiquidityCall(
            dexId: model.dexId,
            assetA: model.baseAsset.id,
            assetB: model.targetAsset.id,
            assetDesired: assetDesired,
            minA: amountMinA,
            minB: amountMinB
        )

        return { builder in
            try builder.adding(call: withdrawCall)
        }
    }
}
