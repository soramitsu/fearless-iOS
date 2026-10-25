/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/**
 *  Class is designed to apply type erasure technique to ```DataProviderRepositoryObservable```
 */

public final class AnyDataProviderRepositoryObservable<T>: DataProviderRepositoryObservable {
    public typealias Model = T

    private let _start: (@escaping (Error?) -> Void) -> Void
    private let _stop: (@escaping (Error?) -> Void) -> Void
    private let _addObserver: (
        AnyObject,
        DispatchQueue,
        @escaping ([DataProviderChange<Model>]) -> Void
    ) -> Void
    private let _removeObserver: (AnyObject) -> Void

    /**
     *  Initializes type erasure wrapper for observable implementation.
     *
     *  - parameters:
     *    - repository: Repository implementation to erase type of.
     */

    public init<U: DataProviderRepositoryObservable>(_ observable: U) where U.Model == Model {
        _start = observable.start
        _stop = observable.stop
        _addObserver = observable.addObserver
        _removeObserver = observable.removeObserver
    }

    public func start(completionBlock: @escaping (Error?) -> Void) {
        _start(completionBlock)
    }

    public func stop(completionBlock: @escaping (Error?) -> Void) {
        _stop(completionBlock)
    }

    public func addObserver(
        _ observer: AnyObject,
        deliverOn queue: DispatchQueue,
        executing updateBlock: @escaping ([DataProviderChange<T>]) -> Void
    ) {
        _addObserver(observer, queue, updateBlock)
    }

    public func removeObserver(_ observer: AnyObject) {
        _removeObserver(observer)
    }
}
