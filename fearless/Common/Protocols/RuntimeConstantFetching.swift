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
