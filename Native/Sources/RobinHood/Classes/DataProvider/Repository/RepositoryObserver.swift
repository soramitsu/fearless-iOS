/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/**
 *  Class is designed to weakly store information about repository observer.
 */

public struct RepositoryObserver<T> {
    /// An object which is responsible for handling changes in repository.
    public private(set) weak var observer: AnyObject?

    /// Queue to execute update closure in.
    public private(set) var queue: DispatchQueue

    /// Closure to deliver changes to observers. Closure is executed in ```queue```.
    public private(set) var updateBlock: ([DataProviderChange<T>]) -> Void

    /**
     *  Initializes repository observer.
     *
     *  - parameters:
     *    - observer: An object which is responsible for handling changes in repository.
     *    - queue: Queue to execute update closure in.
     *    - updateBlock: Closure to deliver changes to observers. Closure is executed in ```queue```.
     */

    public init(
        observer: AnyObject,
        queue: DispatchQueue,
        updateBlock: @escaping ([DataProviderChange<T>]) -> Void
    ) {
        self.observer = observer
        self.queue = queue
        self.updateBlock = updateBlock
    }
}
