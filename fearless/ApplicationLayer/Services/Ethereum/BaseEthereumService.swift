import Foundation
import Web3
import Web3ContractABI

class BaseEthereumService {
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

    func queryGasPrice() async throws -> EthereumQuantity {
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

    func queryMaxPriorityFeePerGas() async throws -> EthereumQuantity {
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
}
