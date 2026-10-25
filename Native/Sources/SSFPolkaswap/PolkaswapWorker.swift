import BigInt
import Foundation
import RobinHood
import SSFPools
import SSFUtils

enum PolkaswapWorkerError: Error {
    case getPoolReservesIdFailed
    case getPoolReservesFailed
}

protocol PolkaswapWorker: Actor {
    func getBaseAssetIds() async throws -> [String]
    func getAccountPools(accountId: Data, baseAssetId: String) async throws -> [AccountPool]
    func getPoolReservesId(baseAssetId: String) async throws -> [LiquidityPair]
    func getPoolReservesId(baseAssetId: String, targetAssetId: String) async throws
        -> PolkaswapAccountId
    func getPoolProviderBalance(reservesId: Data?, accountId: Data) async throws -> BigUInt
    func getPoolTotalIssuances(reservesId: Data?) async throws -> BigUInt
    func getPoolReserves(baseAssetId: String, targetAssetId: String) async throws
        -> PolkaswapPoolReserves
    func getPoolsReserves(baseAssetId: String) async throws -> [LiquidityPair]
}

actor PolkaswapWorkerDefault: PolkaswapWorker {
    private let operationFactory: PolkaswapOperationFactory
    private let operationManager: OperationManagerProtocol

    init(
        operationFactory: PolkaswapOperationFactory,
        operationManager: OperationManagerProtocol = OperationManager()
    ) {
        self.operationFactory = operationFactory
        self.operationManager = operationManager
    }

    func getBaseAssetIds() async throws -> [String] {
        let operation = try operationFactory.dexInfos()
        operationManager.enqueue(operations: operation.allOperations, in: .transient)

        return try await withCheckedThrowingContinuation { continuation in
            operation.targetOperation.completionBlock = {
                do {
                    let result = try operation.targetOperation.extractNoCancellableResultData()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func getAccountPools(accountId: Data, baseAssetId: String) async throws -> [AccountPool] {
        let operation = try operationFactory.accountPools(
            accountId: accountId,
            baseAssetId: baseAssetId
        )
        operationManager.enqueue(operations: operation.allOperations, in: .transient)

        return try await withCheckedThrowingContinuation { continuation in
            operation.targetOperation.completionBlock = {
                do {
                    let userPools = try operation.targetOperation.extractNoCancellableResultData()
                    continuation.resume(returning: userPools)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func getPoolReservesId(baseAssetId: String) async throws -> [LiquidityPair] {
        let operation = try operationFactory.poolProperties(baseAssetId: baseAssetId)
        operationManager.enqueue(operations: operation.allOperations, in: .transient)

        return try await withCheckedThrowingContinuation { continuation in
            operation.targetOperation.completionBlock = {
                do {
                    let result = try operation.targetOperation.extractNoCancellableResultData()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func getPoolReservesId(
        baseAssetId: String,
        targetAssetId: String
    ) async throws -> PolkaswapAccountId {
        let operation = operationFactory.poolProperties(
            baseAssetId: baseAssetId,
            targetAssetId: targetAssetId
        )
        operationManager.enqueue(operations: operation.allOperations, in: .transient)

        return try await withCheckedThrowingContinuation { continuation in
            operation.targetOperation.completionBlock = {
                do {
                    guard let result = try operation.targetOperation
                        .extractNoCancellableResultData() else
                    {
                        throw PolkaswapWorkerError.getPoolReservesIdFailed
                    }
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func getPoolProviderBalance(reservesId: Data?, accountId: Data) async throws -> BigUInt {
        let operation = try operationFactory.poolProvidersBalance(
            reservesId: reservesId,
            accountId: accountId
        )
        operationManager.enqueue(operations: operation.allOperations, in: .transient)

        return try await withCheckedThrowingContinuation { continuation in
            operation.targetOperation.completionBlock = {
                do {
                    let result = try operation.targetOperation.extractNoCancellableResultData()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func getPoolTotalIssuances(reservesId: Data?) async throws -> BigUInt {
        let operation = try operationFactory.poolTotalIssuances(reservesId: reservesId)
        operationManager.enqueue(operations: operation.allOperations, in: .transient)

        return try await withCheckedThrowingContinuation { continuation in
            operation.targetOperation.completionBlock = {
                do {
                    let result = try operation.targetOperation.extractNoCancellableResultData()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func getPoolReserves(
        baseAssetId: String,
        targetAssetId: String
    ) async throws -> PolkaswapPoolReserves {
        let operation = try operationFactory.poolReserves(
            baseAssetId: baseAssetId,
            targetAssetId: targetAssetId
        )
        operationManager.enqueue(operations: operation.allOperations, in: .transient)

        return try await withCheckedThrowingContinuation { continuation in
            operation.targetOperation.completionBlock = {
                do {
                    guard let result = try operation.targetOperation
                        .extractNoCancellableResultData() else
                    {
                        throw PolkaswapWorkerError.getPoolReservesFailed
                    }
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func getPoolsReserves(baseAssetId: String) async throws -> [LiquidityPair] {
        let operation = try operationFactory.reservesKeysOperation(baseAssetId: baseAssetId)
        operationManager.enqueue(operations: operation.allOperations, in: .transient)

        return try await withCheckedThrowingContinuation { continuation in
            operation.targetOperation.completionBlock = {
                do {
                    let poolReserves = try operation.targetOperation
                        .extractNoCancellableResultData()
                    continuation.resume(returning: poolReserves)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
