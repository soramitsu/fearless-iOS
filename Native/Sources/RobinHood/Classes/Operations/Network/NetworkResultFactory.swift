/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/**
 *  Protocol is designed to create result value from remote response.
 */

public protocol NetworkResultFactoryProtocol: AnyObject {
    associatedtype ResultType

    /**
     *  Creates result from network response.
     *
     *  - parameters:
     *    - data: Response data.
     *    - response: Response description.
     *    - error: Error if request is failed.
     *  - result: Swift Result containing concrete value or an error in case of failure.
     */
    func createResult(data: Data?, response: URLResponse?, error: Error?)
        -> Result<ResultType, Error>
}

/// Closure to convert network response to concrete value.
public typealias NetworkResultFactoryBlock<ResultType> = (Data?, URLResponse?, Error?) -> Result<
    ResultType,
    Error
>

/// Closure to produce result in case of successfull response.
public typealias NetworkResultFactorySuccessResponseBlock<ResultType> = () -> ResultType

/// Closure to convert network response data to concrete value to form result in case of successfull
/// response.
public typealias NetworkResultFactoryProcessingBlock<ResultType> = (Data) throws -> ResultType

/**
 *  Type erasure implementation of `NetworkResultFactoryProtocol` protocol.
 *
 *  It allows closure based parsing instead of manual protocol implementation for each endpoint.
 */

public final class AnyNetworkResultFactory<T>: NetworkResultFactoryProtocol {
    public typealias ResultType = T

    private var _createResult: NetworkResultFactoryBlock<ResultType>

    /**
     *  Creates type erasure wrapper for implementation of network result factory protocol.
     *
     *  - paramaters:
     *    - factory: Concrete implementation of ```NetworkResultFactoryProtocol```.
     */

    public init<U: NetworkResultFactoryProtocol>(factory: U) where U.ResultType == ResultType {
        _createResult = factory.createResult
    }

    /**
     *  Creates type erasure wrapper of network result factory protocol
     *  that executes closure to process the response in order to form result.
     *
     *  - parameters:
     *    - block: Closure to process network response in order to form
     *    result.
     */

    public init(block: @escaping NetworkResultFactoryBlock<ResultType>) {
        _createResult = block
    }

    /**
     *  Creates type erasure wrapper of network result factory protocol
     *  that executes closure to receive the result value in case if response
     *  contains no errors. Otherwise an error is returned.
     *
     *  - parameters:
     *    - successResponseBlock: Closure to execute, in case response contains no error, to receive
     *    result.
     */

    public convenience init(
        successResponseBlock: @escaping NetworkResultFactorySuccessResponseBlock<ResultType>
    ) {
        self.init { data, response, error -> Result<ResultType, Error> in
            if let connectionError = error {
                return .failure(connectionError)
            }

            if let error = NetworkOperationHelper.createError(from: response, data: data) {
                return .failure(error)
            }

            let result = successResponseBlock()
            return .success(result)
        }
    }

    /**
     *  Creates type erasure wrapper of network result factory protocol
     *  that executes closure to produce result from response data in case of successfull
     *  response.
     *
     *  - parameters:
     *    - processingBlock: Closure to execute, in case response contains no error, to receive
     *    result from response data.
     */

    public convenience init(
        processingBlock: @escaping NetworkResultFactoryProcessingBlock<ResultType>
    ) {
        self.init { data, response, error -> Result<ResultType, Error> in
            if let connectionError = error {
                return .failure(connectionError)
            }

            if let error = NetworkOperationHelper.createError(from: response, data: data) {
                return .failure(error)
            }

            guard let documentData = data else {
                return .failure(NetworkBaseError.unexpectedEmptyData)
            }

            do {
                let value = try processingBlock(documentData)
                return .success(value)
            } catch {
                return .failure(error)
            }
        }
    }

    public func createResult(
        data: Data?,
        response: URLResponse?,
        error: Error?
    ) -> Result<ResultType, Error> {
        _createResult(data, response, error)
    }
}
