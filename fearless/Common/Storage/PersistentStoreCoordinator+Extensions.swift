import Foundation
import CoreData

extension NSPersistentStoreCoordinator {
    static func destroyStore(at storeURL: URL) throws {
        let persistentStoreCoordinator = NSPersistentStoreCoordinator(
            managedObjectModel: NSManagedObjectModel()
        )

        try persistentStoreCoordinator.destroyPersistentStore(
            at: storeURL,
            ofType: NSSQLiteStoreType,
            options: nil
        )
    }

    static func replaceStore(at targetURL: URL, withStoreAt sourceURL: URL) throws {
        let persistentStoreCoordinator = NSPersistentStoreCoordinator(
            managedObjectModel: NSManagedObjectModel()
        )

        try persistentStoreCoordinator.replacePersistentStore(
            at: targetURL,
            destinationOptions: nil,
            withPersistentStoreFrom: sourceURL,
            sourceOptions: nil,
            ofType: NSSQLiteStoreType
        )
    }

    static func metadata(at storeURL: URL) -> [String: Any]? {
        try? NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType,
            at: storeURL,
            options: nil
        )
    }

    func addPersistentStore(at storeURL: URL, options: [AnyHashable: Any]) throws -> NSPersistentStore {
        try addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: options
        )
    }
}
