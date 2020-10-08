import Foundation

struct BalanceContext {
    static let freeKey = "account.balance.free.key"
    static let reservedKey = "account.balance.reserved.key"
    static let miscFrozenKey = "account.balance.misc.frozen.key"
    static let feeFrozenKey = "account.balance.fee.frozen.key"
    static let priceKey = "account.balance.price.key"
    static let priceChangeKey = "account.balance.price.change.key"

    let free: Decimal
    let reserved: Decimal
    let miscFrozen: Decimal
    let feeFrozen: Decimal

    let price: Decimal
    let priceChange: Decimal
}

extension BalanceContext {
    var total: Decimal { free + reserved }
    var frozen: Decimal { reserved + max(miscFrozen, feeFrozen) }
    var available: Decimal { free - max(miscFrozen, feeFrozen) }
}

extension BalanceContext {
    init(context: [String: String]) {
        if let freeString = context[BalanceContext.freeKey],
            let free = Decimal(string: freeString) {
            self.free = free
        } else {
            self.free = 0
        }

        if let reservedString = context[BalanceContext.reservedKey],
            let reserved = Decimal(string: reservedString) {
            self.reserved = reserved
        } else {
            self.reserved = 0
        }

        if let miscFrozenString = context[BalanceContext.miscFrozenKey],
            let miscFrozen = Decimal(string: miscFrozenString) {
            self.miscFrozen = miscFrozen
        } else {
            self.miscFrozen = 0
        }

        if let feeFrozenString = context[BalanceContext.feeFrozenKey],
            let feeFrozen = Decimal(string: feeFrozenString) {
            self.feeFrozen = feeFrozen
        } else {
            self.feeFrozen = 0
        }

        if let priceString = context[BalanceContext.priceKey],
           let price = Decimal(string: priceString) {
            self.price = price
        } else {
            self.price = 0
        }

        if let priceChangeString = context[BalanceContext.priceChangeKey],
           let priceChange = Decimal(string: priceChangeString) {
            self.priceChange = priceChange
        } else {
            self.priceChange = 0
        }
    }

    func toContext() -> [String: String] {
        [
            BalanceContext.freeKey: free.stringWithPointSeparator,
            BalanceContext.reservedKey: reserved.stringWithPointSeparator,
            BalanceContext.miscFrozenKey: miscFrozen.stringWithPointSeparator,
            BalanceContext.feeFrozenKey: feeFrozen.stringWithPointSeparator,
            BalanceContext.priceKey: price.stringWithPointSeparator,
            BalanceContext.priceChangeKey: priceChange.stringWithPointSeparator
        ]
    }
}

extension BalanceContext {
    func byChangingPrice(_ newPrice: Decimal, newPriceChange: Decimal) -> BalanceContext {
        BalanceContext(free: free,
                       reserved: reserved,
                       miscFrozen: miscFrozen,
                       feeFrozen: feeFrozen,
                       price: newPrice,
                       priceChange: newPriceChange)
    }
}
