import Foundation

struct TransferMetadataContext {
    static let receiverBalanceKey = "transfer.metadata.receiver.balance.key"

    let receiverBalance: Decimal
}

extension TransferMetadataContext {
    init(data: AccountData, precision: Int16) {
        let free = Decimal
            .fromSubstrateAmount(data.free.value, precision: precision) ?? .zero
        let reserved = Decimal
            .fromSubstrateAmount(data.reserved.value, precision: precision) ?? .zero

        receiverBalance = free + reserved
    }

    init(context: [String: String]) {
        if let stringValue = context[Self.receiverBalanceKey] {
            receiverBalance = Decimal(string: stringValue) ?? .zero
        } else {
            receiverBalance = .zero
        }
    }

    func toContext() -> [String: String] {
        [
            Self.receiverBalanceKey: receiverBalance.stringWithPointSeparator
        ]
    }
}
