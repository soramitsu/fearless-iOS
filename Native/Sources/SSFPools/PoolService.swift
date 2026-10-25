import Combine
import Foundation

public protocol PoolsService {
    func getAllPairs() async throws -> [LiquidityPair]

    func getAccountPools(accountId: Data) async throws -> [AccountPool]

    func getAccountPoolDetails(
        accountId: Data,
        baseAsset: PooledAssetInfo,
        targetAsset: PooledAssetInfo
    ) async throws -> AccountPool?

    func subscribeAccountPools(
        accountId: Data
    ) async throws -> (ids: [UInt16], publisher: PassthroughSubject<[AccountPool], Error>)

    func subscribeAccountPoolDetails(
        accountId: Data,
        baseAsset: PooledAssetInfo,
        targetAsset: PooledAssetInfo
    ) throws -> (id: UInt16, publisher: PassthroughSubject<AccountPool, Error>)

    func unsubscribe(id: UInt16) throws
}
