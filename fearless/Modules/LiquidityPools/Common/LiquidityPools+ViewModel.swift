import Foundation
import SSFPolkaswap
import SSFModels
import SSFPools

protocol LiquidityPoolsModelFactory {
    func buildReserves(pool: LiquidityPair, chain: ChainModel, reserves: PolkaswapPoolReservesInfo?, baseAssetPrice: PriceData?, targetAssetPrice: PriceData?) -> Decimal?
    func buildReserves(accountPool: AccountPool, chain: ChainModel, reserves: PolkaswapPoolReservesInfo?, baseAssetPrice: PriceData?, targetAssetPrice: PriceData?) -> Decimal?
}

final class LiquidityPoolsModelFactoryDefault: LiquidityPoolsModelFactory {
    func buildReserves(pool: LiquidityPair, chain: ChainModel, reserves: PolkaswapPoolReservesInfo?, baseAssetPrice: PriceData?, targetAssetPrice: PriceData?) -> Decimal? {
        let baseAsset = chain.assets.first(where: { $0.currencyId == pool.baseAssetId })
        let targetAsset = chain.assets.first(where: { $0.currencyId == pool.targetAssetId })

        guard let baseAsset, let targetAsset else {
            return nil
        }

        let poolReservesValue = (reserves?.reserves.reserves).flatMap { Decimal.fromSubstrateAmount($0, precision: Int16(baseAsset.precision)) }
        let baseAssetPriceValue = (baseAssetPrice?.price).flatMap { Decimal(string: $0) }

        let poolFeeValue = (reserves?.reserves.fee).flatMap { Decimal.fromSubstrateAmount($0, precision: Int16(targetAsset.precision)) }
        let targetAssetPriceValue = (targetAssetPrice?.price).flatMap { Decimal(string: $0) }

        let poolReservesFiatValue: Decimal? = poolReservesValue.flatMap { poolReserves in
            guard let baseAssetPriceValue, let poolFeeValue, let targetAssetPriceValue else {
                return nil
            }

            return (poolReserves * baseAssetPriceValue) + (poolFeeValue * targetAssetPriceValue)
        }

        return poolReservesFiatValue
    }

    func buildReserves(accountPool: AccountPool, chain: ChainModel, reserves: PolkaswapPoolReservesInfo?, baseAssetPrice: PriceData?, targetAssetPrice: PriceData?) -> Decimal? {
        let baseAsset = chain.assets.first(where: { $0.currencyId == accountPool.baseAssetId })
        let targetAsset = chain.assets.first(where: { $0.currencyId == accountPool.targetAssetId })

        guard let baseAsset, let targetAsset else {
            return nil
        }

        let poolReservesValue = (reserves?.reserves.reserves).flatMap { Decimal.fromSubstrateAmount($0, precision: Int16(baseAsset.precision)) }
        let baseAssetPriceValue = (baseAssetPrice?.price).flatMap { Decimal(string: $0) }

        let poolFeeValue = (reserves?.reserves.fee).flatMap { Decimal.fromSubstrateAmount($0, precision: Int16(targetAsset.precision)) }
        let targetAssetPriceValue = (targetAssetPrice?.price).flatMap { Decimal(string: $0) }

        let poolReservesFiatValue: Decimal? = poolReservesValue.flatMap { poolReserves in
            guard let baseAssetPriceValue, let poolFeeValue, let targetAssetPriceValue else {
                return nil
            }

            return (poolReserves * baseAssetPriceValue) + (poolFeeValue * targetAssetPriceValue)
        }

        return poolReservesFiatValue
    }
}
