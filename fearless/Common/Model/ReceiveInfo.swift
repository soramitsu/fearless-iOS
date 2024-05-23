import Foundation

public struct ReceiveInfo: Codable, Equatable {
    public var accountId: String
    public var assetId: String?
    public var amount: AmountDecimal?
    public var details: String?

    public init(accountId: String, assetId: String?, amount: AmountDecimal?, details: String?) {
        self.accountId = accountId
        self.assetId = assetId
        self.amount = amount
        self.details = details
    }
}
