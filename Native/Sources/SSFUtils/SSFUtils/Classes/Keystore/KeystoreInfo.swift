import Foundation
import SSFModels

public struct KeystoreInfo {
    public let address: String?
    public let chainType: ChainType?
    public let cryptoType: CryptoType
    public let meta: KeystoreMeta?
    public let isEthereum: Bool
}
