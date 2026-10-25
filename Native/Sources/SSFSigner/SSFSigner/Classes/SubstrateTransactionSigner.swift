import IrohaCrypto
import SSFCrypto
import SSFModels

public class SubstrateTransactionSigner: TransactionSignerProtocol {
    private let publicKeyData: Data
    private let secretKeyData: Data
    private let cryptoType: CryptoType

    public init(
        publicKeyData: Data,
        secretKeyData: Data,
        cryptoType: CryptoType
    ) {
        self.publicKeyData = publicKeyData
        self.secretKeyData = secretKeyData
        self.cryptoType = cryptoType
    }

    public func sign(_ originalData: Data) throws -> IRSignatureProtocol {
        switch cryptoType {
        case .sr25519:
            return try signSr25519(
                originalData,
                secretKeyData: secretKeyData,
                publicKeyData: publicKeyData
            )
        case .ed25519:
            return try signEd25519(
                originalData,
                secretKey: secretKeyData
            )
        case .ecdsa:
            return try signEcdsa(
                originalData,
                secretKey: secretKeyData
            )
        }
    }
}
