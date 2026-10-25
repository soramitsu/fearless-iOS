import Foundation
import Web3
import Web3ContractABI

// sourcery: AutoMockable
public protocol EthereumService {
    var connection: Web3.Eth { get }
    var hasSubscription: Bool { get }

    func send(
        _ transaction: EthereumSignedTransaction
    ) async throws -> EthereumData
    func queryGasLimit(
        call: EthereumCall
    ) async throws -> EthereumQuantity
    func queryGasLimit(
        from: EthereumAddress?,
        amount: EthereumQuantity?,
        transfer: SolidityInvocation
    ) async throws -> EthereumQuantity
    func queryGasPrice() async throws -> EthereumQuantity
    func queryMaxPriorityFeePerGas() async throws -> EthereumQuantity
    func queryNonce(
        ethereumAddress: EthereumAddress
    ) async throws -> EthereumQuantity
    func checkChainSupportEip1559() async -> Bool
    func unsubscribe(subscriptionId: String) async throws -> Bool
    func getBlockByNumber(
        block: EthereumQuantityTag,
        fullTransactionObjects: Bool
    ) async throws -> EthereumBlockObject?
}

public final class EthereumServiceDefault: EthereumService {
    public let connection: Web3.Eth

    public lazy var hasSubscription: Bool = connection.properties
        .provider as? Web3BidirectionalProvider != nil

    public init(connection: Web3.Eth) {
        self.connection = connection
    }

    public func send(
        _ transaction: EthereumSignedTransaction
    ) async throws -> EthereumData {
        try await withUnsafeThrowingContinuation { continuation in
            do {
                try connection.sendRawTransaction(transaction: transaction) { resp in
                    switch resp.status {
                    case let .success(data):
                        continuation.resume(returning: data)
                    case let .failure(error):
                        continuation.resume(throwing: error)
                    }
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    public func queryGasLimit(
        call: EthereumCall
    ) async throws -> EthereumQuantity {
        try await withUnsafeThrowingContinuation { continuation in
            connection.estimateGas(call: call) { resp in
                switch resp.status {
                case let .success(limit):
                    continuation.resume(returning: limit)
                case let .failure(error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func queryGasLimit(
        from: EthereumAddress?,
        amount: EthereumQuantity?,
        transfer: SolidityInvocation
    ) async throws -> EthereumQuantity {
        try await withUnsafeThrowingContinuation { continuation in
            transfer.estimateGas(from: from, value: amount) { quantity, error in
                if let gas = quantity {
                    continuation.resume(returning: gas)
                } else if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    let error = TransferServiceError.unexpectedWeb3Behaviour
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func queryGasPrice() async throws -> EthereumQuantity {
        try await withUnsafeThrowingContinuation { continuation in
            connection.gasPrice { resp in
                switch resp.status {
                case let .success(price):
                    continuation.resume(returning: price)
                case let .failure(error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func queryMaxPriorityFeePerGas() async throws -> EthereumQuantity {
        try await withUnsafeThrowingContinuation { continuation in
            connection.maxPriorityFeePerGas { resp in
                switch resp.status {
                case let .success(fee):
                    continuation.resume(returning: fee)
                case let .failure(error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func queryNonce(
        ethereumAddress: EthereumAddress
    ) async throws -> EthereumQuantity {
        try await withUnsafeThrowingContinuation { continuation in
            connection.getTransactionCount(address: ethereumAddress, block: .pending) { resp in
                switch resp.status {
                case let .success(nonce):
                    continuation.resume(returning: nonce)
                case let .failure(error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func checkChainSupportEip1559() async -> Bool {
        do {
            _ = try await queryMaxPriorityFeePerGas()
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    public func unsubscribe(subscriptionId: String) async throws -> Bool {
        try await withUnsafeThrowingContinuation { continuation in
            do {
                try connection.unsubscribe(subscriptionId: subscriptionId) { resp in
                    continuation.resume(returning: resp)
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    public func getBlockByNumber(
        block: EthereumQuantityTag,
        fullTransactionObjects: Bool
    ) async throws -> EthereumBlockObject? {
        try await withUnsafeThrowingContinuation { continuation in
            connection.getBlockByNumber(
                block: block,
                fullTransactionObjects: fullTransactionObjects
            ) { resp in
                switch resp.status {
                case let .success(block):
                    continuation.resume(returning: block)
                case let .failure(error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
