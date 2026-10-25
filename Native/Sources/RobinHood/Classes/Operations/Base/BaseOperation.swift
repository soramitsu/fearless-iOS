/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Type defines a closure that can be provided to configure an operation.
public typealias OperationConfigBlock = () -> Void

/**
 *  Enum is designed to define most common errors related
 *  to operations.
 */
public enum BaseOperationError: Error {
    /// Parameter operation has been unexpectedly cancelled.
    case parentOperationCancelled

    /// Dependency operation provided unexpected result.
    case unexpectedDependentResult
}

/**
 *  Class is designed to provide base implementation
 *  of generic operation.
 *
 *  Operation contains configuration closure that is executed
 *  when operation starts to setup internal parameters based on dependencies.
 *  Moreover it maintains Swift result which is:
 *  - remains ```nil``` if operation is cancelled;
 *  - is initialized with generic value in case of success;
 *  - is initialized with error in case of failure;
 */

open class BaseOperation<ResultType>: Operation {
    /**
     *  Result of the operation which is:
     *  - remains ```nil``` if operation is cancelled;
     *  - is initialized with generic value in case of success;
     *  - is initialized with error in case of failure;
     */

    open var result: Result<ResultType, Error>?

    /**
     *  Configuration closure to execute when operation starts.
     *
     *  Closure is automatically set to ```nil``` after execution.
     */
    open var configurationBlock: OperationConfigBlock?

    override open func main() {
        configurationBlock?()
        configurationBlock = nil
    }

    override open func cancel() {
        configurationBlock = nil
        super.cancel()
    }
}
