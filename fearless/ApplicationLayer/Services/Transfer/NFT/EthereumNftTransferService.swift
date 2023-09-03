import Foundation
import Web3
import Web3ContractABI

enum EthereumNftTransferServiceError: Error {
    case incorrectTokenId(tokenId: String)
}

final class EthereumNftTransferService: BaseEthereumService, NftTransferService {
    private let privateKey: EthereumPrivateKey
    private let senderAddress: String
    private var feeSubscriptionId: UInt16?

    init(
        ws: Web3.Eth,
        privateKey: EthereumPrivateKey,
        senderAddress: String
    ) {
        self.privateKey = privateKey
        self.senderAddress = senderAddress

        super.init(ws: ws)
    }

    func estimateFee(for transfer: NftTransfer) async throws -> BigUInt {
        guard let tokenId = BigUInt(string: transfer.nft.tokenId) else {
            throw EthereumNftTransferServiceError.incorrectTokenId(tokenId: transfer.nft.tokenId)
        }
        let ethSenderAddress = try EthereumAddress(rawAddress: senderAddress.hexToBytes())
        let receiverAddress = transfer.receiver.isEmpty ? senderAddress : transfer.receiver
        let address = try EthereumAddress(rawAddress: receiverAddress.hexToBytes())
        let contractAddress = try EthereumAddress(rawAddress: transfer.nft.smartContract.hexToBytes())
        let contract = ws.Contract(type: GenericERC721Contract.self, address: contractAddress)
        let transfer = contract.transferFrom(from: ethSenderAddress, to: address, tokenId: tokenId)
        let gasPrice = try await queryGasPrice()
        let transferGasLimit = try await queryGasLimit(from: ethSenderAddress, amount: EthereumQuantity(quantity: BigUInt.zero), transfer: transfer)

        return gasPrice.quantity * transferGasLimit.quantity
    }

    func estimateFee(for transfer: NftTransfer, baseFeePerGas: EthereumQuantity) async throws -> BigUInt {
        guard let tokenId = BigUInt(string: transfer.nft.tokenId) else {
            throw EthereumNftTransferServiceError.incorrectTokenId(tokenId: transfer.nft.tokenId)
        }

        let ethSenderAddress = try EthereumAddress(rawAddress: senderAddress.hexToBytes())
        let receiverAddress = transfer.receiver.isEmpty ? senderAddress : transfer.receiver
        let address = try EthereumAddress(rawAddress: receiverAddress.hexToBytes())
        let contractAddress = try EthereumAddress(rawAddress: transfer.nft.smartContract.hexToBytes())
        let contract = ws.Contract(type: GenericERC721Contract.self, address: contractAddress)
        let transfer = contract.transferFrom(from: ethSenderAddress, to: address, tokenId: tokenId)
        let maxPriorityFeePerGas = try await queryMaxPriorityFeePerGas()
        let transferGasLimit = try await queryGasLimit(from: ethSenderAddress, amount: EthereumQuantity(quantity: BigUInt.zero), transfer: transfer)

        return (maxPriorityFeePerGas.quantity + baseFeePerGas.quantity) * transferGasLimit.quantity
    }

    func subscribeForFee(transfer: NftTransfer, listener: TransferFeeEstimationListener) {
        do {
            try ws.subscribeToNewHeads(subscribed: {
                _ in

            }, onEvent: { [weak self, weak listener] result in
                if let blockObject = result.result, let listener = listener {
                    self?.handle(newHead: blockObject, listener: listener, transfer: transfer)
                } else if let error = result.error {
                    listener?.didReceiveFeeError(feeError: error)
                } else {
                    listener?.didReceiveFeeError(feeError: TransferServiceError.cannotEstimateFee(reason: "unexpected new block head response"))
                }
            })
        } catch {
            listener.didReceiveFeeError(feeError: error)
        }
    }

    func submit(transfer: NftTransfer) async throws -> String {
        try await transferERC721(transfer: transfer)
    }

    private func transferERC721(transfer: NftTransfer) async throws -> String {
        guard let tokenId = BigUInt(string: transfer.nft.tokenId) else {
            throw EthereumNftTransferServiceError.incorrectTokenId(tokenId: transfer.nft.tokenId)
        }

        let chainIdValue = EthereumQuantity(transfer.nft.chain.chainId.hexToBytes())
        let senderAddress = try EthereumAddress(rawAddress: self.senderAddress.hexToBytes())
        let address = try EthereumAddress(rawAddress: transfer.receiver.hexToBytes())
        let contractAddress = try EthereumAddress(rawAddress: transfer.nft.smartContract.hexToBytes())
        let contract = ws.Contract(type: GenericERC721Contract.self, address: contractAddress)
        let transferCall = contract.transfer(to: address, tokenId: tokenId)
        let nonce = try await queryNonce(ethereumAddress: senderAddress)
        let gasPrice = try await queryGasPrice()
        let transferGasLimit = try await queryGasLimit(from: senderAddress, amount: EthereumQuantity(quantity: .zero), transfer: transferCall)

        guard let transferData = transferCall.encodeABI() else {
            throw TransferServiceError.transferFailed(reason: "Cannot create ERC20 transfer transaction")
        }

        let tx = EthereumTransaction(
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
            transactionType: .eip1559
        )

        let rawTransaction = try tx.sign(with: privateKey, chainId: chainIdValue)

        let result = try await withCheckedThrowingContinuation { continuation in
            do {
                try ws.sendRawTransaction(transaction: rawTransaction) { resp in
                    if let hash = resp.result {
                        continuation.resume(with: .success(hash))
                    } else if let error = resp.error {
                        continuation.resume(with: .failure(error))
                    }
                }
            } catch {
                continuation.resume(with: .failure(error))
            }
        }

        return result.hex()
    }

    private func handle(newHead: EthereumBlockObject, listener: TransferFeeEstimationListener, transfer: NftTransfer) {
        guard let baseFeePerGas = newHead.baseFeePerGas else {
            listener.didReceiveFeeError(feeError: TransferServiceError.cannotEstimateFee(reason: "unexpected new block head response"))
            return
        }

        Task {
            let fee = try await estimateFee(for: transfer, baseFeePerGas: baseFeePerGas)
            listener.didReceiveFee(fee: fee)
        }
    }

    override func queryGasLimit(from: EthereumAddress?, amount: EthereumQuantity?, transfer: SolidityInvocation) async throws -> EthereumQuantity {
        try await withCheckedThrowingContinuation { continuation in
            transfer.estimateGas(from: from, value: amount) { quantity, error in
                if let gas = quantity {
                    return continuation.resume(with: .success(gas))
                } else if let error = error {
                    return continuation.resume(with: .failure(error))
                } else {
                    continuation.resume(with: .failure(TransferServiceError.unexpected))
                }
            }
        }
    }
}