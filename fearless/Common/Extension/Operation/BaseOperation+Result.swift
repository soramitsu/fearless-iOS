import Foundation
import RobinHood

extension BaseOperation {
    static func createWithError(_ error: Error) -> BaseOperation<ResultType> {
        let operation = BaseOperation<ResultType>()
        operation.result = .failure(error)
        return operation
    }

    static func createWithResult(_ result: ResultType) -> BaseOperation<ResultType> {
        let operation = BaseOperation<ResultType>()
        operation.result = .success(result)
        return operation
    }
}
