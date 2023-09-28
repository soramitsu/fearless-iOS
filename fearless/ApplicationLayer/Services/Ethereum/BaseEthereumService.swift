import Foundation
import Web3
import Web3ContractABI

enum BaseEthereumServiceError: Error {
    case continuationError
}

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
