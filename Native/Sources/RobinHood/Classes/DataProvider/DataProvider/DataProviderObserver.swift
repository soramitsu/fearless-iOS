/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public struct DataProviderObserver<T, P> {
    public private(set) weak var observer: AnyObject?
    public private(set) var queue: DispatchQueue?
    public private(set) var updateBlock: ([DataProviderChange<T>]) -> Void
    public private(set) var failureBlock: (Error) -> Void
    public private(set) var options: P

    public init(
        observer: AnyObject,
        queue: DispatchQueue?,
        updateBlock: @escaping ([DataProviderChange<T>]) -> Void,
        failureBlock: @escaping (Error) -> Void,
        options: P
    ) {
        self.observer = observer
        self.options = options
        self.queue = queue
        self.updateBlock = updateBlock
        self.failureBlock = failureBlock
    }
}

struct DataProviderPendingObserver<T> {
    private(set) weak var observer: AnyObject?
    private(set) var operation: BaseOperation<T>?

    init(observer: AnyObject, operation: BaseOperation<T>) {
        self.observer = observer
        self.operation = operation
    }
}
