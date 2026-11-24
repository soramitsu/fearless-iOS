import Foundation
import SSFModels
import Web3

/// Signs and sends WalletConnect transactions exactly as quoted: no field, the gas
/// values included, is fetched again after the user confirms.
protocol WalletConnectEthereumTransferService {
    func sign(quote: WalletConnectEthereumTransactionQuote) throws -> EthereumData
    func send(quote: WalletConnectEthereumTransactionQuote) async throws -> EthereumData
}

extension WalletConnectEthereumTransactionQuote {
    func makeTransaction() throws -> EthereumTransaction {
        let sender = try EthereumAddress(rawAddress: Array(from))
        let recipient = try EthereumAddress(rawAddress: Array(to))

        switch fee {
        case let .legacy(gasPrice):
            return EthereumTransaction(
                nonce: EthereumQuantity(quantity: nonce),
                gasPrice: EthereumQuantity(quantity: gasPrice),
                gasLimit: EthereumQuantity(quantity: gasLimit),
                from: sender,
                to: recipient,
                value: EthereumQuantity(quantity: value),
                data: EthereumData(Array(data)),
                accessList: [:],
                transactionType: .legacy
            )
        case let .eip1559(maxFeePerGas, maxPriorityFeePerGas):
            return EthereumTransaction(
                nonce: EthereumQuantity(quantity: nonce),
                maxFeePerGas: EthereumQuantity(quantity: maxFeePerGas),
                maxPriorityFeePerGas: EthereumQuantity(quantity: maxPriorityFeePerGas),
                gasLimit: EthereumQuantity(quantity: gasLimit),
                from: sender,
                to: recipient,
                value: EthereumQuantity(quantity: value),
                data: EthereumData(Array(data)),
                accessList: [:],
                transactionType: .eip1559
            )
        }
    }
}
