import Foundation

public struct SoraQRInfo: QRInfo, Equatable {
    public let prefix: String
    public let address: String
    public let rawPublicKey: Data
    public let username: String
    public let assetId: String
    public let amount: String?

    public init(
        prefix: String = SubstrateQRConstants.prefix,
        address: String,
        rawPublicKey: Data,
        username: String,
        assetId: String,
        amount: String?
    ) {
        self.prefix = prefix
        self.address = address
        self.rawPublicKey = rawPublicKey
        self.username = username
        self.assetId = assetId
        self.amount = amount
    }
}
