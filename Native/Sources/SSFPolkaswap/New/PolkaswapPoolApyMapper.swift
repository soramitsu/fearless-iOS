import Foundation
import SSFPools

/// Maps indexer APY rows to the reserves-account address that the liquidity-pool screens
/// match on (`PoolApyInfo.poolId`).
///
/// The Soramitsu indexer identifies a pool as `<base asset id>-<target asset id>`; the
/// retired SubQuery project used the reserves address itself. Rows for pools the chain
/// does not list are dropped.
public enum PolkaswapPoolApyMapper {
    public static func map(
        _ values: [PolkaswapPoolStrategicBonusApy],
        availablePools: [LiquidityPair]
    ) -> [PoolApyInfo] {
        var reservesByPairId: [String: String] = [:]
        var knownReserves = Set<String>()

        for pool in availablePools {
            guard let reservesId = pool.reservesId, !reservesId.isEmpty else {
                continue
            }

            let pairId = normalizedPairId(
                baseAssetId: pool.baseAssetId,
                targetAssetId: pool.targetAssetId
            )
            reservesByPairId[pairId] = reservesId
            knownReserves.insert(reservesId)
        }

        var seenPools = Set<String>()

        return values.compactMap { value in
            let poolId: String
            if let reservesId = reservesByPairId[normalizedIndexerId(value.id)] {
                poolId = reservesId
            } else if knownReserves.contains(value.id) {
                poolId = value.id
            } else {
                return nil
            }

            guard seenPools.insert(poolId).inserted else {
                return nil
            }

            return PoolApyInfo(poolId: poolId, apy: value.strategicBonusApy)
        }
    }

    static func normalizedPairId(baseAssetId: String, targetAssetId: String) -> String {
        "\(normalizedAssetId(baseAssetId))-\(normalizedAssetId(targetAssetId))"
    }

    static func normalizedIndexerId(_ identifier: String) -> String {
        let parts = identifier.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2 else {
            return identifier.lowercased()
        }

        return normalizedPairId(baseAssetId: String(parts[0]), targetAssetId: String(parts[1]))
    }

    private static func normalizedAssetId(_ assetId: String) -> String {
        let lowercased = assetId.lowercased()
        return lowercased.hasPrefix("0x") ? lowercased : "0x" + lowercased
    }
}
