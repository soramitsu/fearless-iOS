import Foundation
import SSFModels

public enum TransactionSignerAssembly {
    public static func signer(
        for chainType: ChainBaseType,
        publicKeyData: Data,
        secretKeyData: Data,
        cryptoType: CryptoType
    ) -> TransactionSignerProtocol {
        switch chainType {
        case .substrate:
            return SubstrateTransactionSigner(
                publicKeyData: publicKeyData,
                secretKeyData: secretKeyData,
                cryptoType: cryptoType
            )
        case .ethereum:
            return EthereumTransactionSigner(
                publicKeyData: publicKeyData,
                secretKeyData: secretKeyData
            )
        }
    }
}
