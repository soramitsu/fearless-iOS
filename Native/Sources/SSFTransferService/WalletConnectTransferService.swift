import Foundation
import SSFModels
import Web3

public protocol WalletConnectTransferService {
    func sign(
        transaction: EthereumTransaction,
        chain: ChainModel
    ) throws -> EthereumData
    func send(
        transaction: EthereumTransaction,
        chain: ChainModel
    ) async throws -> EthereumData
}

public final class WalletConnectTransferServiceDefault: WalletConnectTransferService {
    private let privateKey: EthereumPrivateKey
    private let ethereumService: EthereumService

    init(
        privateKey: EthereumPrivateKey,
        ethereumService: EthereumService
    ) {
        self.privateKey = privateKey
        self.ethereumService = ethereumService
    }

    // MARK: - WalletConnectTransferService

    public func sign(
        transaction: EthereumTransaction,
        chain: ChainModel
    ) throws -> EthereumData {
        let chainId = EthereumQuantity(chain.chainId.hexToBytes())
        let signed = try transaction.sign(with: privateKey, chainId: chainId)

        return try signed.rawTransaction()
    }

    public func send(
        transaction: EthereumTransaction,
        chain: ChainModel
    ) async throws -> EthereumData {
        guard let receiverAddress = transaction.to,
              let senderAddress = transaction.from else
        {
            throw TransferServiceError.transferFailed(reason: "Wallet connect invalid params")
        }
        let quantity: EthereumQuantity
        if let value = transaction.value {
            quantity = value
        } else {
            quantity = EthereumQuantity(quantity: .zero)
        }

        let call = EthereumCall(
            from: senderAddress,
            to: receiverAddress,
            gas: transaction.gasLimit,
            gasPrice: transaction.gasPrice,
            value: transaction.value,
            data: transaction.data
        )
        async let nonce = try ethereumService.queryNonce(ethereumAddress: senderAddress)
        async let gasPrice = try ethereumService.queryGasPrice()
        async let gasLimit = try ethereumService.queryGasLimit(call: call)

        let tx = try await EthereumTransaction(
            nonce: nonce,
            gasPrice: gasPrice,
            maxFeePerGas: gasPrice,
            maxPriorityFeePerGas: gasPrice,
            gasLimit: gasLimit,
            from: senderAddress,
            to: receiverAddress,
            value: quantity,
            data: transaction.data,
            accessList: [:],
            transactionType: .eip1559
        )
        guard let chainId = BigUInt(string: chain.chainId) else {
            throw EthereumSignedTransaction.Error
                .chainIdNotSet(msg: "WC transactions need a chainId")
        }
        let chainIdValue = EthereumQuantity(quantity: chainId)
        let rawTransaction = try tx.sign(with: privateKey, chainId: chainIdValue)

        return try await ethereumService.send(rawTransaction)
    }
}
