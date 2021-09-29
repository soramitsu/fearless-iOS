import Foundation

struct BalanceContext {
    static let freeKey = "account.balance.free.key"
    static let reservedKey = "account.balance.reserved.key"
    static let miscFrozenKey = "account.balance.misc.frozen.key"
    static let feeFrozenKey = "account.balance.fee.frozen.key"

    static let bondedKey = "account.balance.bonded.key"
    static let redeemableKey = "account.balance.redeemable.key"
    static let unbondingKey = "account.balance.unbonding.key"

    static let priceKey = "account.balance.price.key"
    static let priceChangeKey = "account.balance.price.change.key"

    static let minimalBalanceKey = "account.balance.minimal.key"

    let free: Decimal
    let reserved: Decimal
    let miscFrozen: Decimal
    let feeFrozen: Decimal

    let price: Decimal
    let priceChange: Decimal

    let minimalBalance: Decimal

    let balanceLocks: [String: Decimal]
}

extension BalanceContext {
    var total: Decimal { free + reserved }
    var frozen: Decimal { reserved + locked }
    var locked: Decimal { max(miscFrozen, feeFrozen) }
    var available: Decimal { free - locked }
}

extension BalanceContext {
    init(context: [String: String]) {
        free = Self.parseContext(key: BalanceContext.freeKey, context: context)
        reserved = Self.parseContext(key: BalanceContext.reservedKey, context: context)
        miscFrozen = Self.parseContext(key: BalanceContext.miscFrozenKey, context: context)
        feeFrozen = Self.parseContext(key: BalanceContext.feeFrozenKey, context: context)

        price = Self.parseContext(key: BalanceContext.priceKey, context: context)
        priceChange = Self.parseContext(key: BalanceContext.priceChangeKey, context: context)

        minimalBalance = Self.parseContext(key: BalanceContext.minimalBalanceKey, context: context)

        balanceLocks = [:]
    }

    func toContext() -> [String: String] {
        [
            BalanceContext.freeKey: free.stringWithPointSeparator,
            BalanceContext.reservedKey: reserved.stringWithPointSeparator,
            BalanceContext.miscFrozenKey: miscFrozen.stringWithPointSeparator,
            BalanceContext.feeFrozenKey: feeFrozen.stringWithPointSeparator,
            BalanceContext.priceKey: price.stringWithPointSeparator,
            BalanceContext.priceChangeKey: priceChange.stringWithPointSeparator,
            BalanceContext.minimalBalanceKey: minimalBalance.stringWithPointSeparator
        ]
    }

    private static func parseContext(key: String, context: [String: String]) -> Decimal {
        if let stringValue = context[key] {
            return Decimal(string: stringValue) ?? .zero
        } else {
            return .zero
        }
    }
}

extension BalanceContext {
    func byChangingAccountInfo(_ accountData: AccountData, precision: Int16) -> BalanceContext {
        let free = Decimal
            .fromSubstrateAmount(accountData.free, precision: precision) ?? .zero
        let reserved = Decimal
            .fromSubstrateAmount(accountData.reserved, precision: precision) ?? .zero
        let miscFrozen = Decimal
            .fromSubstrateAmount(accountData.miscFrozen, precision: precision) ?? .zero
        let feeFrozen = Decimal
            .fromSubstrateAmount(accountData.feeFrozen, precision: precision) ?? .zero

        return BalanceContext(
            free: free,
            reserved: reserved,
            miscFrozen: miscFrozen,
            feeFrozen: feeFrozen,
            price: price,
            priceChange: priceChange,
            minimalBalance: minimalBalance,
            balanceLocks: [:]
        )
    }

    // TODO: Remove
    func byChangingStakingInfo(
        _ stakingInfo: StakingLedger,
        activeEra: UInt32,
        precision: Int16
    ) -> BalanceContext {
        let redeemable = Decimal
            .fromSubstrateAmount(
                stakingInfo.redeemable(inEra: activeEra),
                precision: precision
            ) ?? .zero

        let bonded = Decimal
            .fromSubstrateAmount(
                stakingInfo.active,
                precision: precision
            ) ?? .zero

        let unbonding = Decimal
            .fromSubstrateAmount(
                stakingInfo.unbonding(inEra: activeEra),
                precision: precision
            ) ?? .zero

        return BalanceContext(
            free: free,
            reserved: reserved,
            miscFrozen: miscFrozen,
            feeFrozen: feeFrozen,
            price: price,
            priceChange: priceChange,
            minimalBalance: minimalBalance,
            balanceLocks: [:]
        )
    }

    func byChangingPrice(_ newPrice: Decimal, newPriceChange: Decimal) -> BalanceContext {
        BalanceContext(
            free: free,
            reserved: reserved,
            miscFrozen: miscFrozen,
            feeFrozen: feeFrozen,
            price: newPrice,
            priceChange: newPriceChange,
            minimalBalance: minimalBalance,
            balanceLocks: [:]
        )
    }

    func byChangingMinimalBalance(to newMinimalBalance: Decimal) -> BalanceContext {
        BalanceContext(
            free: free,
            reserved: reserved,
            miscFrozen: miscFrozen,
            feeFrozen: feeFrozen,
            price: price,
            priceChange: priceChange,
            minimalBalance: newMinimalBalance,
            balanceLocks: [:]
        )
    }
}
