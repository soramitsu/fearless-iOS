/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/**
 *  Class is designed to apply type erasure technique to ```DataProviderProtocol```.
 */

public final class AnyDataProvider<T: Identifiable & Equatable>: DataProviderProtocol {
    public typealias Model = T

    private let _fetchById: (String, ((Result<T?, Error>?) -> Void)?)
        -> CompoundOperationWrapper<T?>
    private let _fetchPage: (UInt, ((Result<[T], Error>?) -> Void)?)
        -> CompoundOperationWrapper<[T]>

    private let _addObserver: (
        AnyObject,
        DispatchQueue?,
        @escaping ([DataProviderChange<T>]) -> Void,
        @escaping (Error) -> Void,
        DataProviderObserverOptions
    ) -> Void

    private let _removeObserver: (AnyObject) -> Void

    private let _refresh: () -> Void

    public private(set) var executionQueue: OperationQueue

    /**
     *  Initializes type erasure wrapper for data provider protocol implementation.
     *
     *  - parameters:
     *    - dataProvider: Data provider to apply type erasure to.
     */

    public init<U: DataProviderProtocol>(_ dataProvider: U) where U.Model == Model {
        _fetchById = dataProvider.fetch
        _fetchPage = dataProvider.fetch
        _addObserver = dataProvider.addObserver
        _removeObserver = dataProvider.removeObserver
        _refresh = dataProvider.refresh
        executionQueue = dataProvider.executionQueue
    }

    public func fetch(
        by modelId: String,
        completionBlock: ((Result<T?, Error>?) -> Void)?
    )
        -> CompoundOperationWrapper<T?>
    {
        _fetchById(modelId, completionBlock)
    }

    public func fetch(
        page index: UInt,
        completionBlock: ((Result<[T], Error>?) -> Void)?
    )
        -> CompoundOperationWrapper<[T]>
    {
        _fetchPage(index, completionBlock)
    }

    public func addObserver(
        _ observer: AnyObject,
        deliverOn queue: DispatchQueue?,
        executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void,
        failing failureBlock: @escaping (Error) -> Void,
        options: DataProviderObserverOptions
    ) {
        _addObserver(observer, queue, updateBlock, failureBlock, options)
    }

    public func removeObserver(_ observer: AnyObject) {
        _removeObserver(observer)
    }

    public func refresh() {
        _refresh()
    }
}
