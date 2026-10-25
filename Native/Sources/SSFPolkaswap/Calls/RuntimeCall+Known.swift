import Foundation
import SSFUtils

extension RuntimeCall {
    static func register(_ args: PairRegisterCall) -> RuntimeCall<PairRegisterCall> {
        RuntimeCall<PairRegisterCall>(moduleName: "TradingPair", callName: "register", args: args)
    }

    static func initializePool(_ args: InitializePoolCall) -> RuntimeCall<InitializePoolCall> {
        RuntimeCall<InitializePoolCall>(
            moduleName: "PoolXYK",
            callName: "initialize_pool",
            args: args
        )
    }

    static func depositLiquidity(_ args: DepositLiquidityCall)
        -> RuntimeCall<DepositLiquidityCall>
    {
        RuntimeCall<DepositLiquidityCall>(
            moduleName: "PoolXYK",
            callName: "deposit_liquidity",
            args: args
        )
    }

    static func withdrawLiquidity(_ args: WithdrawLiquidityCall)
        -> RuntimeCall<WithdrawLiquidityCall>
    {
        RuntimeCall<WithdrawLiquidityCall>(
            moduleName: "PoolXYK",
            callName: "withdraw_liquidity",
            args: args
        )
    }
}
