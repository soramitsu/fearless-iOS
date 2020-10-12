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

    let free: Decimal
    let reserved: Decimal
    let miscFrozen: Decimal
    let feeFrozen: Decimal

    let bonded: Decimal
    let redeemable: Decimal
    let unbonding: Decimal

    let price: Decimal
    let priceChange: Decimal
}

extension BalanceContext {
    var total: Decimal { free + reserved }
    var frozen: Decimal { reserved + locked }
    var locked: Decimal { max(miscFrozen, feeFrozen) }
    var available: Decimal { free - locked }
}

extension BalanceContext {
    init(context: [String: String]) {
        self.free = Self.parseContext(key: BalanceContext.freeKey, context: context)
        self.reserved = Self.parseContext(key: BalanceContext.reservedKey, context: context)
        self.miscFrozen = Self.parseContext(key: BalanceContext.miscFrozenKey, context: context)
        self.feeFrozen = Self.parseContext(key: BalanceContext.feeFrozenKey, context: context)

        self.bonded = Self.parseContext(key: BalanceContext.bondedKey, context: context)
        self.redeemable = Self.parseContext(key: BalanceContext.redeemableKey, context: context)
        self.unbonding  = Self.parseContext(key: BalanceContext.unbondingKey, context: context)

        self.price = Self.parseContext(key: BalanceContext.priceKey, context: context)
        self.priceChange = Self.parseContext(key: BalanceContext.priceChangeKey, context: context)
    }

    func toContext() -> [String: String] {
        [
            BalanceContext.freeKey: free.stringWithPointSeparator,
            BalanceContext.reservedKey: reserved.stringWithPointSeparator,
            BalanceContext.miscFrozenKey: miscFrozen.stringWithPointSeparator,
            BalanceContext.feeFrozenKey: feeFrozen.stringWithPointSeparator,
            BalanceContext.bondedKey: bonded.stringWithPointSeparator,
            BalanceContext.redeemableKey: redeemable.stringWithPointSeparator,
            BalanceContext.unbondingKey: unbonding.stringWithPointSeparator,
            BalanceContext.priceKey: price.stringWithPointSeparator,
            BalanceContext.priceChangeKey: priceChange.stringWithPointSeparator
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
            .fromSubstrateAmount(accountData.free.value, precision: precision) ?? .zero
        let reserved = Decimal
            .fromSubstrateAmount(accountData.reserved.value, precision: precision) ?? .zero
        let miscFrozen = Decimal
            .fromSubstrateAmount(accountData.miscFrozen.value, precision: precision) ?? .zero
        let feeFrozen = Decimal
            .fromSubstrateAmount(accountData.feeFrozen.value, precision: precision) ?? .zero

        return BalanceContext(free: free,
                              reserved: reserved,
                              miscFrozen: miscFrozen,
                              feeFrozen: feeFrozen,
                              bonded: bonded,
                              redeemable: redeemable,
                              unbonding: unbonding,
                              price: price,
                              priceChange: priceChange)
    }

    func byChangingStakingInfo(_ stakingInfo: StakingLedger,
                               activeEra: UInt32,
                               precision: Int16) -> BalanceContext {
        let redeemable = Decimal
            .fromSubstrateAmount(stakingInfo.redeemable(inEra: activeEra),
                                 precision: precision) ?? .zero

        let bonded = Decimal
            .fromSubstrateAmount(stakingInfo.active,
                                 precision: precision) ?? .zero

        let unbonding = Decimal
            .fromSubstrateAmount(stakingInfo.unbounding(inEra: activeEra),
                                 precision: precision) ?? .zero

        return BalanceContext(free: free,
                              reserved: reserved,
                              miscFrozen: miscFrozen,
                              feeFrozen: feeFrozen,
                              bonded: bonded,
                              redeemable: redeemable,
                              unbonding: unbonding,
                              price: price,
                              priceChange: priceChange)
    }

    func byChangingPrice(_ newPrice: Decimal, newPriceChange: Decimal) -> BalanceContext {
        BalanceContext(free: free,
                       reserved: reserved,
                       miscFrozen: miscFrozen,
                       feeFrozen: feeFrozen,
                       bonded: bonded,
                       redeemable: redeemable,
                       unbonding: unbonding,
                       price: newPrice,
                       priceChange: newPriceChange)
    }
}
