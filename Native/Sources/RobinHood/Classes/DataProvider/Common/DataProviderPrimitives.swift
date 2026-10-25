/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/**
 *  Protocol that describes any unique identifiable instance.
 */

public protocol Identifiable {
    /// Unique identifier of the instance.

    var identifier: String { get }
}

/**
 *  Enum is designed to store changes introduced by data provider.
 */

public enum DataProviderChange<T> {
    /// New items has been added.
    /// Item is passed as associated value.
    case insert(newItem: T)

    /// Existing item has been updated
    /// Item is passed as associated value.
    case update(newItem: T)

    /// Existing item has been removed.
    /// Identifier of the item is passed as associated value.
    case delete(deletedIdentifier: String)

    /// Returns item if bounded as associated value.

    var item: T? {
        switch self {
        case let .insert(newItem):
            return newItem
        case let .update(newItem):
            return newItem
        default:
            return nil
        }
    }
}

/**
 *  Struct designed to store options needed to describe how an observer should be handled by data provider.
 */

public struct DataProviderObserverOptions {
    /// Asks data provider to notify observer in any case after synchronization completes.
    /// If this value is `false` (default value) then observer is only notified when
    /// there are changes after synchronization.
    public var alwaysNotifyOnRefresh: Bool

    /// Asks data provider to wait until any in progress synchronization completes before adding the
    /// observer.
    /// By default the value is `true`.
    /// - note: Passing `false` may significantly improve performance however may also introduce
    /// inconsitency between
    /// observer's local data and persistent data if a repository doesn't have any synchronization
    /// mechanism.
    public var waitsInProgressSyncOnAdd: Bool

    /// - parameters:
    ///    - alwaysNotifyOnRefresh: Asks data provider to notify observer in any case after
    /// synchronization completes.
    ///    Default value is `false`.
    ///
    ///    - waitsInProgressSyncOnAdd: Asks data provider to wait until any in progress
    /// synchronization
    ///    completes before adding the observer. Default value is `true`. Passing `false` may
    /// significantly
    ///    improve performance however may also introduce inconsitency between observer's local data
    /// and
    ///    persistent data if a repository doesn't have any synchronization mechanism.

    public init(
        alwaysNotifyOnRefresh: Bool = false,
        waitsInProgressSyncOnAdd: Bool = true
    ) {
        self.alwaysNotifyOnRefresh = alwaysNotifyOnRefresh
        self.waitsInProgressSyncOnAdd = waitsInProgressSyncOnAdd
    }
}

/**
 *  Struct designed to store options needed to describe how an observer should be handled by streamable
 *  data provider.
 */

public struct StreamableProviderObserverOptions {
    /// Asks data provider to notify observer in any case after synchronization completes.
    /// If this value is `false` (default value) then observer is only notified when
    /// there are changes after synchronization.
    public var alwaysNotifyOnRefresh: Bool

    /// Asks data provider to wait until any in progress synchronization completes before adding the
    /// observer.
    /// By default the value is `true`.
    /// - note: Passing `false` may significantly improve performance however may also introduce
    /// inconsitency
    /// between observer's local data and persistent data if a repository
    /// doesn't have any synchronization mechanism.
    public var waitsInProgressSyncOnAdd: Bool

    /// Number of items to fetch from local store and return in update block call after
    /// observer successfully added.
    /// Bu default the value is ```0```.
    /// - note: If the value is less or equal to zero than all existing objects are fetched.
    public var initialSize: Int

    /// Refreshes list using data source when one from repository is empty.
    /// By default ```true```.
    public var refreshWhenEmpty: Bool
    
    /// Will notify just when local repository was updated.
    /// By default ```false```.
    public var notifyJustWhenUpdated: Bool

    /// - parameters:
    ///    - alwaysNotifyOnRefresh: Asks data provider to notify observer in any case
    ///    after synchronization completes.
    ///    Default value is `false`.
    ///
    ///    - waitsInProgressSyncOnAdd: Asks data provider to wait until any in progress
    /// synchronization
    ///    completes before adding the observer. Default value is `true`. Passing `false` may
    /// significantly
    ///    improve performance however may also introduce inconsitency between observer's local data
    /// and
    ///    persistent data if a repository doesn't have any synchronization mechanism.
    ///
    ///    - initialSize: Number of items to fetch from local store and return in update block call
    /// after
    ///     observer successfully added. If the value is less or equal to zero than all
    ///     existing objects are fetched.
    ///
    ///    - refreshWhenEmpty: Calls refresh from data source when list fetched from repository is
    /// empty.
    ///    Default value is ```true```.

    public init(
        alwaysNotifyOnRefresh: Bool = false,
        waitsInProgressSyncOnAdd: Bool = true,
        initialSize: Int = 0,
        refreshWhenEmpty: Bool = true,
        notifyJustWhenUpdated: Bool = false
    ) {
        self.alwaysNotifyOnRefresh = alwaysNotifyOnRefresh
        self.waitsInProgressSyncOnAdd = waitsInProgressSyncOnAdd
        self.initialSize = initialSize
        self.refreshWhenEmpty = refreshWhenEmpty
        self.notifyJustWhenUpdated = notifyJustWhenUpdated
    }
}

/**
 *  Struct is designed to store options applied for fetch request from a repository.
 */

public struct RepositoryFetchOptions {
    /**
     *  If ```false``` properties are fetched when they are directly accessed
     *  (for example, when an entity is transformed to app model), otherwise all
     *  properties are fetched and cached. By default ```true```.
     */
    let includesProperties: Bool

    /**
     *  If ```false``` subentities are fetched when they are directly accessed
     *  (for example, when an entity is transformed to app model), otherwise all
     *  subentities are fetched and cached. By default ```true```.
     */
    let includesSubentities: Bool

    public init(includesProperties: Bool = true, includesSubentities: Bool = true) {
        self.includesProperties = includesProperties
        self.includesSubentities = includesSubentities
    }
}

public extension RepositoryFetchOptions {
    /**
     *  Creates options to prevent including both properties and subentities to the fetch request.
     */
    static var none: RepositoryFetchOptions {
        RepositoryFetchOptions(includesProperties: false, includesSubentities: false)
    }

    /**
     *  Creates options to prevent including subentities to the fetch request.
     */
    static var onlyProperties: RepositoryFetchOptions {
        RepositoryFetchOptions(includesProperties: true, includesSubentities: false)
    }
}

/**
 *  Struct is designed to request part of the list of objects from repository.
 */

public struct RepositorySliceRequest {
    /**
     *  Offset of the slice the list of objects
     */
    let offset: Int

    /**
     *  Maximum number of objects to fetch
     */
    let count: Int

    /**
     *  If ```true``` the objects in the slice is in reversed order.
     */
    let reversed: Bool

    public init(offset: Int, count: Int, reversed: Bool) {
        self.offset = offset
        self.count = count
        self.reversed = reversed
    }
}
