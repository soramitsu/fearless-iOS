/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public extension BaseOperation {
    func extractResultData(throwing noResultError: Error) throws -> ResultType {
        if let result = try extractResultData() {
            return result
        } else {
            throw noResultError
        }
    }

    func extractResultData() throws -> ResultType? {
        guard let result = result else {
            return nil
        }

        switch result {
        case let .success(data):
            return data
        case let .failure(error):
            throw error
        }
    }

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

    func extractNoCancellableResultData() throws -> ResultType {
        try extractResultData(throwing: BaseOperationError.parentOperationCancelled)
    }
}
