import Foundation
import SoraKeystore
import FearlessUtils
import IrohaCrypto

protocol KeystoreExportWrapperProtocol {
    func export(
        chainAccount: ChainAccountResponse,
        password: String?,
        address: String,
        metaId: String,
        accountId: AccountId?,
        genesisHash: String
    ) throws -> Data
}

enum KeystoreExportWrapperError: Error {
    case missingSecretKey
    case unsupportedCryptoType
}

final class KeystoreExportWrapper: KeystoreExportWrapperProtocol {
    let keystore: KeystoreProtocol

    private lazy var jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    private lazy var ss58Factory = SS58AddressFactory()

    init(keystore: KeystoreProtocol) {
        self.keystore = keystore
    }

    func export(
        chainAccount: ChainAccountResponse,
        password: String?,
        address: String,
        metaId: String,
        accountId: AccountId?,
        genesisHash: String
    ) throws -> Data {
        let secretKeyTag = chainAccount.isEthereumBased
            ? KeystoreTagV2.ethereumSecretKeyTagForMetaId(metaId, accountId: accountId)
            : KeystoreTagV2.substrateSecretKeyTagForMetaId(metaId, accountId: accountId)
        var secretKey = try keystore.fetchKey(for: secretKeyTag)

        let derivationPathTag = chainAccount.isEthereumBased
            ? KeystoreTagV2.ethereumDerivationTagForMetaId(metaId, accountId: accountId)
            : KeystoreTagV2.substrateDerivationTagForMetaId(metaId, accountId: accountId)

        let seedTag = chainAccount.isEthereumBased
            ? KeystoreTagV2.ethereumSeedTagForMetaId(metaId, accountId: accountId)
            : KeystoreTagV2.substrateSeedTagForMetaId(metaId, accountId: accountId)

        if let derivationPath = try keystore.fetchDeriviationForAddress(derivationPathTag),
           let seed = try keystore.fetchSeedForAddress(seedTag) {
            let junctionFactory = chainAccount.isEthereumBased ?
                BIP32JunctionFactory() : SubstrateJunctionFactory()
            let junctionResult = try junctionFactory.parse(path: derivationPath)
            let keypair = try generateKeypair(
                from: seed,
                chaincodes: junctionResult.chaincodes,
                cryptoType: chainAccount.cryptoType,
                isEthereum: chainAccount.isEthereumBased
            )
            secretKey = keypair.secretKey
        }

        var builder = KeystoreBuilder().with(name: chainAccount.name)

        if let genesisHashData = try? Data(hexString: genesisHash) {
            builder = builder.with(genesisHash: genesisHashData.toHex(includePrefix: true))
        }

        guard let cryptoType = FearlessUtils.CryptoType(onChainType: chainAccount.cryptoType.rawValue) else {
            throw KeystoreExportWrapperError.unsupportedCryptoType
        }

        let keystoreData = KeystoreData(
            address: address,
            secretKeyData: secretKey,
            publicKeyData: chainAccount.publicKey,
            cryptoType: cryptoType
        )

        let definition = try builder.build(
            from: keystoreData,
            password: password,
            isEthereum: chainAccount.isEthereumBased
        )

        return try jsonEncoder.encode(definition)
    }
}

private extension KeystoreExportWrapper {
    func generateKeypair(
        from seed: Data,
        chaincodes: [Chaincode],
        cryptoType: CryptoType,
        isEthereum: Bool
    ) throws -> (publicKey: Data, secretKey: Data) {
        let keypairFactory = createKeypairFactory(cryptoType, isEthereumBased: isEthereum)

        let keypair = try keypairFactory.createKeypairFromSeed(
            seed,
            chaincodeList: chaincodes
        )

        if isEthereum {
            let privateKey = try SECPrivateKey(rawData: seed)

            return (
                publicKey: try SECKeyFactory().derive(fromPrivateKey: privateKey).publicKey().rawData(),
                secretKey: seed
            )

        } else if cryptoType == .sr25519 {
            return (
                publicKey: keypair.publicKey().rawData(),
                secretKey: keypair.privateKey().rawData()
            )
        } else {
            guard let factory = keypairFactory as? DerivableSeedFactoryProtocol else {
                throw AccountOperationFactoryError.keypairFactoryFailure
            }

            let secretKey = try factory.deriveChildSeedFromParent(seed, chaincodeList: chaincodes)
            return (
                publicKey: keypair.publicKey().rawData(),
                secretKey: secretKey
            )
        }
    }

    func createKeypairFactory(_ cryptoType: CryptoType, isEthereumBased: Bool) -> KeypairFactoryProtocol {
        switch cryptoType {
        case .sr25519:
            return SR25519KeypairFactory()
        case .ed25519:
            return Ed25519KeypairFactory()
        case .ecdsa:
            if isEthereumBased {
                return BIP32KeypairFactory()
            }
            return EcdsaKeypairFactory()
        }
    }
}
