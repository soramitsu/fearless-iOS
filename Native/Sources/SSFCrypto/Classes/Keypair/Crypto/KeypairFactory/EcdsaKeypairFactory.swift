import Foundation
import IrohaCrypto
import SSFUtils

public struct EcdsaKeypairFactory: DerivableSeedFactoryProtocol {
    static let hdkdPrefix = "Secp256k1HDKD"

    private let internalFactory = SECKeyFactory()

    public init() {}

    public func createKeypairFromSeed(
        _ seed: Data,
        chaincodeList: [Chaincode]
    ) throws -> IRCryptoKeypairProtocol {
        let childSeed = try deriveChildSeedFromParent(seed, chaincodeList: chaincodeList)
        let childPrivateKey = try SECPrivateKey(rawData: childSeed)
        return try internalFactory.derive(fromPrivateKey: childPrivateKey)
    }

    public func deriveChildSeedFromParent(
        _ seed: Data,
        chaincodeList: [Chaincode]
    ) throws -> Data {
        let scaleEncoder = ScaleEncoder()
        try Self.hdkdPrefix.encode(scaleEncoder: scaleEncoder)
        let prefix = scaleEncoder.encode()

        return try chaincodeList.reduce(seed) { currentSeed, chaincode in
            guard chaincode.type == .hard else {
                throw KeypairFactoryError.unsupportedChaincodeType
            }

            return try (prefix + currentSeed + chaincode.data).blake2b32()
        }
    }
}
