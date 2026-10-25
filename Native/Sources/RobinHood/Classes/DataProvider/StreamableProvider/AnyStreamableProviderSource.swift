/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Closure to execute history fetch request
public typealias AnyStreamableSourceFetchBlock = (DispatchQueue?, ((Result<Int, Error>?) -> Void)?)
    -> Void

/**
 *  Type erasure implementation of `StreamableSourceProtocol` protocol. It should be used
 *  to wrap concrete implementation of `StreamableSourceProtocol` before passing as dependency
 *  to streamable data provider.
 */

public final class AnyStreamableSource<T: Identifiable>: StreamableSourceProtocol {
    public typealias Model = T

    private let _fetchHistory: AnyStreamableSourceFetchBlock
    private let _refresh: AnyStreamableSourceFetchBlock

    /**
     *  Initializes type erasure wrapper for streamable source implementation.
     *
     *  - parameters:
     *    - source: Streamable source implementation to erase type of.
     */

    public init<U: StreamableSourceProtocol>(_ source: U) where U.Model == Model {
        _fetchHistory = source.fetchHistory
        _refresh = source.refresh
    }

    /**
     *  Initializes type erasure wrapper with history request closure.
     *
     *  - parameters:
     *    - fetchHistory: Closure to request history from streamable remote source.
     *    - refresh: Closure to request refresh operation from streamable remote source.
     */

    public init(
        fetchHistory: @escaping AnyStreamableSourceFetchBlock,
        refresh: @escaping AnyStreamableSourceFetchBlock
    ) {
        _fetchHistory = fetchHistory
        _refresh = refresh
    }

    public func fetchHistory(
        runningIn queue: DispatchQueue?,
        commitNotificationBlock: ((Result<Int, Error>?) -> Void)?
    ) {
        _fetchHistory(queue, commitNotificationBlock)
    }

    public func refresh(
        runningIn queue: DispatchQueue?,
        commitNotificationBlock: ((Result<Int, Error>?) -> Void)?
    ) {
        _refresh(queue, commitNotificationBlock)
    }
}
