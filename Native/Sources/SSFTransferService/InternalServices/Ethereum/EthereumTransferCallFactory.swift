import Foundation
import SSFChainConnection
import SSFModels
import Web3
import Web3ContractABI

protocol EthereumTransferCallFactory {
    func signNative(transfer: EthereumTransfer, chainAsset: ChainAsset) async throws
        -> EthereumSignedTransaction
    func signERC20(transfer: EthereumTransfer, chainAsset: ChainAsset) async throws
        -> EthereumSignedTransaction
}

final class EthereumTransferCallFactoryDefault: EthereumTransferCallFactory {
    private let ethereumService: EthereumService
    private let senderAddress: AccountAddress
    private let privateKey: EthereumPrivateKey

    init(
        ethereumService: EthereumService,
        senderAddress: AccountAddress,
        privateKey: EthereumPrivateKey
    ) {
        self.ethereumService = ethereumService
        self.senderAddress = senderAddress
        self.privateKey = privateKey
    }

    func signNative(
        transfer: EthereumTransfer,
        chainAsset: ChainAsset
    ) async throws -> EthereumSignedTransaction {
        guard let chainId = BigUInt(string: chainAsset.chain.chainId) else {
            let error = EthereumSignedTransaction.Error
                .chainIdNotSet(msg: "EIP1559 transactions need a chainId")
            throw error
        }
        let chainIdValue = EthereumQuantity(quantity: chainId)
        let receiverAddress = try EthereumAddress(rawAddress: transfer.receiver.hexToBytes())
        let senderAddress = try EthereumAddress(rawAddress: self.senderAddress.hexToBytes())
        let quantity = EthereumQuantity(quantity: transfer.amount)
        let call = EthereumCall(to: receiverAddress, value: quantity)

        async let nonce = try ethereumService.queryNonce(ethereumAddress: senderAddress)
        async let gasPrice = try ethereumService.queryGasPrice()
        async let gasLimit = try ethereumService.queryGasLimit(call: call)
        async let supportsEip1559 = ethereumService.checkChainSupportEip1559()

        let transactionType: EthereumTransaction
            .TransactionType = await supportsEip1559 ? .eip1559 : .legacy
        let tx = try await EthereumTransaction(
            nonce: nonce,
            gasPrice: gasPrice,
            maxFeePerGas: gasPrice,
            maxPriorityFeePerGas: gasPrice,
            gasLimit: gasLimit,
            from: senderAddress,
            to: receiverAddress,
            value: quantity,
            accessList: [:],
            transactionType: transactionType
        )

        return try tx.sign(with: privateKey, chainId: chainIdValue)
    }

    func signERC20(
        transfer: EthereumTransfer,
        chainAsset: ChainAsset
    ) async throws -> EthereumSignedTransaction {
        guard let chainId = BigUInt(string: chainAsset.chain.chainId) else {
            throw EthereumSignedTransaction.Error
                .chainIdNotSet(msg: "EIP1559 transactions need a chainId")
        }
        let chainIdValue = EthereumQuantity(quantity: chainId)
        let senderAddress = try EthereumAddress(rawAddress: self.senderAddress.hexToBytes())
        let address = try EthereumAddress(rawAddress: transfer.receiver.hexToBytes())
        let contractAddress = try EthereumAddress(rawAddress: chainAsset.asset.id.hexToBytes())
        let contract = ethereumService.connection.Contract(
            type: GenericERC20Contract.self,
            address: contractAddress
        )
        let transferCall = contract.transfer(to: address, value: transfer.amount)

        async let nonce = try ethereumService.queryNonce(ethereumAddress: senderAddress)
        async let gasPrice = try ethereumService.queryGasPrice()
        async let transferGasLimit = try ethereumService.queryGasLimit(
            from: senderAddress,
            amount: EthereumQuantity(quantity: .zero),
            transfer: transferCall
        )
        async let supportsEip1559 = ethereumService.checkChainSupportEip1559()
        let transactionType: EthereumTransaction
            .TransactionType = await supportsEip1559 ? .eip1559 : .legacy

        guard let transferData = transferCall.encodeABI() else {
            throw TransferServiceError
                .transferFailed(reason: "Cannot create ERC20 transfer transaction")
        }

        let tx = try await EthereumTransaction(
            nonce: nonce,
            gasPrice: gasPrice,
            maxFeePerGas: gasPrice,
            maxPriorityFeePerGas: gasPrice,
            gasLimit: transferGasLimit,
            from: senderAddress,
            to: contractAddress,
            value: EthereumQuantity(quantity: BigUInt.zero),
            data: transferData,
            accessList: [:],
            transactionType: transactionType
        )

        let rawTransaction = try tx.sign(with: privateKey, chainId: chainIdValue)
        return rawTransaction
    }
}
