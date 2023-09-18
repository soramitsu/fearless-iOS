import Foundation
import OrderedCollections
import Web3
import SSFModels
import SSFExtrinsicKit
import SSFSigner
import Web3ContractABI
import Web3PromiseKit
import SSFUtils

protocol WalletConnectEthereumTransferService {
    func sign(
        transaction: EthereumTransaction,
        chain: ChainModel
    ) throws -> EthereumData

    func send(
        transaction: EthereumTransaction,
        chain: ChainModel
    ) async throws -> EthereumData
}

final class EthereumTransferService: TransferServiceProtocol, WalletConnectEthereumTransferService {
    private let ws: Web3.Eth
    private let privateKey: EthereumPrivateKey
    private let senderAddress: String
    private var feeSubscriptionId: UInt16?

    init(
        ws: Web3.Eth,
        privateKey: EthereumPrivateKey,
        senderAddress: String
    ) {
        self.ws = ws
        self.privateKey = privateKey
        self.senderAddress = senderAddress
    }

    func estimateFee(for transfer: Transfer) async throws -> BigUInt {
        switch transfer.chainAsset.asset.ethereumType {
        case .normal:
            let address = try EthereumAddress(rawAddress: transfer.receiver.hexToBytes())
            let call = EthereumCall(to: address)

            let gasPrice = try await queryGasPrice()
            let gasLimit = try await queryGasLimit(call: call)
            return gasLimit.quantity * gasPrice.quantity
        case .erc20:
            let senderAddress = try EthereumAddress(rawAddress: senderAddress.hexToBytes())
            let contractAddress = try EthereumAddress(rawAddress: transfer.chainAsset.asset.id.hexToBytes())
            let contract = ws.Contract(type: GenericERC20Contract.self, address: contractAddress)
            let transfer = contract.transfer(to: contractAddress, value: transfer.amount)
            let gasPrice = try await queryGasPrice()
            let transferGasLimit = try await queryGasLimit(from: senderAddress, amount: EthereumQuantity(quantity: BigUInt.zero), transfer: transfer)

            return gasPrice.quantity * transferGasLimit.quantity
        case .none:
            throw TransferServiceError.cannotEstimateFee(reason: "unknown asset")
        }
    }

    func estimateFee(for transfer: Transfer, baseFeePerGas: EthereumQuantity) async throws -> BigUInt {
        switch transfer.chainAsset.asset.ethereumType {
        case .normal:
            let address = try EthereumAddress(rawAddress: transfer.receiver.hexToBytes())
            let call = EthereumCall(to: address)

            let maxPriorityFeePerGas = try await queryMaxPriorityFeePerGas()
            let gasLimit = try await queryGasLimit(call: call)
            return gasLimit.quantity * (baseFeePerGas.quantity + maxPriorityFeePerGas.quantity)
        case .erc20:
            let address = try EthereumAddress(rawAddress: transfer.receiver.hexToBytes())
            let senderAddress = try EthereumAddress(rawAddress: senderAddress.hexToBytes())
            let contractAddress = try EthereumAddress(rawAddress: transfer.chainAsset.asset.id.hexToBytes())
            let contract = ws.Contract(type: GenericERC20Contract.self, address: contractAddress)
            let transfer = contract.transfer(to: address, value: transfer.amount)
            let maxPriorityFeePerGas = try await queryMaxPriorityFeePerGas()
            let transferGasLimit = try await queryGasLimit(from: senderAddress, amount: EthereumQuantity(quantity: BigUInt.zero), transfer: transfer)

            return (maxPriorityFeePerGas.quantity + baseFeePerGas.quantity) * transferGasLimit.quantity
        case .none:
            throw TransferServiceError.cannotEstimateFee(reason: "unknown asset")
        }
    }

    func subscribeForFee(transfer: Transfer, listener: TransferFeeEstimationListener) {
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

    private func handle(newHead: EthereumBlockObject, listener: TransferFeeEstimationListener, transfer: Transfer) {
        guard let baseFeePerGas = newHead.baseFeePerGas else {
            listener.didReceiveFeeError(feeError: TransferServiceError.cannotEstimateFee(reason: "unexpected new block head response"))
            return
        }

        Task {
            let fee = try await estimateFee(for: transfer, baseFeePerGas: baseFeePerGas)
            listener.didReceiveFee(fee: fee)
        }
    }

    // MARK: - WalletConnectTransferService

    func sign(
        transaction: EthereumTransaction,
        chain: ChainModel
    ) throws -> EthereumData {
        let chainId = EthereumQuantity(chain.chainId.hexToBytes())
        let signed = try transaction.sign(with: privateKey, chainId: chainId)

        return try signed.rawTransaction()
    }

    func send(
        transaction: EthereumTransaction,
        chain: ChainModel
    ) async throws -> EthereumData {
        guard
            let receiverAddress = transaction.to,
            let senderAddress = transaction.from,
            let quantity = transaction.value
        else {
            throw TransferServiceError.transferFailed(reason: "Wallet connect invalid params")
        }

        let call = EthereumCall(to: receiverAddress, value: quantity)
        let nonce = try await queryNonce(ethereumAddress: senderAddress)
        let gasPrice = try await queryGasPrice()
        let gasLimit = try await queryGasLimit(call: call)
        let tx = EthereumTransaction(
            nonce: nonce,
            gasPrice: gasPrice,
            maxFeePerGas: gasPrice,
            maxPriorityFeePerGas: gasPrice,
            gasLimit: gasLimit,
            from: senderAddress,
            to: receiverAddress,
            value: quantity,
            accessList: [:],
            transactionType: .eip1559
        )
        let chainIdValue = EthereumQuantity(chain.chainId.hexToBytes())
        let rawTransaction = try tx.sign(with: privateKey, chainId: chainIdValue)

        return try await withCheckedThrowingContinuation { continuation in
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
    }

    // MARK: Transfers

    func submit(transfer: Transfer) async throws -> String {
        switch transfer.chainAsset.asset.ethereumType {
        case .normal:
            return try await transferNative(transfer: transfer)
        case .erc20:
            return try await transferERC20(transfer: transfer)
        case .none:
            throw TransferServiceError.transferFailed(reason: "unknown asset")
        }
    }

    private func transferNative(transfer: Transfer) async throws -> String {
        let chainIdValue = EthereumQuantity(transfer.chainAsset.chain.chainId.hexToBytes())
        let receiverAddress = try EthereumAddress(rawAddress: transfer.receiver.hexToBytes())
        let senderAddress = try EthereumAddress(rawAddress: self.senderAddress.hexToBytes())
        let quantity = EthereumQuantity(quantity: transfer.amount)

        let call = EthereumCall(to: receiverAddress, value: quantity)
        let nonce = try await queryNonce(ethereumAddress: senderAddress)
        let gasPrice = try await queryGasPrice()
        let gasLimit = try await queryGasLimit(call: call)
        let tx = EthereumTransaction(
            nonce: nonce,
            gasPrice: gasPrice,
            maxFeePerGas: gasPrice,
            maxPriorityFeePerGas: gasPrice,
            gasLimit: gasLimit,
            from: senderAddress,
            to: receiverAddress,
            value: quantity,
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

    private func transferERC20(transfer: Transfer) async throws -> String {
        let chainIdValue = EthereumQuantity(transfer.chainAsset.chain.chainId.hexToBytes())
        let senderAddress = try EthereumAddress(rawAddress: self.senderAddress.hexToBytes())
        let address = try EthereumAddress(rawAddress: transfer.receiver.hexToBytes())
        let contractAddress = try EthereumAddress(rawAddress: transfer.chainAsset.asset.id.hexToBytes())
        let contract = ws.Contract(type: GenericERC20Contract.self, address: contractAddress)
        let transferCall = contract.transfer(to: address, value: transfer.amount)
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

    // MARK: Fee

    private func queryGasLimit(call: EthereumCall) async throws -> EthereumQuantity {
        try await withCheckedThrowingContinuation { continuation in
            ws.estimateGas(call: call) { resp in
                if let limit = resp.result {
                    continuation.resume(with: .success(limit))
                } else if let error = resp.error {
                    continuation.resume(with: .failure(error))
                } else {
                    continuation.resume(with: .failure(TransferServiceError.unexpected))
                }
            }
        }
    }

    private func queryGasLimit(from: EthereumAddress?, amount: EthereumQuantity?, transfer: SolidityInvocation) async throws -> EthereumQuantity {
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

    private func queryGasPrice() async throws -> EthereumQuantity {
        try await withCheckedThrowingContinuation { continuation in
            ws.gasPrice { resp in
                if let price = resp.result {
                    continuation.resume(with: .success(price))
                } else if let error = resp.error {
                    continuation.resume(with: .failure(error))
                } else {
                    continuation.resume(with: .failure(TransferServiceError.unexpected))
                }
            }
        }
    }

    private func queryMaxPriorityFeePerGas() async throws -> EthereumQuantity {
        try await withCheckedThrowingContinuation { continuation in
            ws.maxPriorityFeePerGas { resp in
                if let fee = resp.result {
                    continuation.resume(with: .success(fee))
                } else if let error = resp.error {
                    continuation.resume(with: .failure(error))
                } else {
                    continuation.resume(with: .failure(TransferServiceError.unexpected))
                }
            }
        }
    }

    // MARK: Additional

    private func queryNonce(ethereumAddress: EthereumAddress) async throws -> EthereumQuantity {
        try await withCheckedThrowingContinuation { continuation in
            ws.getTransactionCount(address: ethereumAddress, block: .pending) { resp in
                if let nonce = resp.result {
                    continuation.resume(with: .success(nonce))
                } else if let error = resp.error {
                    continuation.resume(with: .failure(error))
                }
            }
        }
    }
}
