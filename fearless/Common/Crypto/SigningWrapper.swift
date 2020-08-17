import Foundation
import IrohaCrypto
import SoraKeystore
import FearlessUtils

enum SigningWrapperError: Error {
    case missingSelectedAccount
    case missingSecretKey
}

final class SigningWrapper: IRSignatureCreatorProtocol {
    let keystore: KeystoreProtocol
    let settings: SettingsManagerProtocol

    init(keystore: KeystoreProtocol, settings: SettingsManagerProtocol) {
        self.keystore = keystore
        self.settings = settings
    }

    func sign(_ originalData: Data) throws -> IRSignatureProtocol {
        guard let selectedAccount = settings.selectedAccount else {
            throw SigningWrapperError.missingSelectedAccount
        }

        guard let secretKey = try keystore.fetchSecretKeyForAddress(selectedAccount.address) else {
            throw SigningWrapperError.missingSecretKey
        }

        switch selectedAccount.cryptoType {
        case .sr25519:
            return try signSr25519(originalData,
                                   secretKeyData: secretKey,
                                   publicKeyData: selectedAccount.publicKeyData)
        case .ed25519:
            return try signEd25519(originalData,
                                   secretKey: secretKey)
        case .ecdsa:
            return try signEcdsa(originalData,
                                 secretKey: secretKey)
        }
    }

    private func signSr25519(_ originalData: Data, secretKeyData: Data, publicKeyData: Data) throws
        -> IRSignatureProtocol {

        let privateKey = try SNPrivateKey(rawData: secretKeyData)
        let publicKey = try SNPublicKey(rawData: publicKeyData)

        let signer = SNSigner(keypair: SNKeypair(privateKey: privateKey, publicKey: publicKey))
        let signature = try signer.sign(originalData)

        return signature
    }

    private func signEd25519(_ originalData: Data, secretKey: Data) throws -> IRSignatureProtocol {
        let keypairFactory = Ed25519KeypairFactory()
        let privateKey = try keypairFactory
            .createKeypairFromSeed(secretKey.miniSeed, chaincodeList: [])
            .privateKey()

        let signer = EDSigner(privateKey: privateKey)

        return try signer.sign(originalData)
    }

    private func signEcdsa(_ originalData: Data, secretKey: Data) throws -> IRSignatureProtocol {
        let keypairFactory = EcdsaKeypairFactory()
        let privateKey = try keypairFactory
            .createKeypairFromSeed(secretKey.miniSeed, chaincodeList: [])
            .privateKey()

        let signer = SECSigner(privateKey: privateKey)

        return try signer.sign(originalData)
    }
}
