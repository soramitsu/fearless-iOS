import Foundation
import SSFCrypto
import SSFModels
import SSFUtils

// sourcery: AutoMockable
protocol CommonCrypto {
    func getQuery(
        seed: Data,
        derivationPath: String,
        cryptoType: CryptoType,
        ethereumBased: Bool
    ) throws -> AccountQuery

    func getJunctionResult(
        from derivationPath: String,
        ethereumBased: Bool
    ) throws -> JunctionResult?

    func generateKeypair(
        from seed: Data,
        chaincodes: [Chaincode],
        cryptoType: CryptoType,
        isEthereum: Bool
    ) throws -> (publicKey: Data, secretKey: Data)

    func createKeypairFactory(
        _ cryptoType: CryptoType,
        isEthereumBased: Bool
    ) -> KeypairFactoryProtocol
}

final class CommonCryptoImpl: CommonCrypto {
    func getQuery(
        seed: Data,
        derivationPath: String,
        cryptoType: CryptoType,
        ethereumBased: Bool
    ) throws -> AccountQuery {
        let junctionResult = try getJunctionResult(
            from: derivationPath,
            ethereumBased: ethereumBased
        )

        let chaincodes = junctionResult?.chaincodes ?? []
        let keypair = try generateKeypair(
            from: seed,
            chaincodes: chaincodes,
            cryptoType: cryptoType,
            isEthereum: ethereumBased
        )

        let address = ethereumBased
            ? try keypair.publicKey.ethereumAddressFromPublicKey()
            : try keypair.publicKey.publicKeyToAccountId()

        return AccountQuery(
            publicKey: keypair.publicKey,
            privateKey: keypair.secretKey,
            address: address
        )
    }

    func getJunctionResult(
        from derivationPath: String,
        ethereumBased: Bool
    ) throws -> JunctionResult? {
        guard !derivationPath.isEmpty else { return nil }

        let junctionFactory = ethereumBased
            ? BIP32JunctionFactory()
            : SubstrateJunctionFactory()

        return try junctionFactory.parse(path: derivationPath)
    }

    func generateKeypair(
        from seed: Data,
        chaincodes: [Chaincode],
        cryptoType: CryptoType,
        isEthereum: Bool
    ) throws -> (publicKey: Data, secretKey: Data) {
        let keypairFactory = createKeypairFactory(
            cryptoType,
            isEthereumBased: isEthereum
        )

        let keypair = try keypairFactory.createKeypairFromSeed(
            seed,
            chaincodeList: chaincodes
        )

        if cryptoType == .sr25519 || isEthereum {
            return (
                publicKey: keypair.publicKey().rawData(),
                secretKey: keypair.privateKey().rawData()
            )
        } else {
            guard let factory = keypairFactory as? DerivableSeedFactoryProtocol else {
                throw JsonCreatorError.jsonFactoryError
            }

            let secretKey = try factory.deriveChildSeedFromParent(seed, chaincodeList: chaincodes)
            return (
                publicKey: keypair.publicKey().rawData(),
                secretKey: secretKey
            )
        }
    }

    func createKeypairFactory(
        _ cryptoType: CryptoType,
        isEthereumBased: Bool
    ) -> KeypairFactoryProtocol {
        if isEthereumBased {
            return BIP32KeypairFactory()
        } else {
            switch cryptoType {
            case .sr25519:
                return SR25519KeypairFactory()
            case .ed25519:
                return Ed25519KeypairFactory()
            case .ecdsa:
                return EcdsaKeypairFactory()
            }
        }
    }
}
