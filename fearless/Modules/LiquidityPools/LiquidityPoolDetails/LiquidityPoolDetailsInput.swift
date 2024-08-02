import Foundation
import SSFPolkaswap
import SSFPools
import SSFModels

enum LiquidityPoolDetailsInput {
    case initial
    case userPool(
        liquidityPair: LiquidityPair?,
        reserves: PolkaswapPoolReservesInfo?,
        apyInfo: PoolApyInfo?,
        accountPool: AccountPool?,
        availablePairs: [LiquidityPair]?
    )
    case availablePool(
        liquidityPair: LiquidityPair?,
        reserves: PolkaswapPoolReservesInfo?,
        apyInfo: PoolApyInfo?,
        availablePairs: [LiquidityPair]?
    )

    var availablePairs: [LiquidityPair]? {
        switch self {
        case .initial:
            return nil
        case let .userPool(_, _, _, _, availablePairs):
            return availablePairs
        case let .availablePool(_, _, _, availablePairs):
            return availablePairs
        }
    }

    var liquidityPair: LiquidityPair? {
        switch self {
        case .initial:
            return nil
        case let .userPool(liquidityPair, _, _, _, _):
            return liquidityPair
        case let .availablePool(liquidityPair, _, _, _):
            return liquidityPair
        }
    }

    var reserves: PolkaswapPoolReservesInfo? {
        switch self {
        case .initial:
            return nil
        case let .userPool(_, reserves, _, _, _):
            return reserves
        case let .availablePool(_, reserves, _, _):
            return reserves
        }
    }

    var apyInfo: PoolApyInfo? {
        switch self {
        case .initial:
            return nil
        case let .userPool(_, _, apyInfo, _, _):
            return apyInfo
        case let .availablePool(_, _, apyInfo, _):
            return apyInfo
        }
    }

    var accountPool: AccountPool? {
        switch self {
        case .initial:
            return nil
        case let .userPool(_, _, _, accountPool, _):
            return accountPool
        case .availablePool:
            return nil
        }
    }

    var isUserPool: Bool {
        switch self {
        case .userPool:
            return true
        default:
            return false
        }
    }
}
