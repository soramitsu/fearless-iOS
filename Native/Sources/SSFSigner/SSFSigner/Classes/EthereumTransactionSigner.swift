import Foundation
import IrohaCrypto
import SSFCrypto

public final class EthereumTransactionSigner: TransactionSignerProtocol {
    private let publicKeyData: Data
    private let secretKeyData: Data

    public init(
        publicKeyData: Data,
        secretKeyData: Data
    ) {
        self.publicKeyData = publicKeyData
        self.secretKeyData = secretKeyData
    }

    public func sign(_ originalData: Data) throws -> IRSignatureProtocol {
        let keypairFactory = EcdsaKeypairFactory()
        let privateKey = try keypairFactory
            .createKeypairFromSeed(secretKeyData.miniSeed, chaincodeList: [])
            .privateKey()

        let signer = SECSigner(privateKey: privateKey)

        let hashedData = try originalData.keccak256()
        return try signer.sign(hashedData)
    }
}
