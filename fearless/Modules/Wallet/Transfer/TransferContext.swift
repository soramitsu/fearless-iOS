import Foundation

struct TransferContext {
    static let balanceKey = "transfer.balance.key"
    static let existentialDepositKey = "transfer.existensial.key"

    let balance: Decimal
    let existentialDeposit: Decimal
}

extension TransferContext {
    init(context: [String: String]) {
        if let balanceString = context[TransferContext.balanceKey],
           let balance = Decimal(string: balanceString) {
            self.balance = balance
        } else {
            self.balance = 0
        }

        if let existentialDepositString = context[TransferContext.existentialDepositKey],
           let existentialDeposit = Decimal(string: existentialDepositString) {
            self.existentialDeposit = existentialDeposit
        } else {
            self.existentialDeposit = 0
        }
    }

    func toContext() -> [String: String] {
        [
            TransferContext.balanceKey: balance.stringWithPointSeparator,
            TransferContext.existentialDepositKey: existentialDeposit.stringWithPointSeparator
        ]
    }
}
