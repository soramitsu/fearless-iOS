import Foundation
import RobinHood

protocol RuntimeConstantFetching {
    func fetchConstant<T: LosslessStringConvertible & Equatable>(
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
    func fetchConstant<T: LosslessStringConvertible & Equatable>(
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
