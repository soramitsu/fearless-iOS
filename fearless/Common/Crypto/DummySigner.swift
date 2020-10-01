import Foundation
import IrohaCrypto

enum DummySigningType {
    case sr25519(secretKeyData: Data, publicKeyData: Data)
    case ed25519(seed: Data)
    case ecdsa(seed: Data)
}

final class DummySigner: SigningWrapperProtocol {
    let type: DummySigningType

    init(cryptoType: CryptoType, seed: Data = Data(repeating: 1, count: 32)) throws {
        switch cryptoType {
        case .sr25519:
            let keypair = try SNKeyFactory().createKeypair(fromSeed: seed)
            type = .sr25519(secretKeyData: keypair.privateKey().rawData(),
                            publicKeyData: keypair.publicKey().rawData())
        case .ed25519:
            type = .ed25519(seed: seed)
        case .ecdsa:
            type = .ecdsa(seed: seed)
        }

    }

    func sign(_ originalData: Data) throws -> IRSignatureProtocol {
        switch type {
        case .sr25519(let secretKeyData, let publicKeyData):
            return try signSr25519(originalData,
                                   secretKeyData: secretKeyData,
                                   publicKeyData: publicKeyData)
        case .ed25519(let seed):
            return try signEd25519(originalData, secretKey: seed)
        case .ecdsa(let seed):
            return try signEcdsa(originalData, secretKey: seed)
        }
    }
}
