import Foundation
import IrohaCrypto
import FearlessUtils

protocol SigningWrapperProtocol: IRSignatureCreatorProtocol {}

extension SigningWrapperProtocol {
    func signSr25519(_ originalData: Data, secretKeyData: Data, publicKeyData: Data) throws
        -> IRSignatureProtocol {

        let privateKey = try SNPrivateKey(rawData: secretKeyData)
        let publicKey = try SNPublicKey(rawData: publicKeyData)

        let signer = SNSigner(keypair: SNKeypair(privateKey: privateKey, publicKey: publicKey))
        let signature = try signer.sign(originalData)

        return signature
    }

    func signEd25519(_ originalData: Data, secretKey: Data) throws -> IRSignatureProtocol {
        let keypairFactory = Ed25519KeypairFactory()
        let privateKey = try keypairFactory
            .createKeypairFromSeed(secretKey.miniSeed, chaincodeList: [])
            .privateKey()

        let signer = EDSigner(privateKey: privateKey)

        return try signer.sign(originalData)
    }

    func signEcdsa(_ originalData: Data, secretKey: Data) throws -> IRSignatureProtocol {
        let keypairFactory = EcdsaKeypairFactory()
        let privateKey = try keypairFactory
            .createKeypairFromSeed(secretKey.miniSeed, chaincodeList: [])
            .privateKey()

        let signer = SECSigner(privateKey: privateKey)

        let hashedData = try originalData.blake2b32()
        return try signer.sign(hashedData)
    }
}
