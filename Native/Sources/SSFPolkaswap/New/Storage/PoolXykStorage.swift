import Foundation
import BigInt
import SSFUtils
import SSFStorageQueryKit
import SSFModels

public enum PoolXykStorageError: Error {
    case totalIssuanceNotFound
    case accountPoolsNotFound(accountId: AccountId)
    case propertiesNotFound(pairs: [AssetIdPair])
    case poolProvidersNotFound(properties: [LiquidityPoolProperties], accountId: AccountId)
    case reservesNotFound(pairs: [AssetIdPair])
    case propertiesNotFound(baseAssetIds: [PolkaswapDexInfoAssetId])
}

public typealias TotalIssuanceByReservesId = [AccountId: BigUInt]

public protocol PoolXykStorage {
    func totalIssuance(chain: ChainModel) async throws -> TotalIssuanceByReservesId
    func accountPools(accountId: AccountId, chain: ChainModel) async throws -> [UserPool]
    func properties(pairs: [AssetIdPair], chain: ChainModel) async throws -> [AssetIdPair: LiquidityPoolProperties]
    func poolProviders(properties: [LiquidityPoolProperties], accountId: AccountId, chain: ChainModel) async throws -> [PoolProvidersStorageKey: BigUInt]
    func reserves(pairs: [AssetIdPair], chain: ChainModel) async throws -> [PolkaswapPoolReservesInfo]
    func properties(baseAssetIds: [PolkaswapDexInfoAssetId], chain: ChainModel) async throws ->  [AssetIdPair: LiquidityPoolProperties]
    
    func subscribeTotalIssuance(chain: ChainModel) async -> AsyncThrowingStream<CachedStorageResponse<TotalIssuanceByReservesId>, Error>
    func subscribeProperties(baseAssetIds: [PolkaswapDexInfoAssetId], chain: ChainModel) async ->  AsyncThrowingStream<CachedStorageResponse<[AssetIdPair: LiquidityPoolProperties]>, Error>
    func subscribeAccountPools(accountId: AccountId, chain: ChainModel) async -> AsyncThrowingStream<CachedStorageResponse<[ScaleTuple<Data,SoraAssetId>: [SoraAssetId]]>, Swift.Error>
    func subscribeProperties(pairs: [AssetIdPair], chain: ChainModel) async throws -> AsyncThrowingStream<CachedStorageResponse<[AssetIdPair: LiquidityPoolProperties]>, Swift.Error>
    func subscribeReserves(pairs: [AssetIdPair], chain: ChainModel) async throws -> AsyncThrowingStream<CachedStorageResponse<[AssetIdPair: PolkaswapPoolReserves]>, Error>
}

public final class PoolXykStorageDefaultL: PoolXykStorage {
    
    private let storageRequestPerformer: StorageRequestPerformer
    
    public init(storageRequestPerformer: StorageRequestPerformer) {
        self.storageRequestPerformer = storageRequestPerformer
    }
    
    // MARK: - Requests

    public func totalIssuance(chain: ChainModel) async throws -> TotalIssuanceByReservesId {
        let totalIssuanceRequest = PoolXykTotalIssuanceStoragePagedRequest()
        let totalIssuanceByReservesId: [Data: StringScaleMapper<BigUInt>]? = try await storageRequestPerformer.performPrefix(totalIssuanceRequest, chain: chain)
        
        guard let totalIssuanceByReservesId else {
            throw PoolXykStorageError.totalIssuanceNotFound
        }
        
        return totalIssuanceByReservesId.compactMapValues { $0.value }
    }
    
    public func accountPools(accountId: AccountId, chain: ChainModel) async throws -> [UserPool] {
        let userPoolsRequest = UserPoolsStorageRequest(accountId: accountId)
        let userPools: [ScaleTuple<Data,SoraAssetId>: [SoraAssetId]]? = try await storageRequestPerformer.performPrefix(userPoolsRequest, chain: chain)
        
        guard let userPools else {
            throw PoolXykStorageError.accountPoolsNotFound(accountId: accountId)
        }
        
        return userPools.compactMap { userPool in
            return userPool.value.compactMap {
                let assetIdPair = AssetIdPair(baseAssetIdCode: userPool.key.second.value, targetAssetIdCode: $0.value)
                
                return UserPool(
                    accountId: accountId,
                    assetPair: assetIdPair
                )
            }
        }.reduce([], +)
    }
    
    public func properties(pairs: [AssetIdPair], chain: ChainModel) async throws -> [AssetIdPair: LiquidityPoolProperties] {
        let propertiesRequest = XykPoolPropertiesStorageMultipleRequest(pairs: pairs)
        let properties: [AssetIdPair: LiquidityPoolProperties]? = try await storageRequestPerformer.performMultiple(propertiesRequest, chain: chain)
        
        guard let properties else {
            throw PoolXykStorageError.propertiesNotFound(pairs: pairs)
        }
        
        return properties
    }
    
    public func poolProviders(properties: [LiquidityPoolProperties], accountId: AccountId, chain: ChainModel) async throws -> [PoolProvidersStorageKey: BigUInt] {
        let poolProvidersRequestParameters: [PoolProvidersStorageKey] = properties.compactMap {
            return PoolProvidersStorageKey(reservesId: $0.reservesId, accountId: accountId)
        }
        let poolProvidersRequest = PoolXykPoolProvidersStorageMultipleRequest(parameters: poolProvidersRequestParameters)
        let poolProviders: [PoolProvidersStorageKey: StringScaleMapper<BigUInt>]? = try await storageRequestPerformer.performMultiple(poolProvidersRequest, chain: chain)
        
        guard let poolProviders else {
            throw PoolXykStorageError.poolProvidersNotFound(properties: properties, accountId: accountId)
        }
        
        return poolProviders.compactMapValues { $0.value }
    }
    
    public func reserves(pairs: [AssetIdPair], chain: ChainModel) async throws -> [PolkaswapPoolReservesInfo] {
        let poolReservesRequest = PoolXykReservesStorageRequest(pairs: pairs)
        let poolReservesByPair: [AssetIdPair: PolkaswapPoolReserves]? = try await storageRequestPerformer.performMultiple(poolReservesRequest, chain: chain)
        
        guard let poolReservesByPair else {
            throw PoolXykStorageError.reservesNotFound(pairs: pairs)
        }
        
        return poolReservesByPair.compactMap {
            PolkaswapPoolReservesInfo(poolId: $0.key.poolId, reserves: $0.value)
        }
    }
    
    public func properties(baseAssetIds: [PolkaswapDexInfoAssetId], chain: ChainModel) async throws ->  [AssetIdPair: LiquidityPoolProperties] {
        let propertiesRequest = XykPoolPropertiesStoragePagedRequest(baseAssetIds: baseAssetIds)
        let properties: [AssetIdPair: LiquidityPoolProperties]? = try await storageRequestPerformer.performPrefix(propertiesRequest, chain: chain)
        
        guard let properties else {
            throw PoolXykStorageError.propertiesNotFound(baseAssetIds: baseAssetIds)
        }
        return properties
    }

    // MARK: - Subscriptions
    
    public func subscribeProperties(baseAssetIds: [PolkaswapDexInfoAssetId], chain: ChainModel) async -> AsyncThrowingStream<CachedStorageResponse<[AssetIdPair : LiquidityPoolProperties]>, Error> {
        let propertiesRequest = XykPoolPropertiesStoragePagedRequest(baseAssetIds: baseAssetIds)
        let properties: AsyncThrowingStream<CachedStorageResponse<[AssetIdPair: LiquidityPoolProperties]>, Error> = await storageRequestPerformer.performPrefix(propertiesRequest, withCacheOptions: .onAll, chain: chain)
        return properties
    }
    
    public func subscribeTotalIssuance(chain: ChainModel) async -> AsyncThrowingStream<CachedStorageResponse<TotalIssuanceByReservesId>, Error> {
        let totalIssuanceRequest = PoolXykTotalIssuanceStoragePagedRequest()
        let totalIssuance: AsyncThrowingStream<CachedStorageResponse<TotalIssuanceByReservesId>, Error> = await storageRequestPerformer.performPrefix(totalIssuanceRequest, withCacheOptions: .onAll, chain: chain)
        return totalIssuance
    }
    
    public func subscribeAccountPools(accountId: AccountId, chain: ChainModel) async -> AsyncThrowingStream<CachedStorageResponse<[ScaleTuple<Data,SoraAssetId>: [SoraAssetId]]>, Swift.Error> {
        let userPoolsRequest = UserPoolsStorageRequest(accountId: accountId)
        let userPools: AsyncThrowingStream<CachedStorageResponse<[ScaleTuple<Data,SoraAssetId>: [SoraAssetId]]>, Swift.Error> = await storageRequestPerformer.performPrefix(userPoolsRequest, withCacheOptions: .onAll, chain: chain)
        return userPools
    }
    
    public func subscribeProperties(pairs: [AssetIdPair], chain: ChainModel) async throws -> AsyncThrowingStream<CachedStorageResponse<[AssetIdPair: LiquidityPoolProperties]>, Swift.Error> {
        let propertiesRequest = XykPoolPropertiesStorageMultipleRequest(pairs: pairs)
        let properties: AsyncThrowingStream<CachedStorageResponse<[AssetIdPair: LiquidityPoolProperties]>, Swift.Error> = await storageRequestPerformer.performMultiple(propertiesRequest, withCacheOptions: .onAll, chain: chain)
        return properties
    }
    
    public func subscribeReserves(pairs: [AssetIdPair], chain: ChainModel) async throws -> AsyncThrowingStream<CachedStorageResponse<[AssetIdPair: PolkaswapPoolReserves]>, Error> {
        let poolReservesRequest = PoolXykReservesStorageRequest(pairs: pairs)
        let poolReservesByPair: AsyncThrowingStream<CachedStorageResponse<[AssetIdPair: PolkaswapPoolReserves]>, Error> = await storageRequestPerformer.performMultiple(poolReservesRequest, withCacheOptions: .onAll, chain: chain)
        return poolReservesByPair
    }
}
