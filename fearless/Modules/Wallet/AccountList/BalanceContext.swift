import Foundation

struct BalanceContext {
    static let priceKey = "account.balance.price"
    static let priceChangeKey = "account.balance.price.change.key"

    let price: Decimal
    let priceChange: Decimal
}

extension BalanceContext {
    init(context: [String: String]) {
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
            BalanceContext.priceKey: price.stringWithPointSeparator,
            BalanceContext.priceChangeKey: priceChange.stringWithPointSeparator
        ]
    }
}
