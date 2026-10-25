import Foundation
import RobinHood

enum WalletAssetId: String {
    case pswap = "0x0200050000000000000000000000000000000000000000000000000000000000"
}

public struct AccountPool: Codable {
    public enum CodingKeys: String, CodingKey {
        case poolId
        case accountId
        case chainId
        case baseAssetId
        case targetAssetId
        case rewardAssetId
        case apy
        case baseAssetPooled
        case targetAssetPooled
        case accountPoolShare
    }

    public let poolId: String
    public let accountId: String
    public let chainId: String
    public let baseAssetId: String
    public let targetAssetId: String
    public let rewardAssetId: String = WalletAssetId.pswap.rawValue
    public var apy: Decimal?
    public var baseAssetPooled: Decimal?
    public var targetAssetPooled: Decimal?
    public var accountPoolShare: Decimal?
    public var reservesId: String?

    public init(
        poolId: String,
        accountId: String,
        chainId: String,
        baseAssetId: String,
        targetAssetId: String,
        apy: Decimal? = nil,
        baseAssetPooled: Decimal? = nil,
        targetAssetPooled: Decimal? = nil,
        accountPoolShare: Decimal? = nil,
        reservesId: String? = nil
    ) {
        self.poolId = poolId
        self.accountId = accountId
        self.chainId = chainId
        self.baseAssetId = baseAssetId
        self.targetAssetId = targetAssetId
        self.apy = apy
        self.baseAssetPooled = baseAssetPooled
        self.targetAssetPooled = targetAssetPooled
        self.accountPoolShare = accountPoolShare
        self.reservesId = reservesId
    }

    init(accountPool: AccountPool) {
        self.init(
            poolId: accountPool.poolId,
            accountId: accountPool.accountId,
            chainId: accountPool.chainId,
            baseAssetId: accountPool.baseAssetId,
            targetAssetId: accountPool.targetAssetId,
            apy: accountPool.apy,
            baseAssetPooled: accountPool.baseAssetPooled,
            targetAssetPooled: accountPool.targetAssetPooled,
            accountPoolShare: accountPool.accountPoolShare,
            reservesId: accountPool.reservesId
        )
    }

    public func update(reservesId: String?) -> AccountPool {
        var copy = AccountPool(accountPool: self)
        copy.reservesId = reservesId
        return copy
    }

    public func update(apy: Decimal?) -> AccountPool {
        var copy = AccountPool(accountPool: self)
        copy.apy = apy
        return copy
    }
}

extension AccountPool: Identifiable {
    public var identifier: String { poolId }
}

extension AccountPool: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(poolId)
        hasher.combine(baseAssetId)
        hasher.combine(targetAssetId)
        hasher.combine(accountId)
        hasher.combine(chainId)
    }

    public static func == (lhs: AccountPool, rhs: AccountPool) -> Bool {
        lhs.poolId == rhs.poolId &&
            lhs.accountId == rhs.accountId &&
            lhs.chainId == rhs.chainId &&
            lhs.baseAssetId == rhs.baseAssetId &&
            lhs.targetAssetId == rhs.targetAssetId
    }
}
