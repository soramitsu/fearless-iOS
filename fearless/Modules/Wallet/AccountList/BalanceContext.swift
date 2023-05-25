import Foundation

struct BalanceContext {
    static let freeKey = "account.balance.free.key"
    static let reservedKey = "account.balance.reserved.key"
    static let frozenKey = "account.balance.frozen.key"

    static let priceKey = "account.balance.price.key"
    static let priceChangeKey = "account.balance.price.change.key"

    static let minimalBalanceKey = "account.balance.minimal.key"

    static let balanceLocksKey = "account.balance.locks.key"

    let free: Decimal
    let reserved: Decimal
    let frozen: Decimal

    let price: Decimal
    let priceChange: Decimal

    let minimalBalance: Decimal

    let balanceLocks: BalanceLocks
}

extension BalanceContext {
    var total: Decimal { free + reserved }
    var locked: Decimal { frozen }
    var available: Decimal { free - locked }
}

extension BalanceContext {
    init(context: [String: String]) {
        free = Self.parseContext(key: BalanceContext.freeKey, context: context)
        reserved = Self.parseContext(key: BalanceContext.reservedKey, context: context)
        frozen = Self.parseContext(key: BalanceContext.frozenKey, context: context)

        price = Self.parseContext(key: BalanceContext.priceKey, context: context)
        priceChange = Self.parseContext(key: BalanceContext.priceChangeKey, context: context)

        minimalBalance = Self.parseContext(key: BalanceContext.minimalBalanceKey, context: context)

        balanceLocks = Self.parseJSONContext(key: BalanceContext.balanceLocksKey, context: context)
    }

    func toContext() -> [String: String] {
        let locksStringRepresentation: String = {
            guard let locksJSON = try? JSONEncoder().encode(balanceLocks) else {
                return ""
            }

            return String(data: locksJSON, encoding: .utf8) ?? ""
        }()

        return [
            BalanceContext.freeKey: free.stringWithPointSeparator,
            BalanceContext.reservedKey: reserved.stringWithPointSeparator,
            BalanceContext.frozenKey: frozen.stringWithPointSeparator,
            BalanceContext.priceKey: price.stringWithPointSeparator,
            BalanceContext.priceChangeKey: priceChange.stringWithPointSeparator,
            BalanceContext.minimalBalanceKey: minimalBalance.stringWithPointSeparator,
            BalanceContext.balanceLocksKey: locksStringRepresentation
        ]
    }

    private static func parseContext(key: String, context: [String: String]) -> Decimal {
        if let stringValue = context[key] {
            return Decimal(string: stringValue) ?? .zero
        } else {
            return .zero
        }
    }

    private static func parseJSONContext(key: String, context: [String: String]) -> [BalanceLock] {
        guard let locksStringRepresentation = context[key] else { return [] }

        guard let JSONData = locksStringRepresentation.data(using: .utf8) else {
            return []
        }

        let balanceLocks = try? JSONDecoder().decode(
            BalanceLocks.self,
            from: JSONData
        )

        return balanceLocks ?? []
    }
}

extension BalanceContext {
    func byChangingAccountInfo(_ accountData: AccountData, precision: Int16) -> BalanceContext {
        let free = Decimal
            .fromSubstrateAmount(accountData.free, precision: precision) ?? .zero
        let reserved = Decimal
            .fromSubstrateAmount(accountData.reserved, precision: precision) ?? .zero
        let frozen = Decimal
            .fromSubstrateAmount(accountData.frozen, precision: precision) ?? .zero

        return BalanceContext(
            free: free,
            reserved: reserved,
            frozen: frozen,
            price: price,
            priceChange: priceChange,
            minimalBalance: minimalBalance,
            balanceLocks: balanceLocks
        )
    }

    func byChangingBalanceLocks(
        _ updatedLocks: BalanceLocks
    ) -> BalanceContext {
        BalanceContext(
            free: free,
            reserved: reserved,
            frozen: frozen,
            price: price,
            priceChange: priceChange,
            minimalBalance: minimalBalance,
            balanceLocks: updatedLocks
        )
    }

    func byChangingPrice(_ newPrice: Decimal, newPriceChange: Decimal) -> BalanceContext {
        BalanceContext(
            free: free,
            reserved: reserved,
            frozen: frozen,
            price: newPrice,
            priceChange: newPriceChange,
            minimalBalance: minimalBalance,
            balanceLocks: balanceLocks
        )
    }

    func byChangingMinimalBalance(to newMinimalBalance: Decimal) -> BalanceContext {
        BalanceContext(
            free: free,
            reserved: reserved,
            frozen: frozen,
            price: price,
            priceChange: priceChange,
            minimalBalance: newMinimalBalance,
            balanceLocks: balanceLocks
        )
    }
}
