import Foundation
import Web3
import SSFModels
import Web3ContractABI

enum OKXEthereumSwapServiceError: Error {
    case invalidChainId
}

protocol OKXEthereumSwapService {
    func swap(
        swap: CrossChainSwap,
        chain: ChainModel
    ) async throws -> String

    func getAllowance(
        swap: CrossChainSwap,
        dexTokenApproveAddress: String,
        chain: ChainModel
    ) async throws -> String

    func approve(
        approveTransaction: OKXApproveTransaction,
        swap: CrossChainSwap,
        chain: ChainModel,
        dexTokenApproveAddress: String,
        chainAsset: ChainAsset
    ) async throws -> String

    func estimateFee(
        swap: CrossChainSwap,
        chain: ChainModel
    ) async throws -> BigUInt
}

final class OKXEthereumSwapServiceImpl: BaseEthereumService, OKXEthereumSwapService {
    private let privateKey: EthereumPrivateKey
    private let senderAddress: String
    private var feeSubscriptionId: String?
    private var baseFeePerGas: BigUInt?

    init(privateKey: EthereumPrivateKey, senderAddress: String, eth: Web3.Eth) {
        self.privateKey = privateKey
        self.senderAddress = senderAddress

        super.init(ws: eth)
    }

    func approve(approveTransaction: OKXApproveTransaction, swap _: CrossChainSwap, chain: ChainModel, dexTokenApproveAddress _: String, chainAsset: ChainAsset) async throws -> String {
        guard
            let gasPrice = EthereumQuantity(quantity: BigUInt(string: approveTransaction.gasPrice)),
            let gasLimit = EthereumQuantity(quantity: BigUInt(string: "350000"))

        else {
            throw EthereumServiceError.invalidTransaction
        }

        guard
            let intChainId = UInt64(chain.chainId)
        else {
            throw OKXEthereumSwapServiceError.invalidChainId
        }
        let contractAddress = try EthereumAddress(rawAddress: chainAsset.asset.id.hexToBytes())
        let data = try EthereumData.string(approveTransaction.data)
        let chainId = EthereumQuantity(integerLiteral: intChainId)
        let senderAddress = try EthereumAddress(rawAddress: senderAddress.hexToBytes())
        let nonce = try await queryNonce(ethereumAddress: senderAddress)

        let tx = EthereumTransaction(
            nonce: nonce,
            gasPrice: gasPrice,
            gasLimit: gasLimit,
            to: contractAddress,
            value: EthereumQuantity(quantity: .zero),
            data: data
        )

        let signedTransaction = try tx.sign(
            with: privateKey,
            chainId: chainId
        )

        return try await withCheckedThrowingContinuation { continuation in
            do {
                try ws.sendRawTransaction(transaction: signedTransaction) { resp in
                    if let hash = resp.result {
                        continuation.resume(with: .success(hash.hex()))
                        print("Approve transaction hash: ", hash.hex())
                    } else if let error = resp.error {
                        print("Transaction error: ", error)
                        continuation.resume(with: .failure(error))
                    }
                }
            } catch {
                continuation.resume(with: .failure(error))
            }
        }
    }

    func swap(
        swap: CrossChainSwap,
        chain: ChainModel
    ) async throws -> String {
        guard
            let swapGasLimit = swap.gasLimit,
            let txData = swap.txData,
            let swapGasPrice = swap.gasPrice,
            let maxPriorityFeePerGas = swap.maxPriorityFeePerGas,
            let senderAddress = try EthereumAddress(rawAddress: swap.from?.hexToBytes())
        else {
            throw EthereumServiceError.invalidTransaction
        }

        guard
            let intChainId = UInt64(chain.chainId)
        else {
            throw OKXEthereumSwapServiceError.invalidChainId
        }

        let chainId = EthereumQuantity(integerLiteral: intChainId)

        let data = EthereumData(txData.hexToBytes())

        let nonce = try await queryNonce(ethereumAddress: senderAddress)

        let gasLimitValue = BigUInt(string: "1000000")
        let gasPriceValue = BigUInt(string: swapGasPrice)
        let maxPriorityFeePerGasValue = BigUInt(string: maxPriorityFeePerGas)

        let ethereumGasLimit = EthereumQuantity(quantity: gasLimitValue)
        let ethereumGasPrice = EthereumQuantity(quantity: gasPriceValue)
        let ethereumMaxPriorityFeePerGas = EthereumQuantity(quantity: maxPriorityFeePerGasValue)

        let ethereumValue = EthereumQuantity(quantity: .zero)
        let contractAddress = try EthereumAddress(rawAddress: swap.contractAddress?.hexToBytes())

        let supportsEip1559 = await checkChainSupportEip1559()
        let transactionType: EthereumTransaction.TransactionType = supportsEip1559 ? .eip1559 : .legacy

        let tx = EthereumTransaction(
            nonce: nonce,
            gasPrice: ethereumGasPrice,
            maxFeePerGas: ethereumGasPrice,
            maxPriorityFeePerGas: ethereumMaxPriorityFeePerGas,
            gasLimit: ethereumGasLimit,
            from: senderAddress,
            to: contractAddress,
            value: ethereumValue,
            data: data,
            accessList: [:],
            transactionType: transactionType
        )

        let signedTransaction = try tx.sign(
            with: privateKey,
            chainId: chainId
        )

        return try await withCheckedThrowingContinuation { continuation in
            do {
                try ws.sendRawTransaction(transaction: signedTransaction) { resp in
                    if let hash = resp.result {
                        continuation.resume(with: .success(hash.hex()))
                    } else if let error = resp.error {
                        print("Transaction error: ", error)
                        continuation.resume(with: .failure(error))
                    }
                }
            } catch {
                continuation.resume(with: .failure(error))
            }
        }
    }

    func estimateFee(swap: CrossChainSwap, chain _: ChainModel) async throws -> BigUInt {
        guard
            let swapFromAmount = swap.fromAmount,
            let txData = swap.txData,
            let contractAddress = try EthereumAddress(rawAddress: swap.contractAddress?.hexToBytes())
        else {
            throw EthereumServiceError.invalidTransaction
        }

        let data = EthereumData(txData.hexToBytes())
        let value = BigUInt(string: swapFromAmount)
        let senderAddress = try EthereumAddress(rawAddress: senderAddress.hexToBytes())
        let gasPrice = try await queryGasPrice()
        let ethereumValue = EthereumQuantity(quantity: value)

        let call = EthereumCall(from: senderAddress, to: contractAddress, value: ethereumValue, data: data)
        let gasLimit = try await queryGasLimit(call: call)
        return gasPrice.quantity * gasLimit.quantity
    }

    func getAllowance(swap: CrossChainSwap, dexTokenApproveAddress: String, chain: ChainModel) async throws -> String {
        guard let chainId = BigUInt(string: chain.chainId) else {
            throw EthereumSignedTransaction.Error.chainIdNotSet(msg: "EIP1559 transactions need a chainId")
        }
        let chainIdValue = EthereumQuantity(quantity: chainId)

        let senderAddress = try EthereumAddress(rawAddress: senderAddress.hexToBytes())
        let spenderAddress = try EthereumAddress(rawAddress: dexTokenApproveAddress.hexToBytes())
        let contractAddress = try EthereumAddress(rawAddress: swap.contractAddress?.bytes)
        let contract = ws.Contract(type: GenericERC20Contract.self, address: contractAddress)
        let transferCall = contract.allowance(owner: senderAddress, spender: spenderAddress)

        let nonce = try await queryNonce(ethereumAddress: senderAddress)
        let gasPrice = try await queryGasPrice()
        let transferGasLimit = try await queryGasLimit(from: senderAddress, amount: EthereumQuantity(quantity: .zero), transfer: transferCall)
        let supportsEip1559 = await checkChainSupportEip1559()
        let transactionType: EthereumTransaction.TransactionType = supportsEip1559 ? .eip1559 : .legacy

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
            transactionType: transactionType
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

    // MARK: - Private

    func subscribeForFee(listener: EthBlockChangesListener) {
        func subscribe() throws {
            try ws.subscribeToNewHeads(subscribed: { [weak self] subscriptionId in
                self?.feeSubscriptionId = subscriptionId.result
            }, onEvent: { [weak listener] result in
                if let blockObject = result.result, let listener = listener {
                    guard let baseFeePerGas = blockObject.baseFeePerGas else {
                        return
                    }

                    listener.didReceive(baseFeePerGas: baseFeePerGas.quantity)
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
                        listener.didFailToSubscribe(error: error)
                    }
                })
            } else {
                try subscribe()
            }
        } catch {
            listener.didFailToSubscribe(error: error)
        }
    }

    nonisolated func unsubscribe() {
        guard let subscriptionId = feeSubscriptionId else {
            return
        }
        try? ws.unsubscribe(subscriptionId: subscriptionId, completion: { _ in })
    }
}
