import Foundation
import Web3
import Web3ContractABI

enum EthereumServiceError: Error {
    case invalidTransaction
}

protocol EthereumService {
    func queryGasLimit(call: EthereumCall) async throws -> EthereumQuantity
    func queryGasLimit(from: EthereumAddress?, amount: EthereumQuantity?, transfer: SolidityInvocation) async throws -> EthereumQuantity
    func queryGasPrice() async throws -> EthereumQuantity
    func queryMaxPriorityFeePerGas() async throws -> EthereumQuantity
    func queryNonce(ethereumAddress: EthereumAddress) async throws -> EthereumQuantity
    func checkChainSupportEip1559() async -> Bool
    func queryGasLimit(invocation: SolidityInvocation) async throws -> EthereumQuantity
}

class BaseEthereumService: EthereumService {
    let ws: Web3.Eth

    init(
        ws: Web3.Eth
    ) {
        self.ws = ws
    }

    func queryGasLimit(call: EthereumCall) async throws -> EthereumQuantity {
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

    func queryGasLimit(from: EthereumAddress?, amount: EthereumQuantity?, transfer: SolidityInvocation) async throws -> EthereumQuantity {
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

    func queryGasLimit(invocation: SolidityInvocation) async throws -> EthereumQuantity {
        try await withCheckedThrowingContinuation { continuation in
            invocation.estimateGas { quantity, error in
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

    func queryGasPrice() async throws -> EthereumQuantity {
        try await withCheckedThrowingContinuation { continuation in
            var nillableContinuation: CheckedContinuation<EthereumQuantity, Error>? = continuation

            ws.gasPrice { resp in
                guard let unwrapedContinuation = nillableContinuation else {
                    return
                }

                if let price = resp.result {
                    unwrapedContinuation.resume(with: .success(price))
                    nillableContinuation = nil
                } else if let error = resp.error {
                    unwrapedContinuation.resume(with: .failure(error))
                    nillableContinuation = nil
                } else {
                    unwrapedContinuation.resume(with: .failure(TransferServiceError.unexpected))
                    nillableContinuation = nil
                }
            }
        }
    }

    func queryMaxPriorityFeePerGas() async throws -> EthereumQuantity {
        try await withCheckedThrowingContinuation { continuation in
            var nillableContinuation: CheckedContinuation<EthereumQuantity, Error>? = continuation
            ws.maxPriorityFeePerGas { resp in
                guard let unwrapedContinuation = nillableContinuation else {
                    return
                }
                if let fee = resp.result {
                    unwrapedContinuation.resume(with: .success(fee))
                    nillableContinuation = nil
                } else if let error = resp.error {
                    unwrapedContinuation.resume(with: .failure(error))
                    nillableContinuation = nil
                } else {
                    unwrapedContinuation.resume(with: .failure(TransferServiceError.unexpected))
                    nillableContinuation = nil
                }
            }
        }
    }

    func queryNonce(ethereumAddress: EthereumAddress) async throws -> EthereumQuantity {
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

    func checkChainSupportEip1559() async -> Bool {
        do {
            _ = try await queryMaxPriorityFeePerGas()
            return true
        } catch {
            print("error: ", error)
            return false
        }
    }

    func submit(
        hexData: String,
        privateKey: Data,
        sender: String,
        gasPrice: String,
        gasLimit: String,
        value: String
    ) async throws -> EthereumData {
        guard
            let gasPriceValue = BigUInt(string: gasPrice),
            let gasLimitValue = BigUInt(string: gasLimit),
            let valueValue = BigUInt(string: value)
        else {
            throw EthereumServiceError.invalidTransaction
        }

        let senderAddress = try EthereumAddress(rawAddress: sender.hexToBytes())
        let data = EthereumData(hexData.hexToBytes())
        let nonce = try await queryNonce(ethereumAddress: senderAddress)
        let transaction = EthereumTransaction(
            nonce: nonce,
            gasPrice: EthereumQuantity(quantity: gasPriceValue),
            gasLimit: EthereumQuantity(quantity: gasLimitValue),
            value: EthereumQuantity(quantity: valueValue),
            data: data,
            accessList: [:],
            transactionType: .legacy
        )
        let ethPrivateKey = try EthereumPrivateKey(privateKey.bytes)
        let signedTransaction = try transaction.sign(
            with: ethPrivateKey,
            chainId: EthereumQuantity(integerLiteral: 1)
        )

        return try await withCheckedThrowingContinuation { continuation in
            do {
                try ws.sendRawTransaction(transaction: signedTransaction) { resp in
                    if let hash = resp.result {
                        continuation.resume(with: .success(hash))
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
}
