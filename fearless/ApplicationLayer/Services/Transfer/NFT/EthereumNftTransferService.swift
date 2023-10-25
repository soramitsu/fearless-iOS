import Foundation
import Web3
import Web3ContractABI

enum EthereumNftTransferServiceError: Error {
    case incorrectTokenId(tokenId: String)
    case missedSmartContract
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
        let gasPrice = try await queryGasPrice()
        let transferGasLimitQuantity = try await transferGasLimitQuantity(for: transfer)
        return gasPrice.quantity * transferGasLimitQuantity
    }

    func estimateFee(for transfer: NftTransfer, baseFeePerGas: EthereumQuantity) async throws -> BigUInt {
        let maxPriorityFeePerGas = try await queryMaxPriorityFeePerGas()
        let transferGasLimitQuantity = try await transferGasLimitQuantity(for: transfer)
        return (maxPriorityFeePerGas.quantity + baseFeePerGas.quantity) * transferGasLimitQuantity
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

    private func transferGasLimitQuantity(for transfer: NftTransfer) async throws -> BigUInt {
        guard let smartContract = transfer.nft.smartContract else {
            throw EthereumNftTransferServiceError.missedSmartContract
        }

        let tokenId = BigUInt(try Data(hexStringSSF: transfer.nft.tokenId))
        let ethSenderAddress = try EthereumAddress(rawAddress: senderAddress.hexToBytes())
        let receiverAddress = transfer.receiver.isEmpty ? senderAddress : transfer.receiver
        let address = try EthereumAddress(rawAddress: receiverAddress.hexToBytes())
        let contractAddress = try EthereumAddress(rawAddress: smartContract.hexToBytes())

        var transferSolidityInvocation: SolidityInvocation
        switch transfer.nft.tokenType ?? .erc721 {
        case .erc721:
            let contract = ws.Contract(type: GenericERC721Contract.self, address: contractAddress)
            transferSolidityInvocation = contract.transferFrom(from: ethSenderAddress, to: address, tokenId: tokenId)
        case .erc1155:
            let contract = ws.Contract(type: GenericERC1155Contract.self, address: contractAddress)
            transferSolidityInvocation = contract.safeTransferFrom(from: ethSenderAddress, to: address, tokenId: tokenId, value: 1, data: [])
        }

        let transferGasLimit = try await queryGasLimit(
            from: ethSenderAddress,
            amount: EthereumQuantity(quantity: BigUInt.zero),
            transfer: transferSolidityInvocation
        )
        return transferGasLimit.quantity
    }

    private func transferERC721(transfer: NftTransfer) async throws -> String {
        guard let smartContract = transfer.nft.smartContract else {
            throw EthereumNftTransferServiceError.missedSmartContract
        }

        let tokenId = BigUInt(try Data(hexStringSSF: transfer.nft.tokenId))
        guard let chainId = BigUInt(string: transfer.nft.chain.chainId) else {
            throw EthereumSignedTransaction.Error.chainIdNotSet(msg: "EIP1559 transactions need a chainId")
        }
        let chainIdValue = EthereumQuantity(quantity: chainId)
        let senderAddress = try EthereumAddress(rawAddress: self.senderAddress.hexToBytes())
        let address = try EthereumAddress(rawAddress: transfer.receiver.hexToBytes())
        let contractAddress = try EthereumAddress(rawAddress: smartContract.hexToBytes())

        var transferCall: SolidityInvocation
        switch transfer.nft.tokenType ?? .erc721 {
        case .erc721:
            let contract = ws.Contract(type: GenericERC721Contract.self, address: contractAddress)
            transferCall = contract.transferFrom(from: senderAddress, to: address, tokenId: tokenId)
        case .erc1155:
            let contract = ws.Contract(type: GenericERC1155Contract.self, address: contractAddress)
            transferCall = contract.safeTransferFrom(from: senderAddress, to: address, tokenId: tokenId, value: 1, data: [])
        }
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

    override func queryGasLimit(from: EthereumAddress?, amount _: EthereumQuantity?, transfer: SolidityInvocation) async throws -> EthereumQuantity {
        try await withCheckedThrowingContinuation { continuation in
            transfer.estimateGas(from: from) { quantity, error in
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
