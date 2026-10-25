import BigInt
import Foundation
import IrohaCrypto
import SSFCrypto
import SSFModels
import SSFPools
import SSFStorageQueryKit

enum RemotePolkaswapPoolsServiceError: Error {
    case reservesIdNotFound
}

protocol RemotePolkaswapPoolsService {
    func getBaseAssets() async throws -> [String]
    func getAccountPools(accountId: Data) async throws -> [AccountPool]
    func getPoolDetails(
        accountId: Data,
        baseAsset: PooledAssetInfo,
        targetAsset: PooledAssetInfo
    ) async throws -> AccountPool
    func getBaseAssetIds() async throws -> [String]
    func getAllPairs() async throws -> [LiquidityPair]
    func getAPY(reservesId: String?) async throws -> Decimal?
}

actor RemotePolkaswapPoolsServiceDefault {
    private let worker: PolkaswapWorker
    private let apyService: PolkaswapAPYService
    private let addressFactory: AddressFactory.Type
    private let chain: ChainModel
    private let storageRequestPerformer: StorageRequestPerformer

    init(
        chain: ChainModel,
        worker: PolkaswapWorker,
        apyService: PolkaswapAPYService,
        addressFactory: AddressFactory,
        storageRequestPerformer: StorageRequestPerformer
    ) {
        self.chain = chain
        self.worker = worker
        self.apyService = apyService
        self.addressFactory = type(of: addressFactory)
        self.storageRequestPerformer = storageRequestPerformer
    }
}

extension RemotePolkaswapPoolsServiceDefault: RemotePolkaswapPoolsService {
    func getBaseAssets() async throws -> [String] {
        try await worker.getBaseAssetIds()
    }

    func getAccountPools(accountId: Data) async throws -> [AccountPool] {
        let baseAssetIds = try await worker.getBaseAssetIds()

        async let reserveIdPairs = try baseAssetIds.concurrentMap { [weak self] baseAssetId in
            try await self?.worker.getPoolReservesId(baseAssetId: baseAssetId)
        }

        async let accountPools = baseAssetIds.concurrentMap { [weak self] baseAssetId in
            try await self?.worker.getAccountPools(accountId: accountId, baseAssetId: baseAssetId)
        }

        let results = try await(
            reserveIdPairs: reserveIdPairs.reduce([], +),
            accountPools: accountPools.reduce([], +)
        )

        return results.accountPools.compactMap { pool in
            guard let reservesId = results.reserveIdPairs
                .first(where: { $0.pairId == pool.poolId })?.reservesId else
            {
                return nil
            }

            return pool.update(reservesId: reservesId)
        }
    }

    func getPoolDetails(
        accountId: Data,
        baseAsset: PooledAssetInfo,
        targetAsset: PooledAssetInfo
    ) async throws -> AccountPool {
        let reservesId = try await worker.getPoolReservesId(
            baseAssetId: baseAsset.id,
            targetAssetId: targetAsset.id
        )

        let accountPoolBalance = try await worker.getPoolProviderBalance(
            reservesId: reservesId.value,
            accountId: accountId
        )
        let totalIssuances = try await worker.getPoolTotalIssuances(reservesId: reservesId.value)
        let poolReserves = try await worker.getPoolReserves(
            baseAssetId: baseAsset.id,
            targetAssetId: targetAsset.id
        )

        let poolDetails = (
            accountPoolBalance: accountPoolBalance,
            totalIssuances: totalIssuances,
            poolReserves: poolReserves
        )

        let totalIssuancesDecimal = Decimal.fromSubstrateAmount(
            poolDetails.totalIssuances,
            precision: baseAsset.precision
        ) ?? Decimal(0)

        let reserves = Decimal.fromSubstrateAmount(
            poolDetails.poolReserves.reserves,
            precision: baseAsset.precision
        ) ?? Decimal(0)

        let accountPoolBalanceDecimal = Decimal.fromSubstrateAmount(
            poolDetails.accountPoolBalance,
            precision: baseAsset.precision
        ) ?? Decimal(0)

        let targetAssetPooledTotal = Decimal.fromSubstrateAmount(
            poolDetails.poolReserves.fee,
            precision: targetAsset.precision
        ) ?? Decimal(0)

        let areThereIssuances = totalIssuancesDecimal > 0

        let accountPoolShare = areThereIssuances ? accountPoolBalanceDecimal /
            totalIssuancesDecimal * 100 : .zero
        let baseAssetPooled = areThereIssuances ? reserves * accountPoolBalanceDecimal /
            totalIssuancesDecimal : .zero
        let targetAssetPooled = areThereIssuances ? targetAssetPooledTotal *
            accountPoolBalanceDecimal / totalIssuancesDecimal : .zero
        let reservationIdString = try AddressFactory.address(
            for: reservesId.value,
            chainFormat: chain.chainFormat
        )

        return AccountPool(
            poolId: "\(baseAsset.id)-\(targetAsset.id)",
            accountId: accountId.toHex(),
            chainId: chain.chainId,
            baseAssetId: baseAsset.id,
            targetAssetId: targetAsset.id,
            baseAssetPooled: baseAssetPooled,
            targetAssetPooled: targetAssetPooled,
            accountPoolShare: accountPoolShare,
            reservesId: reservationIdString
        )
    }

    func getBaseAssetIds() async throws -> [String] {
        try await worker.getBaseAssetIds()
    }

    func getAllPairs() async throws -> [LiquidityPair] {
        let baseAssetIds = try await worker.getBaseAssetIds()

        async let reserveIdPairs = try baseAssetIds.concurrentMap { [weak self] baseAssetId in
            try await self?.worker.getPoolReservesId(baseAssetId: baseAssetId)
        }

        async let reservePairs = try baseAssetIds.concurrentMap { [weak self] baseAssetId in
            try await self?.worker.getPoolsReserves(baseAssetId: baseAssetId)
        }

        let results = try await(
            reservePairs: reservePairs.reduce([], +),
            reserveIdPairs: reserveIdPairs.reduce([], +)
        )

        return results.reservePairs.compactMap { pair in
            guard let reservesId = results.reserveIdPairs
                .first(where: { $0.pairId == pair.pairId })?.reservesId else
            {
                return nil
            }

            return pair.update(reservesId: reservesId)
        }
    }

    func getAPY(reservesId: String?) async throws -> Decimal? {
        guard let reservesId else {
            throw RemotePolkaswapPoolsServiceError.reservesIdNotFound
        }
        return try await apyService.getApy(reservesId: reservesId)
    }
}
