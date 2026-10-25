/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/**
 *  Protocol is designed to provide an access to locally persistent (cached) list of objects triggering
 *  fetch of fresh ones from remote source and saving them into local storage. Clients can fetch data and suscribe
 *  for changes using methods described below.
 *
 *  Concrete implementation is expected to:
 *  - provide list of objects to the client;
 *  - synchronize list of object with remote source;
 *  - be in charge of finding difference between old and new sets to notify observers only when there are changes;
 *  - support pagination, however it is only expected that it caches first page;
 */

public protocol DataProviderProtocol {
    associatedtype Model: Identifiable

    /**
     *  Operation queue by which all operations of data provider are executed. Usually it should be provided
     *  during initialization to have a possibility to chain with operations outside of data provider.
     */

    var executionQueue: OperationQueue { get }

    /**
     *  Searches an object in local store by id or fetches from remote store in case if search returns empty result.
     *
     *  - note: It is not expected from concreate implementation to persist remote data at this point to
     *  avoid conflicts with main update mechanism.
     *
     *  - parameters:
     *    - modelId: Identifier of the object to fetch.
     *    - completionBlock: Block to call on completion. `Result` value is passed as a parameter.
     *  - returns: Operations object wrapper to cancel if there is a need or to chain with other operations.
     *  **Don't try** to override target operation's completion block but provide completion
     *  block to the function instead.
     */

    func fetch(
        by modelId: String,
        completionBlock: ((Result<Model?, Error>?) -> Void)?
    )
        -> CompoundOperationWrapper<Model?>

    /**
     *  Returns a concrete page of objects from local store or fetches from remote store in case it is absent locally.
     *
     *  It is required from the implementation to return optimal amount of objects per page and manage
     *  offsets within the list.
     *
     *  - note: It is only expected that concreate implementation caches the first page. Current method
     *  is not expected to update local storage to avoid conflicts with main update mechanism.
     *
     *  - parameters:
     *    - page: `UInt` index of the page.
     *    - completionBlock: Block to call on completion. `Result` value is passed as a parameter.
     *  - returns: Operations object wrapper to cancel if there is a need or to chain with other operations.
     *  **Don't try** to override target operation's completion block but provide completion
     *  block to the function instead.
     */

    func fetch(
        page index: UInt,
        completionBlock: ((Result<[Model], Error>?) -> Void)?
    )
        -> CompoundOperationWrapper<[Model]>

    /**
     *  Adds observer to notify when there are changes in local storage.
     *
     *  The method calls update closure as soon as an observer is added and passes
     *  list of persisted objects. The closure is also called later after each synchronization attempt
     *  in case of changes or if `alwaysNotifyOnRefresh` flag set in provided `options`. Failure block
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
     *    - updateBlock: Closure to call when there are changes in local store. It is also called immediately
     *      after observer is added to observers list and delivers current list of objects from local store.
     *      If there is a need to be notified even if there are no changes during synchronization then
     *      consider to set `alwaysNotifyOnRefresh` in options.
     *    - failureBlock: Closure to call in case data provider failed to add the observer. It is also called
     *      after failed synchronization but only if `alwaysNotifyOnRefresh` flag is set in options.
     *    - options: Controls a way of how and when observer is notified.
     */

    func addObserver(
        _ observer: AnyObject,
        deliverOn queue: DispatchQueue?,
        executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void,
        failing failureBlock: @escaping (Error) -> Void,
        options: DataProviderObserverOptions
    )

    /**
     *  Removes an observer from the list of observers.
     *
     *  - parameters:
     *    - observer: An object to remove from the list of observers.
     */

    func removeObserver(_ observer: AnyObject)

    /**
     *  Manually initiates synchronization if there is no one running.
     */

    func refresh()
}

public extension DataProviderProtocol {
    /**
     *  Adds observer to notify when there are changes in local storage.
     *
     *  The method calls update closure as soon as an observer is added and passes
     *  list of persisted objects. The closure is also called later after each synchronization attempt
     *  in case of changes or if `alwaysNotifyOnRefresh` flag set in provided `options`. Failure block
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
     *    - updateBlock: Closure to call when there are changes in local store. It is also called immediately
     *      after observer is added to observers list and delivers current list of objects from local store.
     *      If there is a need to be notified even if there are no changes during synchronization then
     *      consider to set `alwaysNotifyOnRefresh` in options.
     *    - failureBlock: Closure to call in case data provider failed to add the observer. It is also called
     *      after failed synchronization but only if `alwaysNotifyOnRefresh` flag is set in options.
     */

    func addObserver(
        _ observer: AnyObject,
        deliverOn queue: DispatchQueue?,
        executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void,
        failing failureBlock: @escaping (Error) -> Void
    ) {
        addObserver(
            observer,
            deliverOn: queue,
            executing: updateBlock,
            failing: failureBlock,
            options: DataProviderObserverOptions()
        )
    }
}

/**
 *  Protocol is designed to fetch data from remote source by a data provider.
 */

public protocol DataProviderSourceProtocol {
    associatedtype Model: Identifiable

    /**
     *  Fetches an object by id from remote source.
     *
     *  - parameters:
     *    - modelId: String that unique identifies the object to fetch;
     *
     *  - returns: Operation object wrapper to cancel if there is needed or to
     *   chain with other operations.
     */

    func fetchOperation(by modelId: String) -> CompoundOperationWrapper<Model?>

    /**
     *  Fetches a page of objects from remote source.
     *
     *  - note: Implementation is expected to propose optimal page size and manage
     *  page offset.
     *
     *  - parameters:
     *    - page: `UInt` index of the page.
     *
     *  - returns: Operation object wrapper to cancel if there is needed or to
     *   chain with other operations.
     */
    func fetchOperation(page index: UInt) -> CompoundOperationWrapper<[Model]>
}
