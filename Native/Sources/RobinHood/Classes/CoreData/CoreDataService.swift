/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import CoreData
import Foundation

/**
 *  Enum is defining errors which can occur during
 *  Core Data service work.
 */

public enum CoreDataServiceError: Error {
    /// Database file can't be created at given url.
    case databaseURLInvalid

    /// Can't instantiate Core Data entity model from url.
    case modelInitializationFailed

    /// Thrown when service is trying to be closed during setup.
    case unexpectedCloseDuringSetup

    /// Thrown when service is trying to drop persistent store but not closed.
    case unexpectedDropWhenOpen

    /// Can't remove incompatible persistent store.
    case incompatibleModelRemoveFailed
}

/**
 *  Class is designed to provide implementation of ```CoreDataServiceProtocol```
 *  which manages Core Data persistent store and contexts.
 */

public class CoreDataService {
    enum SetupState {
        case initial
        case inprogress
        case completed
    }

    public let configuration: CoreDataServiceConfigurationProtocol

    /**
     *  Creates Core Data service object.
     *
     *  - parameters:
     *    - configuration: Value to setup the service.
     */

    public init(configuration: CoreDataServiceConfigurationProtocol) {
        self.configuration = configuration
    }

    var context: NSManagedObjectContext?
    private let lock = NSLock()

    func databaseURL(with fileManager: FileManager) -> URL? {
        guard case let .persistent(settings) = configuration.storageType else {
            return nil
        }

        var dabaseDirectory = settings.databaseDirectory

        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: dabaseDirectory.path, isDirectory: &isDirectory),
           isDirectory.boolValue
        {
            return dabaseDirectory.appendingPathComponent(settings.databaseName)
        }

        do {
            try fileManager.createDirectory(at: dabaseDirectory, withIntermediateDirectories: true)

            var resources = URLResourceValues()
            resources.isExcludedFromBackup = settings.excludeFromiCloudBackup
            try dabaseDirectory.setResourceValues(resources)

            return dabaseDirectory.appendingPathComponent(settings.databaseName)
        } catch {
            return nil
        }
    }
}

// MARK: Internal Invocations logic

extension CoreDataService {
    func invoke(
        block: @escaping CoreDataContextInvocationBlock,
        in context: NSManagedObjectContext
    ) {
        context.perform {
            block(context, nil)
        }
    }
}

// MARK: Internal Setup Logic

extension CoreDataService {
    func setup() throws -> NSManagedObjectContext {
        let fileManager = FileManager.default
        let optionalDatabaseURL = databaseURL(with: fileManager)
        let storageType: String

        guard let model = NSManagedObjectModel(contentsOf: configuration.modelURL) else {
            throw CoreDataServiceError.modelInitializationFailed
        }

        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)

        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        var options: [AnyHashable: Any]?

        switch configuration.storageType {
        case let .persistent(settings):
            guard let databaseURL = optionalDatabaseURL else {
                throw CoreDataServiceError.databaseURLInvalid
            }

            if settings.incompatibleModelStrategy != .ignore &&
                !checkCompatibility(of: model, with: databaseURL, using: fileManager)
            {
                try fileManager.removeItem(at: databaseURL)
            }

            options = settings.options

            storageType = NSSQLiteStoreType
        case .inMemory:
            storageType = NSInMemoryStoreType
        }

        try coordinator.addPersistentStore(
            ofType: storageType,
            configurationName: nil,
            at: optionalDatabaseURL,
            options: options
        )

        self.context = context

        return context
    }
}

// MARK: Model Compatability

extension CoreDataService {
    func checkCompatibility(
        of model: NSManagedObjectModel,
        with databaseURL: URL,
        using fileManager: FileManager
    ) -> Bool {
        guard fileManager.fileExists(atPath: databaseURL.path) else {
            return true
        }

        do {
            let storeMetadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                ofType: NSSQLiteStoreType,
                at: databaseURL,
                options: nil
            )
            return model.isConfiguration(withName: nil, compatibleWithStoreMetadata: storeMetadata)
        } catch {
            return false
        }
    }
}

extension CoreDataService: CoreDataServiceProtocol {
    public func performAsync(block: @escaping CoreDataContextInvocationBlock) {
        lock.lock()

        do {
            if let context = context {
                invoke(block: block, in: context)
            } else {
                let context = try setup()
                invoke(block: block, in: context)
            }

            lock.unlock()
        } catch {
            lock.unlock()

            block(nil, error)
        }
    }

    public func close() throws {
        lock.lock()

        defer {
            lock.unlock()
        }

        context?.performAndWait {
            guard let coordinator = self.context?.persistentStoreCoordinator else {
                return
            }

            for store in coordinator.persistentStores {
                try? coordinator.remove(store)
            }

            self.context = nil
        }
    }

    public func drop() throws {
        lock.lock()

        defer {
            lock.unlock()
        }

        guard context == nil else {
            throw CoreDataServiceError.unexpectedDropWhenOpen
        }

        guard case let .persistent(settings) = configuration.storageType else {
            return
        }

        try removeDatabaseFile(using: FileManager.default, settings: settings)
    }

    private func removeDatabaseFile(
        using fileManager: FileManager,
        settings: CoreDataPersistentSettings
    ) throws {
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(
            atPath: settings.databaseDirectory.path,
            isDirectory: &isDirectory
        ), isDirectory.boolValue {
            try fileManager.removeItem(at: settings.databaseDirectory)
        }
    }
}
