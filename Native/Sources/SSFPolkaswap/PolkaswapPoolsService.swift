import Combine
import Foundation
import SSFPools
import SSFPoolsStorage
import SSFStorageQueryKit
import SSFUtils

enum PolkaswapServiceError: Error {
    case unexpectedError
}

public final class PolkaswapService {
    private let remoteService: RemotePolkaswapPoolsService
    private let localPairService: LocalLiquidityPairService
    private let localAccountPoolService: LocalAccountPoolsService
    private let subscriptionService: PoolSubscriptionService

    init(
        remoteService: RemotePolkaswapPoolsService,
        localPairService: LocalLiquidityPairService,
        localAccountPoolService: LocalAccountPoolsService,
        subscriptionService: PoolSubscriptionService
    ) {
        self.remoteService = remoteService
        self.localPairService = localPairService
        self.localAccountPoolService = localAccountPoolService
        self.subscriptionService = subscriptionService
    }
}

extension PolkaswapService: PoolsService {
    public func subscribeAccountPools(
        accountId: Data
    ) async throws -> (ids: [UInt16], publisher: PassthroughSubject<[AccountPool], Error>) {
        let publisher = PassthroughSubject<[AccountPool], Error>()

        let baseAssetIds = try await remoteService.getBaseAssetIds()

        let updateClosure: (JSONRPCSubscriptionUpdate<StorageUpdate>) -> Void = { [weak self] _ in
            Task { [weak self] in
                guard let self else { return }
                let accountPools = try await self.getAccountPools(accountId: accountId)
                publisher.send(accountPools)
            }
        }

        let ids = try baseAssetIds.compactMap { baseAssetId in
            try subscriptionService.createAccountPoolsSubscription(
                accountId: accountId,
                baseAssetId: baseAssetId,
                updateClosure: updateClosure
            )
        }

        return (ids: ids, publisher: publisher)
    }

    public func getAccountPools(accountId: Data) async throws -> [AccountPool] {
        do {
            var accountPools = try await remoteService.getAccountPools(accountId: accountId)

            accountPools = try await accountPools.asyncMap { [weak self] pool in
                let apy = try await self?.remoteService.getAPY(reservesId: pool.reservesId)
                return pool.update(apy: apy)
            }

            try await localAccountPoolService.sync(remoteAccounts: accountPools)

            return accountPools
        } catch {
            return try await localAccountPoolService.get()
        }
    }

    public func subscribeAccountPoolDetails(
        accountId: Data,
        baseAsset: SSFPools.PooledAssetInfo,
        targetAsset: SSFPools.PooledAssetInfo
    ) throws -> (id: UInt16, publisher: PassthroughSubject<SSFPools.AccountPool, Error>) {
        let publisher = PassthroughSubject<AccountPool, Error>()

        let updateClosure: (JSONRPCSubscriptionUpdate<StorageUpdate>) -> Void = { [weak self] _ in
            Task { [weak self] in
                guard let self,
                      let poolDetails = try await self.getAccountPoolDetails(
                          accountId: accountId,
                          baseAsset: baseAsset,
                          targetAsset: targetAsset
                      ) else
                {
                    return
                }

                publisher.send(poolDetails)
            }
        }

        let id = try subscriptionService.createPoolReservesSubscription(
            baseAssetId: baseAsset.id,
            targetAssetId: targetAsset.id,
            updateClosure: updateClosure
        )

        return (id: id, publisher: publisher)
    }

    public func getAccountPoolDetails(
        accountId: Data,
        baseAsset: SSFPools.PooledAssetInfo,
        targetAsset: SSFPools.PooledAssetInfo
    ) async throws -> SSFPools.AccountPool? {
        do {
            let poolDetails = try await remoteService.getPoolDetails(
                accountId: accountId,
                baseAsset: baseAsset,
                targetAsset: targetAsset
            )

            return poolDetails
        } catch {
            let pools = try? await localAccountPoolService.get()
            return pools?
                .first { $0.baseAssetId == baseAsset.id && $0.targetAssetId == targetAsset.id }
        }
    }

    public func getAllPairs() async throws -> [LiquidityPair] {
        do {
            var liquidityPairs = try await remoteService.getAllPairs()

            liquidityPairs = try await liquidityPairs.asyncMap { [weak self] pair in
                let apy = try await self?.remoteService.getAPY(reservesId: pair.reservesId)
                return pair.update(apy: apy)
            }

            try await localPairService.sync(remotePairs: liquidityPairs)

            return liquidityPairs
        } catch {
            return try await localPairService.get()
        }
    }

    public func unsubscribe(id: UInt16) throws {
        try subscriptionService.unsubscribe(id: id)
    }
}
