import Foundation
import SSFModels

public struct KeystoreData: Equatable {
    public let address: String?
    public let secretKeyData: Data
    public let publicKeyData: Data
    public let cryptoType: CryptoType

    public init(
        address: String?,
        secretKeyData: Data,
        publicKeyData: Data,
        cryptoType: CryptoType
    ) {
        self.address = address
        self.secretKeyData = secretKeyData
        self.publicKeyData = publicKeyData
        self.cryptoType = cryptoType
    }
}
