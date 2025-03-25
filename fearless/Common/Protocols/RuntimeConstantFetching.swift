import Foundation
import RobinHood
import SSFUtils
import SSFRuntimeCodingService

protocol RuntimeConstantFetching {
    func fetchConstant<T: LosslessStringConvertible & Equatable & Hashable>(
        for path: ConstantCodingPath,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        closure: @escaping (Result<T, Error>) -> Void
    )

    func fetchConstant<T: LosslessStringConvertible & Equatable & Hashable>(
        for path: ConstantCodingPath,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol
    ) async throws -> T

    func fetchCompoundConstant<T: Decodable>(
        for path: ConstantCodingPath,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        closure: @escaping (Result<T, Error>) -> Void
    )
}

extension RuntimeConstantFetching {
    func fetchConstant<T: LosslessStringConvertible & Equatable & Hashable>(
        for path: ConstantCodingPath,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        closure: @escaping (Result<T, Error>) -> Void
    ) {
        let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()
        let constOperation = PrimitiveConstantOperation<T>(path: path)
        constOperation.configurationBlock = {
            do {
                constOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                constOperation.result = .failure(error)
            }
        }

        constOperation.addDependency(codingFactoryOperation)

        constOperation.completionBlock = {
            DispatchQueue.main.async {
                if let result = constOperation.result {
                    if case let .failure(errorKind) = result,
                       case StorageDecodingOperationError.invalidStoragePath = errorKind,
                       let snapshot = runtimeCodingService.snapshot,
                       let override = snapshot.typeRegistryCatalog.override(
                           for: path.moduleName,
                           constantName: path.constantName,
                           version: UInt64(snapshot.specVersion)
                       ),
                       let overriden = T(override) {
                        closure(.success(overriden))
                        return
                    }

                    closure(result)
                } else {
                    closure(.failure(BaseOperationError.parentOperationCancelled))
                }
            }
        }

        operationManager.enqueue(operations: [constOperation, codingFactoryOperation], in: .transient)
    }

    func fetchConstant<T: LosslessStringConvertible & Equatable & Hashable>(
        for path: ConstantCodingPath,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol
    ) async throws -> T {
        try await withUnsafeThrowingContinuation { continuation in
            fetchConstant(
                for: path,
                runtimeCodingService: runtimeCodingService,
                operationManager: operationManager
            ) { (result: Swift.Result<T, Error>) in
                switch result {
                case let .success(constant):
                    continuation.resume(returning: constant)
                case let .failure(error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchCompoundConstant<T: Decodable>(
        for path: ConstantCodingPath,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        closure: @escaping (Result<T, Error>) -> Void
    ) {
        let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()
        let constOperation = StorageConstantOperation<T>(path: path)
        constOperation.configurationBlock = {
            do {
                constOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                constOperation.result = .failure(error)
            }
        }

        constOperation.addDependency(codingFactoryOperation)

        constOperation.completionBlock = {
            DispatchQueue.main.async {
                if let result = constOperation.result {
                    closure(result)
                } else {
                    closure(.failure(BaseOperationError.parentOperationCancelled))
                }
            }
        }

        operationManager.enqueue(operations: [constOperation, codingFactoryOperation], in: .transient)
    }
}
