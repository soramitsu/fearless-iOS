/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/**
 *  Class is designed to give an opportunity to represent a set of dependent operations as a single
 *  object with an access to target operation which is assumed to produce final result and all operations
 *  it depends on.
 */

public class CompoundOperationWrapper<ResultType> {
    /**
     *  Returns a list which consists of dependencies and target operation.
     */

    public var allOperations: [Operation] {
        dependencies + [targetOperation]
    }

    /**
     *  Reprensets a list of operations on which target operation depends on.
     */

    public let dependencies: [Operation]

    /**
     *  Represents an operations that is assumed to produce target result.
     */

    public let targetOperation: BaseOperation<ResultType>

    public init(targetOperation: BaseOperation<ResultType>, dependencies: [Operation] = []) {
        self.targetOperation = targetOperation
        self.dependencies = dependencies
    }
}

extension CompoundOperationWrapper: CancellableCall {
    public func cancel() {
        allOperations.forEach { $0.cancel() }
    }
}
