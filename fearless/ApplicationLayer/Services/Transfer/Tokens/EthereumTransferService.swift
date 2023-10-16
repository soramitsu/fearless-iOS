import Foundation
import OrderedCollections
import Web3
import SSFModels
import Web3ContractABI
import Web3PromiseKit
import SSFUtils

final class EthereumTransferService: BaseEthereumService, TransferServiceProtocol {
    private let privateKey: EthereumPrivateKey
    private let senderAddress: String
    private var feeSubscriptionId: String?

    init(
        ws: Web3.Eth,
        privateKey: EthereumPrivateKey,
        senderAddress: String
    ) {
        self.privateKey = privateKey
        self.senderAddress = senderAddress

        super.init(ws: ws)
    }

    deinit {
        unsubscribe()
    }

    func estimateFee(for transfer: Transfer) async throws -> BigUInt {
        switch transfer.chainAsset.asset.ethereumType {
        case .normal:
            let address = try EthereumAddress(rawAddress: transfer.receiver.hexToBytes())
            let call = EthereumCall(to: address)

            let gasPrice = try await queryGasPrice()
            let gasLimit = try await queryGasLimit(call: call)
            return gasLimit.quantity * gasPrice.quantity
        case .erc20, .bep20:
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
        case .erc20, .bep20:
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
        func subscribe() throws {
            try ws.subscribeToNewHeads(subscribed: { [weak self] subscriptionId in
                self?.feeSubscriptionId = subscriptionId.result
            }, onEvent: { [weak self, weak listener] result in
                if let blockObject = result.result, let listener = listener {
                    self?.handle(newHead: blockObject, listener: listener, transfer: transfer)
                } else if let error = result.error {
                    listener?.didReceiveFeeError(feeError: error)
                } else {
                    listener?.didReceiveFeeError(feeError: TransferServiceError.cannotEstimateFee(reason: "unexpected new block head response"))
                }
            })
        }
        do {
            if let currentSubscription = feeSubscriptionId {
                try ws.unsubscribe(subscriptionId: currentSubscription, completion: { success in
                    guard success else { return }
                    do {
                        try subscribe()
                    } catch {
                        listener.didReceiveFeeError(feeError: error)
                    }
                })
            } else {
                try subscribe()
            }
        } catch {
            listener.didReceiveFeeError(feeError: error)
        }
    }

    nonisolated func unsubscribe() {
        guard let subscriptionId = feeSubscriptionId else {
            return
        }
        try? ws.unsubscribe(subscriptionId: subscriptionId, completion: { _ in })
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

    // MARK: Transfers

    func submit(transfer: Transfer) async throws -> String {
        switch transfer.chainAsset.asset.ethereumType {
        case .normal:
            return try await transferNative(transfer: transfer)
        case .erc20, .bep20:
            return try await transferERC20(transfer: transfer)
        case .none:
            throw TransferServiceError.transferFailed(reason: "unknown asset")
        }
    }

    private func transferNative(transfer: Transfer) async throws -> String {
        guard let chainId = BigUInt(string: transfer.chainAsset.chain.chainId) else {
            throw EthereumSignedTransaction.Error.chainIdNotSet(msg: "EIP1559 transactions need a chainId")
        }
        let chainIdValue = EthereumQuantity(quantity: chainId)
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
        guard let chainId = BigUInt(string: transfer.chainAsset.chain.chainId) else {
            throw EthereumSignedTransaction.Error.chainIdNotSet(msg: "EIP1559 transactions need a chainId")
        }
        let chainIdValue = EthereumQuantity(quantity: chainId)
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
}
