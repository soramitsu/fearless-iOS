/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/**
 *  Subclass of the ```BaseOperation``` designed to execute external closure
 *  to produce operation result.
 *
 *  Operation does nothing if result is set when operation starts.
 */

public final class ClosureOperation<ResultType>: BaseOperation<ResultType> {
    /// Closure to execute to produce operation result.
    public let closure: () throws -> ResultType

    /**
     *  Create closure operation.
     *
     *  - parameters:
     *    - closure: Closure to execute to produce operation result.
     */

    public init(closure: @escaping () throws -> ResultType) {
        self.closure = closure
    }

    override public func main() {
        super.main()

        if isCancelled {
            return
        }

        if result != nil {
            return
        }

        do {
            let executionResult = try closure()
            result = .success(executionResult)
        } catch {
            result = .failure(error)
        }
    }
}
