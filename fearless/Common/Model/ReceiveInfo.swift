import Foundation

struct ReceiveInfo: Codable, Equatable {
    var accountId: String
    var assetId: String?
    var amount: AmountDecimal?
    var details: String?

    init(accountId: String, assetId: String?, amount: AmountDecimal?, details: String?) {
        self.accountId = accountId
        self.assetId = assetId
        self.amount = amount
        self.details = details
    }
}
