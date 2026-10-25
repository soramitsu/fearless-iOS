/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/**
 *  Protocol is designed to interface access to local persistent storage and provides
 *  necessary CRUD operations to manage single entity type (```Model```).
 *  All methods of the implementation must return an operation and a client is responsible
 *  for its execution to receive result.
 */

public protocol DataProviderRepositoryProtocol {
    associatedtype Model: Identifiable

    /**
     *  Creates operation which fetches objects by identifier.
     *
     *  - parameters:
     *    - modelIdsClosure: Closure that returs identifiers to fetch.
     *    - options: Options to define fetch logic and caching policy.
     *  - returns: Operation that results in an array of objects or empty if there is
     *  no objects with specified identifiers.
     */

    func fetchOperation(
        by modelIdsClosure: @escaping () throws -> [String],
        options: RepositoryFetchOptions
    ) -> BaseOperation<[Model]>

    /**
     *  Creates operation which fetches object by identifier.
     *
     *  - parameters:
     *    - modelIdClosure: Closure that returs identifier to fetch.
     *    - options: Options to define fetch logic and caching policy.
     *  - returns: Operation that results in an object or nil if there is
     *  no object with specified identifier.
     */

    func fetchOperation(
        by modelIdClosure: @escaping () throws -> String,
        options: RepositoryFetchOptions
    ) -> BaseOperation<Model?>

    /**
     *  Creates operation which fetches all objects.
     *
     *  - parameters:
     *    - options: Options to define fetch logic and caching policy.
     *  - returns: Operation that results in a list of objects.
     */

    func fetchAllOperation(with options: RepositoryFetchOptions) -> BaseOperation<[Model]>

    /**
     *  Creates operation which fetches subset of objects.
     *
     *  - parameters:
     *      - request: Defines which slice to pick from the list of objects.
     *      - options: Options to define fetch logic and caching policy.
     *  - returns: Operation that results in a list of objects.
     */

    func fetchOperation(
        by request: RepositorySliceRequest,
        options: RepositoryFetchOptions
    ) -> BaseOperation<[Model]>

    /**
     *  Creates operation which persists changes to the list of objects.
     *
     *  - parameters:
     *    - updateModelsBlocks: Closure which returns list of objects to create or update.
     *    - deleteIdsBlock: Closure which returns identifiers of objects to delete.
     *  - returns: Operation that returns nothing.
     */

    func saveOperation(
        _ updateModelsBlock: @escaping () throws -> [Model],
        _ deleteIdsBlock: @escaping () throws -> [String]
    ) -> BaseOperation<Void>

    func saveBatchOperation(
        _ updateModelsBlock: @escaping () throws -> [Model],
        _ deleteIdsBlock: @escaping () throws -> [String]
    ) -> BaseOperation<Void>

    /**
     *  Creates operation which that replaces persisted list of objects.
     *
     *  - parameters:
     *    - newModelsBlocks: Closure which returns list of objects to replace old one.
     *  - returns: Operation that returns nothing.
     */

    func replaceOperation(_ newModelsBlock: @escaping () throws -> [Model]) -> BaseOperation<Void>

    /**
     *  Creates operation which calculates number of objects in the repository.
     *
     *  - returns: Operations that results in a number of object in the repository.
     */

    func fetchCountOperation() -> BaseOperation<Int>

    /**
     *  Creates operation which removes all objects.
     *
     *  - returns: Operation which returns nothing.
     */

    func deleteAllOperation() -> BaseOperation<Void>
}

extension DataProviderRepositoryProtocol {
    /**
     *  Creates operation which fetches object by identifier.
     *
     *  - parameters:
     *    - modelId: Identifier of the object to fetch.
     *  - returns: Operation that results in an object or nil if there is
     *  no object with specified identifier.
     */

    func fetchOperation(by modelId: String) -> BaseOperation<Model?> {
        fetchOperation(by: modelId, options: RepositoryFetchOptions())
    }

    /**
     *  Creates operation which fetches all objects.
     *
     *  - returns: Operation that results in a list of objects.
     */

    func fetchAllOperation() -> BaseOperation<[Model]> {
        fetchAllOperation(with: RepositoryFetchOptions())
    }

    /**
     *  Creates operation which fetches subset of objects.
     *
     *  - parameters:
     *     - request: Defines which slice to pick from the list of objects.
     *  - returns: Operation that results in a list of objects.
     */

    func fetchOperation(by request: RepositorySliceRequest) -> BaseOperation<[Model]> {
        fetchOperation(by: request, options: RepositoryFetchOptions())
    }
}

/**
 *  Protocol is designed to provide an interface to observe changes in repository.
 */

public protocol DataProviderRepositoryObservable {
    associatedtype Model

    /**
     *  Asks to start notifying observers if any changes arrive.
     *
     *  - parameters:
     *    - completionBlock: Closure to call when observable sucessfully activated or failed.
     *      In case of failure an error is passed as a parameter.
     */

    func start(completionBlock: @escaping (Error?) -> Void)

    /**
     *  Asks to stop notifying observers.
     *
     *  - parameters:
     *    - completionBlock: Closure to call when observable sucessfully deactivated or failed.
     *      In case of failure an error is passed as a parameter.
     */

    func stop(completionBlock: @escaping (Error?) -> Void)

    /**
     *  Adds an observer to receive repository changes.
     *
     *  - parameters:
     *    - observer: An observer which is responsible for handling changes. It is expected
     *      that implementation does nothing if the observer already exists.
     *    - queue: Dispatch queue to execute closure containing changes in.
     *    - updateBlock: Closure to deliver changes to observer.
     */

    func addObserver(
        _ observer: AnyObject,
        deliverOn queue: DispatchQueue,
        executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void
    )

    /**
     *  Removes an observer from repository's observers list.
     *
     *  - parameters:
     *    - observer: An observer to remove from the list.
     */

    func removeObserver(_ observer: AnyObject)
}

public extension DataProviderRepositoryProtocol {
    /**
     *  Creates operation which fetches object by identifier.
     *
     *  - parameters:
     *    - modelId: Identifier of the object to fetch.
     *    - options: Options to define fetch logic and caching policy.
     *  - returns: Operation that results in an object or nil if there is
     *  no object with specified identifier.
     */

    func fetchOperation(
        by modelId: String,
        options: RepositoryFetchOptions
    ) -> BaseOperation<Model?> {
        fetchOperation(by: { modelId }, options: options)
    }

    func fetchOperation(
        by modelIds: [String],
        options: RepositoryFetchOptions
    ) -> BaseOperation<[Model]> {
        fetchOperation(by: { modelIds }, options: options)
    }
}
