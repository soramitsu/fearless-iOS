import Foundation
import Web3
import SSFModels
import Web3ContractABI

enum OKXEthereumSwapServiceError: Error {
    case invalidChainId
    case unknownAllowanceResponse
    case unknownApproveResponse
}

protocol OKXEthereumSwapService: EthereumService {
    func swap(
        swap: CrossChainTx,
        chainAsset: ChainAsset
    ) async throws -> String

    func getAllowance(
        dexTokenApproveAddress: String,
        chainAsset: ChainAsset
    ) async throws -> BigUInt

    func approve(
        approveTransaction: OKXApproveTransaction,
        chain: ChainModel,
        chainAsset: ChainAsset
    ) async throws -> String

    func estimateFee(
        swap: CrossChainTx
    ) async throws -> BigUInt
    
    func estimateFee(
        quote: CrossChainSwap
    ) async throws -> BigUInt
    
    func estimateFee(
        approveTransaction: OKXApproveTransaction,
        chain: ChainModel,
        chainAsset: ChainAsset
    ) async throws -> BigUInt
    
    func estimateFeeForApproveTx(
        dexTokenApproveAddress: String,
        chainAsset: ChainAsset
    ) async throws -> BigUInt
    
    func revoke(
        chainAsset: ChainAsset,
        dexTokenApproveAddress: String
    ) async throws -> String
}

final class OKXEthereumSwapServiceImpl: BaseEthereumService, OKXEthereumSwapService {
    private let privateKey: EthereumPrivateKey
    private let senderAddress: String
    private var feeSubscriptionId: String?
    private var baseFeePerGas: BigUInt?
    private var useFixedFee: Bool = true

    init(privateKey: EthereumPrivateKey, senderAddress: String, eth: Web3.Eth) {
        self.privateKey = privateKey
        self.senderAddress = senderAddress

        super.init(ws: eth)
    }
    
    func revoke(chainAsset: ChainAsset, dexTokenApproveAddress: String) async throws -> String {
        guard
            let contractAddress = EthereumAddress(hexString: chainAsset.asset.id),
            let chainId = BigUInt(string: chainAsset.chain.chainId)
        else {
            throw EthereumServiceError.invalidTransaction
        }
        let spenderAddress = try EthereumAddress(rawAddress: dexTokenApproveAddress.hexToBytes())
        let senderAddress = try EthereumAddress(rawAddress: senderAddress.hexToBytes())
        let chainIdValue = EthereumQuantity(quantity: chainId)
        let contract = ws.Contract(type: GenericERC20Contract.self, address: contractAddress)
        let call = contract.approve(spender: spenderAddress, value: .zero)
        let nonce = try await queryNonce(ethereumAddress: senderAddress)
        let gasPrice = try await queryGasPrice()
        let transferGasLimit = try await queryGasLimit(from: senderAddress, amount: EthereumQuantity(quantity: .zero), transfer: call)
        let supportsEip1559 = await checkChainSupportEip1559()
        let transactionType: EthereumTransaction.TransactionType = supportsEip1559 ? .eip1559 : .legacy

        guard let transferData = call.encodeABI() else {
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

    func approve(approveTransaction: OKXApproveTransaction, chain: ChainModel, chainAsset: ChainAsset) async throws -> String {
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

        let contractAddress = EthereumAddress(hexString: chainAsset.asset.id)
        let data = try EthereumData.string(approveTransaction.data)
        let chainId = EthereumQuantity(integerLiteral: intChainId)
        let ethSenderAddress = try EthereumAddress(hex: senderAddress, eip55: false)
        let nonce = try await queryNonce(ethereumAddress: ethSenderAddress)

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
        swap: CrossChainTx,
        chainAsset: ChainAsset
    ) async throws -> String {
        guard
            let swapGasLimit = swap.gasLimit,
            let swapGasPrice = swap.gasPrice,
            let maxPriorityFeePerGas = swap.maxPriorityFeePerGas,
            let senderAddress = try EthereumAddress(rawAddress: swap.sender?.hexToBytes()),
            let swapFromAmount = swap.amount
        else {
            throw EthereumServiceError.invalidTransaction
        }

        guard
            let intChainId = UInt64(chainAsset.chain.chainId)
        else {
            throw OKXEthereumSwapServiceError.invalidChainId
        }

        let chainId = EthereumQuantity(integerLiteral: intChainId)
        let value = BigUInt(string: swapFromAmount)

        let data = try EthereumData(ethereumValue: EthereumValue(stringLiteral: swap.transactionHex))

        let nonce = try await queryNonce(ethereumAddress: senderAddress)

        let gasLimitValue = BigUInt(string: "1700000")
        let gasPriceValue = BigUInt(string: swapGasPrice)
        let maxPriorityFeePerGasValue = BigUInt(string: maxPriorityFeePerGas)

        let ethereumGasLimit = EthereumQuantity(quantity: gasLimitValue)
        let ethereumGasPrice = EthereumQuantity(quantity: gasPriceValue)
        let ethereumMaxPriorityFeePerGas = EthereumQuantity(quantity: maxPriorityFeePerGasValue)
        let fee = gasLimitValue.or(.zero) * gasPriceValue.or(.zero)
        let ethereumValue = chainAsset.isUtility ? EthereumQuantity(quantity: value.or(.zero) + fee) : EthereumQuantity(quantity: fee)
        let contractAddress = EthereumAddress(hexString: swap.address)

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
    
    func estimateFee(quote: any CrossChainSwap) async throws -> BigUInt {
        let swapGasPrice = try await queryGasPrice()
        let swapGasLimit =  useFixedFee ? BigUInt(string: "1700000") : quote.gasLimit.flatMap { BigUInt(string: $0) }
        return swapGasPrice.quantity * swapGasLimit.or(.zero)
    }

    func estimateFee(swap: CrossChainTx) async throws -> BigUInt {
        let swapGasPrice = try await queryGasPrice()
        let swapGasLimit =  useFixedFee ? BigUInt(string: "1700000") : swap.gasLimit.flatMap { BigUInt(string: $0) }
        return swapGasPrice.quantity * swapGasLimit.or(.zero)
    }
    
    func estimateFee(approveTransaction: OKXApproveTransaction, chain: ChainModel, chainAsset: ChainAsset) async throws -> BigUInt {
        guard
            let contractAddress = EthereumAddress(hexString: chainAsset.asset.id)
        else {
            throw EthereumServiceError.invalidTransaction
        }

        let data = try EthereumData.string(approveTransaction.data)
        let senderAddress = try EthereumAddress(rawAddress: senderAddress.hexToBytes())
        let gasPrice = try await queryGasPrice()

        let call = EthereumCall(from: senderAddress, to: contractAddress, data: data)
        let gasLimit = try await queryGasLimit(call: call)
        return gasPrice.quantity * gasLimit.quantity
    }
    
    func estimateFeeForApproveTx(dexTokenApproveAddress: String, chainAsset: ChainAsset) async throws -> BigUInt {
        guard
            let contractAddress = EthereumAddress(hexString: chainAsset.asset.id)
        else {
            throw EthereumServiceError.invalidTransaction
        }
        let spenderAddress = try EthereumAddress(rawAddress: dexTokenApproveAddress.hexToBytes())
        let senderAddress = try EthereumAddress(rawAddress: senderAddress.hexToBytes())

        let contract = ws.Contract(type: GenericERC20Contract.self, address: contractAddress)
        let call = contract.approve(spender: spenderAddress, value: .zero)
        let gasPrice = try await queryGasPrice()

        return try await withCheckedThrowingContinuation { continuation in
            call.estimateGas(from: senderAddress, gas: nil, value: EthereumQuantity(integerLiteral: 0)) { gasLimit, error in
                if let gasLimit = gasLimit{
                    continuation.resume(with: .success(gasLimit.quantity * gasPrice.quantity))
                } else {
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(throwing: OKXEthereumSwapServiceError.unknownAllowanceResponse)
                    }
                }
            }
        }
    }

    func getAllowance(dexTokenApproveAddress: String, chainAsset: ChainAsset) async throws -> BigUInt {
        let senderAddress = try EthereumAddress(rawAddress: senderAddress.hexToBytes())
        let spenderAddress = try EthereumAddress(rawAddress: dexTokenApproveAddress.hexToBytes())
        let contractAddress = try EthereumAddress(rawAddress: chainAsset.asset.id.hexToBytes())
        let contract = ws.Contract(type: GenericERC20Contract.self, address: contractAddress)
        let transferCall = contract.allowance(owner: senderAddress, spender: spenderAddress)

        return try await withCheckedThrowingContinuation { continuation in
            transferCall.call { result, error in
                if let result = result{
                    if let remaining = result["_remaining"] as? BigUInt {
                        continuation.resume(with: .success(remaining))
                    } else {
                        continuation.resume(with: .success(.zero))
                    }
                } else {
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(throwing: OKXEthereumSwapServiceError.unknownAllowanceResponse)
                    }
                }
            }
        }
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
