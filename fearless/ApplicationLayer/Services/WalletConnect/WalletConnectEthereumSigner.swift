import Foundation
import FearlessWalletConnect
import SSFUtils
import Web3
import SSFModels
import SSFSigner

final class WalletConnectEthereumSignerImpl: WalletConnectPayloadSigner {
    enum SignType {
        case message(WalletConnectMessage, transactionSigner: TransactionSignerProtocol)
        case typedData(WalletConnectTypedData, transactionSigner: TransactionSignerProtocol)
        case sendTransaction(WalletConnectEthereumTransactionQuote, transferService: WalletConnectEthereumTransferService)
        case signTransaction(WalletConnectEthereumTransactionQuote, transferService: WalletConnectEthereumTransferService)
    }

    private let signType: SignType

    init(signType: SignType) {
        self.signType = signType
    }

    func sign() async throws -> AnyCodable {
        switch signType {
        case let .message(message, transactionSigner):
            guard let prefixedMessage = message.bytes.ethereumPersonalSignMessage() else {
                throw WalletConnectRequestError.unsupported
            }
            return try signHashed(prefixedMessage, transactionSigner: transactionSigner)
        case let .typedData(typedData, transactionSigner):
            return try signHashed(typedData.signingInput, transactionSigner: transactionSigner)
        case let .sendTransaction(quote, transferService):
            return AnyCodable(try await transferService.send(quote: quote))
        case let .signTransaction(quote, transferService):
            return AnyCodable(try transferService.sign(quote: quote))
        }
    }

    // MARK: - Private methods

    /// The signer hashes the input with Keccak-256. Signatures returned to dApps use the
    /// JSON-RPC recovery id convention (27 or 28), which `ecrecover` expects.
    private func signHashed(
        _ input: Data,
        transactionSigner: TransactionSignerProtocol
    ) throws -> AnyCodable {
        var signature = try transactionSigner.sign(input).rawData()
        if signature.count == 65, signature[64] < 27 {
            signature[64] += 27
        }
        return AnyCodable(signature.toHex(includePrefix: true))
    }
}
