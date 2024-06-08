import Foundation

struct AssetTransactionFee: Codable, Equatable {
    let identifier: String
    let assetId: String
    let amount: AmountDecimal
    let context: [String: String]?

    init(identifier: String, assetId: String, amount: AmountDecimal, context: [String: String]?) {
        self.identifier = identifier
        self.assetId = assetId
        self.amount = amount
        self.context = context
    }
}
