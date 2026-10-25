import BigInt
import Foundation
import IrohaCrypto
import SSFUtils

protocol SubstrateCallFactory {
    func register(
        dexId: String,
        baseAssetId: String,
        targetAssetId: String
    ) throws -> RuntimeCall<PairRegisterCall>

    func initializePool(
        dexId: String,
        baseAssetId: String,
        targetAssetId: String
    ) throws -> RuntimeCall<InitializePoolCall>

    func depositLiquidity(
        dexId: String,
        assetA: String,
        assetB: String,
        desiredA: BigUInt,
        desiredB: BigUInt,
        minA: BigUInt,
        minB: BigUInt
    ) throws -> RuntimeCall<DepositLiquidityCall>

    func withdrawLiquidityCall(
        dexId: String,
        assetA: String,
        assetB: String,
        assetDesired: BigUInt,
        minA: BigUInt,
        minB: BigUInt
    ) throws -> RuntimeCall<WithdrawLiquidityCall>
}

final class SubstrateCallFactoryDefault: SubstrateCallFactory {
    func register(
        dexId: String,
        baseAssetId: String,
        targetAssetId: String
    ) throws -> RuntimeCall<PairRegisterCall> {
        let call = PairRegisterCall(
            dexId: dexId,
            baseAssetId: SoraAssetId(wrappedValue: baseAssetId),
            targetAssetId: SoraAssetId(wrappedValue: targetAssetId)
        )
        return RuntimeCall<PairRegisterCall>.register(call)
    }

    func initializePool(
        dexId: String,
        baseAssetId: String,
        targetAssetId: String
    ) throws -> RuntimeCall<InitializePoolCall> {
        let call = InitializePoolCall(
            dexId: dexId,
            assetA: SoraAssetId(wrappedValue: baseAssetId),
            assetB: SoraAssetId(wrappedValue: targetAssetId)
        )
        return RuntimeCall<InitializePoolCall>.initializePool(call)
    }

    func depositLiquidity(
        dexId: String,
        assetA: String,
        assetB: String,
        desiredA: BigUInt,
        desiredB: BigUInt,
        minA: BigUInt,
        minB: BigUInt
    ) throws -> RuntimeCall<DepositLiquidityCall> {
        let call = DepositLiquidityCall(
            dexId: dexId,
            assetA: SoraAssetId(wrappedValue: assetA),
            assetB: SoraAssetId(wrappedValue: assetB),
            desiredA: desiredA,
            desiredB: desiredB,
            minA: minA,
            minB: minB
        )
        return RuntimeCall<DepositLiquidityCall>.depositLiquidity(call)
    }

    func withdrawLiquidityCall(
        dexId: String,
        assetA: String,
        assetB: String,
        assetDesired: BigUInt,
        minA: BigUInt,
        minB: BigUInt
    ) throws -> RuntimeCall<WithdrawLiquidityCall> {
        let call = WithdrawLiquidityCall(
            dexId: dexId,
            assetA: SoraAssetId(wrappedValue: assetA),
            assetB: SoraAssetId(wrappedValue: assetB),
            assetDesired: assetDesired,
            minA: minA,
            minB: minB
        )
        return RuntimeCall<WithdrawLiquidityCall>.withdrawLiquidity(call)
    }
}
