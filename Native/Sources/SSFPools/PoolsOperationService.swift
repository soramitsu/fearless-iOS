import BigInt
import Foundation

public enum PoolsOperationServiceError: Error {
    case unexpectedError
}

public enum PoolOperation {
    case substrateSupplyLiquidity(SupplyLiquidityInfo)
    case substrateRemoveLiquidity(RemoveLiquidityInfo)
}

public protocol PoolsOperationService {
    func submit(liquidityOperation: PoolOperation) async throws -> String
    func estimateFee(liquidityOperation: PoolOperation) async throws -> BigUInt
}
