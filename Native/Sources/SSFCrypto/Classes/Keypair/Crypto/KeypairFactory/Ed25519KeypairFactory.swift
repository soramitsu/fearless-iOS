import Foundation
import IrohaCrypto
import SSFUtils

public struct Ed25519KeypairFactory: DerivableSeedFactoryProtocol {
    static let hdkdPrefix = "Ed25519HDKD"

    private let internalFactory = EDKeyFactory()

    public init() {}

    public func createKeypairFromSeed(
        _ seed: Data,
        chaincodeList: [Chaincode]
    ) throws -> IRCryptoKeypairProtocol {
        let childSeed = try deriveChildSeedFromParent(
            seed,
            chaincodeList: chaincodeList
        )

        return try internalFactory.derive(fromSeed: childSeed)
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
