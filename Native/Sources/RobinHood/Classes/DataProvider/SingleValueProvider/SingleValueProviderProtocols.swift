/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/**
 *  Protocol is designed to provide an access to locally persistent (cached) object triggering
 *  fetch of fresh one from remote source and saving it into local storage. Clients can fetch object and suscribe
 *  for changes using methods described below.
 *
 *  Concrete implementation is expected to:
 *  - provide the object to the client;
 *  - synchronize the object with remote source;
 *  - be in charge of finding difference between old and new objects to notify observers only when there are changes;
 */

public protocol SingleValueProviderProtocol {
    associatedtype Model

    /**
     *  Operation queue by which all operations of data provider are executed. Usually it should be provided
     *  during initialization to have a possibility to chain with operations outside of data provider.
     */

    var executionQueue: OperationQueue { get }

    /**
     *  Searches the object in local store or fetches from remote store in case if search returns no result.
     *
     *  - note: It is not expected from concreate implementation to persist remote data at this point to
     *  avoid conflicts with main update mechanism.
     *
     *  - parameters:
     *    - completionBlock: Block to call on completion. `Result` value is passed as a parameter.
     *  - returns: Operation object wrapper to cancel if there is a need or to chain with other operations.
     *  **Don't try** to override target operation's completion block but provide completion
     *  block to the function instead.
     */

    func fetch(with completionBlock: ((Result<Model?, Error>?) -> Void)?)
        -> CompoundOperationWrapper<Model?>

    /**
     *  Adds observer to notify when there are changes in local storage.
     *
     *  The method calls update closure as soon as an observer is added and passes
     *  persisted object. The closure is also called later after each synchronization attempt
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

public extension SingleValueProviderProtocol {
    /**
     *  Adds observer to notify when there are changes in local storage.
     *
     *  The method calls update closure as soon as an observer is added and passes
     *  persisted object. The closure is also called later after each synchronization attempt
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
 *  Protocol is designed to fetch the object from remote source by a data provider.
 */

public protocol SingleValueProviderSourceProtocol {
    associatedtype Model

    /**
     *  Fetches then object from remote source.
     *
     *  - returns: Operation wrapper object to cancel if needed or chain with other
     *  operations.
     */

    func fetchOperation() -> CompoundOperationWrapper<Model?>
}
