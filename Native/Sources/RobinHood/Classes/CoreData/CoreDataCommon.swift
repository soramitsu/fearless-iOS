/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import CoreData
import Foundation

/**
 *  Enum is defining possible strategies to handle situations
 *  when Core Data entity model is incompatible with persistent store.
 */

public enum IncompatibleModelHandlingStrategy {
    /// do nothing.
    case ignore

    /// remove incompatible stored data.
    case removeStore
}

/**
 *  Structure is designed to define persistence settings of Core Data store.
 */

public struct CoreDataPersistentSettings {
    /// Url of the directory where to store database.
    public var databaseDirectory: URL

    /// Name of the database file.
    public var databaseName: String

    /// Strategy that defines how to handle incompatible persisten store.
    public var incompatibleModelStrategy: IncompatibleModelHandlingStrategy

    /// Flag that states whether to allow database backup to iCloud.
    public var excludeFromiCloudBackup: Bool

    /// Store Options and Migration Options
    public var options: [AnyHashable: Any]?

    /**
     *  Creates Core Data persistent store settins.
     *
     *  - parameters:
     *    - databaseDirectory: Url of the directory where to store database.
     *    - databaseName: Name of the database file.
     *    - incompatibleModelStrategy: Strategy that defines how to handle
     *    incompatible persisten store.
     *    - excludeFromiCloudBackup: Flag that states whether to allow database
     *    backup to iCloud.
     *    - options: A dictionary containing key-value pairs that specify whether the store should be read-only,
     *    and whether (for an XML store) the XML file should be validated against the DTD before it is read.
     *    For key definitions, see Store Options and Migration Options. This value may be nil.
     */

    public init(
        databaseDirectory: URL,
        databaseName: String,
        incompatibleModelStrategy: IncompatibleModelHandlingStrategy = .ignore,
        excludeFromiCloudBackup: Bool = true,
        options: [AnyHashable: Any]? = nil
    ) {
        self.databaseDirectory = databaseDirectory
        self.databaseName = databaseName
        self.incompatibleModelStrategy = incompatibleModelStrategy
        self.excludeFromiCloudBackup = excludeFromiCloudBackup
        self.options = options
    }
}

/**
 *  Enum defines type of Core Data storage.
 */

public enum CoreDataServiceStorageType {
    /// Persist data to disk. Takes persistent settings as associated value.
    case persistent(settings: CoreDataPersistentSettings)

    /// Store data in memory.
    case inMemory
}

/**
 *  Protocol is designed to define configuration of Core Data service.
 */

public protocol CoreDataServiceConfigurationProtocol {
    /// URL of the Core Data entity model.
    var modelURL: URL { get }

    /// Storage type to use.
    var storageType: CoreDataServiceStorageType { get }
}

/**
 *  Closure to asynchroniously deliver Core Data context when requested. ```Nil```
 *  is passed for context parameter when an error occured which is delivered as
 *  a second parameter.
 */

public typealias CoreDataContextInvocationBlock = (NSManagedObjectContext?, Error?) -> Void

/**
 *  Protocol is designed to define an interface to manage configuration and access to Core Data store.
 */

public protocol CoreDataServiceProtocol {
    /// Value that is passed during initialization to configure the service.
    var configuration: CoreDataServiceConfigurationProtocol { get }

    /**
     *  Requests Core Data context. Context is asynchroniously delivered as soon
     *  as become available. If there is an error occured then context ```nil```
     *  is passed for context parameter and error value is delivered as a second one.
     */

    func performAsync(block: @escaping CoreDataContextInvocationBlock)

    /**
     *  Closes Core Data store. Implementation should open the store when a context
     *  is requested for the first time.
     */
    func close() throws

    /**
     *  Removes Core Data store.
     *
     *  - note: Core Data store must be closed before calling this function. See ```close``` method for
     *  more details.
     */
    func drop() throws
}
