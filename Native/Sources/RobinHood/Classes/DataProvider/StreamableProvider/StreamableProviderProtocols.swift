/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/**
 *  Protocol is designed to provide an access to locally persistent list of objects that gets updated by
 *  streaming changes from the remote. Clients can fetch objects and suscribe for changes using methods described below.
 *
 *  Due to the nature of streaming it is convienent that source implementation will directly save changes to
 *  repository. Provider in this case is expected to trigger history fetch from data source and deliver
 *  changes received by listening repository to observers.
 */

public protocol StreamableProviderProtocol {
    associatedtype Model: Identifiable

    /**
     *  Triggers data source to start refreshing. Also provider make sure that all observers
     *  are always notified when refresh completes in case
     *  of ```alwaysNotifyOnRefresh``` flag provided in options.
     */

    func refresh()

    /**
     *  Returns list of objects from local store or fetches from remote store if it is not enough.
     *
     *  - parameters:
     *    - offset: `Int` offset to fetch objects from.
     *    - count: `Int` number of objects to fetch.
     *    - synchronized: `Bool` whether to request pessimistic access to read from local storage.
     *    - completionBlock: Block to call on completion. `Result` value is passed as a parameter.
     *    Note that remote objects may not be delivered in the completion closure and the client needs to add
     *    an observer to receive remained part of the list.
     *  - returns: Operation wrapper object to cancel if there is a need or to chain with other operations.
     *  **Don't try** to override target operation's completion block but provide completion
     *  block to the function instead.
     */

    func fetch(
        offset: Int,
        count: Int,
        synchronized: Bool,
        with completionBlock: @escaping (Result<[Model], Error>?) -> Void
    )
        -> CompoundOperationWrapper<[Model]>

    /**
     *  Adds observer to notify when there are changes in local storage.
     *
     *  The closure is called after each received set
     *  of changes or if `alwaysNotifyOnRefresh` flag set in provided `options`. Failure block
     *  is called in case data provider is failed to add an observer or after each failed synchronization
     *  attempt in case `alwaysNotifyOnRefresh` flag is set. Consider also `options` parameter to
     *  properly setup a way of how and when observer is notified.
     *
     *  - parameters:
     *    - observer: An object which is responsible for handling changes. The object is not retained
     *      so it will be automatically removed from observation when deallocated. If the object
     *      is already in the observers list then failure block is called with `observerAlreadyAdded` error.
     *    - queue: Queue to dispatch update and failure blocks in. If `nil` is provided for this parameter
     *      then closures are dispatched in internal queue.
     *    - updateBlock: Closure to call when there are changes in local store.
     *      If there is a need to be notified even if there are no objects recevied
     *      after ```fetch(offset:count:with:)``` call from remote source then consider to set
     *      `alwaysNotifyOnRefresh` in options.
     *    - failureBlock: Closure to call in case data provider failed to add the observer. It is also called
     *      after failed synchronization but only if `alwaysNotifyOnRefresh` flag is set in options.
     *    - options: Controls a way of how and when observer is handled.
     */

    func addObserver(
        _ observer: AnyObject,
        deliverOn queue: DispatchQueue,
        executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void,
        failing failureBlock: @escaping (Error) -> Void,
        options: StreamableProviderObserverOptions
    )

    /**
     *  Removes an observer from the list of observers.
     *
     *  - parameters:
     *    - observer: An object to remove from the list of observers.
     */

    func removeObserver(_ observer: AnyObject)
}

public extension StreamableProviderProtocol {
    /**
     *  Adds observer to notify when there are changes in local storage.
     *
     *  The closure is also called after each received set
     *  of changes or if `alwaysNotifyOnRefresh` flag set in provided `options`. Failure block
     *  is called in case data provider is failed to add an observer or after each failed synchronization
     *  attempt in case `alwaysNotifyOnRefresh` flag is set. Consider also `options` parameter to
     *  properly setup a way of how and when observer is notified.
     *
     *  - note: This method just calls original `addObserver(_:deliverOn:executing:failing:options)`
     *      with default options.
     *
     *  - parameters:
     *    - observer: An object which is responsible for handling changes. The object is not retained
     *      so it will be automatically removed from observation when deallocated. If the object
     *      is already in the observers list then failure block is called with `observerAlreadyAdded` error.
     *    - queue: Queue to dispatch update and failure blocks in. If `nil` is provided for this parameter
     *      then closures are dispatched in internal queue.
     *    - updateBlock: Closure to call when there are changes in local store.
     *      If there is a need to be notified even if there are no objects recevied after
     *      ```fetch(offset:count:with:)``` call from remote source then consider to set
     *      `alwaysNotifyOnRefresh` in options.
     *    - failureBlock: Closure to call in case data provider failed to add the observer. It is also called
     *      after failed synchronization but only if `alwaysNotifyOnRefresh` flag is set in options.
     *    - options: Controls a way of how and when observer is notified.
     */

    func addObserver(
        _ observer: AnyObject,
        deliverOn queue: DispatchQueue,
        executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void,
        failing failureBlock: @escaping (Error) -> Void
    ) {
        addObserver(
            observer,
            deliverOn: queue,
            executing: updateBlock,
            failing: failureBlock,
            options: StreamableProviderObserverOptions()
        )
    }
}

/**
 *  Protocol is designed to provide an inteface of fetching history from the remote stream.
 *
 *  Concrete implementation must be responsible for saving changes directly to repository.
 *  It can be objects received through stream or fetched as part of the history.
 */

public protocol StreamableSourceProtocol {
    associatedtype Model: Identifiable

    /**
     *  Fetches more data based on the repository and saves objects to the repository.
     *
     *  - parameters:
     *    - queue: Dispatch queue to execute completion closure in. By default is ```nil```
     *    meaning that completion closure will be executed in the internal queueu.
     *    - commitNotificationBlock: Optional closure to execute on completion. Swift result
     *    passed as closure parameter contains either number of saved objects or an error
     *    in case of failure.
     *
     *  - note: Implementation of the method must call completion with ```nil``` in case history
     *    fetching already in progress.
     */

    func fetchHistory(
        runningIn queue: DispatchQueue?,
        commitNotificationBlock: ((Result<Int, Error>?) -> Void)?
    )

    /**
     *  Fetches actual data from remote and replaces local ones.
     *
     *  - parameters:
     *    - queue: Dispatch queue to execute completion closure in. By default is ```nil```
     *      meaning that completion closure will be executed in the internal queueu.
     *    - commitNotificationBlock: Optional closure to execute on completion. Swift result
     *      passed as closure parameter contains either total number of changes or an error
     *      in case of failure.
     *
     *  - note: Implementation of the method must cancel any pending history fetch request and
     *    must call completion with ```nil``` in case refreshing already in progress.
     */
    func refresh(
        runningIn queue: DispatchQueue?,
        commitNotificationBlock: ((Result<Int, Error>?) -> Void)?
    )
}
