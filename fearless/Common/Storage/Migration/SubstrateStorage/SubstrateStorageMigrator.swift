import Foundation
import CoreData
import SoraKeystore

final class SubstrateStorageMigrator {
    let storeURL: URL
    let modelDirectory: String
    let fileManager: FileManager
    let targetVersion: SubstrateStorageVersion

    init(
        targetVersion: SubstrateStorageVersion,
        storeURL: URL,
        modelDirectory: String,
        fileManager: FileManager
    ) {
        self.targetVersion = targetVersion
        self.storeURL = storeURL
        self.modelDirectory = modelDirectory
        self.fileManager = fileManager
    }

    func performMigration() {
        forceWALCheckpointingForStore(at: storeURL)

        let maybeMetadata = try? NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType,
            at: storeURL,
            options: nil
        )

        guard
            let metadata = maybeMetadata,
            let sourceVersion = compatibleVersionForStoreMetadata(metadata) else {
            fatalError("Unknown store version at URL \(storeURL)")
        }

        do {
            let migrationDirName = UUID().uuidString
            let tmpMigrationDirURL = URL(
                fileURLWithPath: NSTemporaryDirectory(),
                isDirectory: true
            ).appendingPathComponent(migrationDirName)

            try fileManager.createDirectory(at: tmpMigrationDirURL, withIntermediateDirectories: true)

            try performMigration(
                from: sourceVersion,
                to: targetVersion,
                storeURL: storeURL,
                tmpMigrationDirURL: tmpMigrationDirURL
            )

            try fileManager.removeItem(at: tmpMigrationDirURL)
        } catch {
            fatalError("Migration failed with error \(error)")
        }
    }

    private func performMigration(
        from sourceVersion: SubstrateStorageVersion,
        to destinationVersion: SubstrateStorageVersion,
        storeURL: URL,
        tmpMigrationDirURL: URL
    ) throws {
        var currentVersion = sourceVersion
        var currentURL = storeURL

        while currentVersion != destinationVersion, let nextVersion = currentVersion.nextVersion() {
            let currentModel = createManagedObjectModel(forResource: currentVersion.rawValue)
            let nextModel = createManagedObjectModel(forResource: nextVersion.rawValue)

            let mapping = try createMapping(from: currentModel, nextModel: nextModel)

            let manager = NSMigrationManager(sourceModel: currentModel, destinationModel: nextModel)

            let nextStepURL = tmpMigrationDirURL.appendingPathComponent(UUID().uuidString)

            try manager.migrateStore(
                from: currentURL,
                sourceType: NSSQLiteStoreType,
                options: nil,
                with: mapping,
                toDestinationURL: nextStepURL,
                destinationType: NSSQLiteStoreType,
                destinationOptions: nil
            )

            if currentURL != storeURL {
                try NSPersistentStoreCoordinator.destroyStore(at: currentURL)
            }

            currentVersion = nextVersion
            currentURL = nextStepURL
        }

        try NSPersistentStoreCoordinator.replaceStore(at: storeURL, withStoreAt: currentURL)

        if currentURL != storeURL {
            try NSPersistentStoreCoordinator.destroyStore(at: currentURL)
        }
    }

    private func checkIfMigrationNeeded(to version: SubstrateStorageVersion) -> Bool {
        let storageExists = fileManager.fileExists(atPath: storeURL.path)

        guard storageExists else {
            return false
        }

        guard let metadata = NSPersistentStoreCoordinator.metadata(at: storeURL) else {
            return false
        }

        let compatibleVersion = compatibleVersionForStoreMetadata(metadata)

        return compatibleVersion != version
    }

    private func compatibleVersionForStoreMetadata(_ metadata: [String: Any]) -> SubstrateStorageVersion? {
        let compatibleVersion = SubstrateStorageVersion.allCases.first {
            let model = createManagedObjectModel(forResource: $0.rawValue)
            return model.isConfiguration(withName: $0.rawValue, compatibleWithStoreMetadata: metadata)
        }

        return compatibleVersion
    }

    private func createManagedObjectModel(forResource resource: String) -> NSManagedObjectModel {
        let bundle = Bundle.main

        let omoURL = bundle.url(
            forResource: resource,
            withExtension: "omo",
            subdirectory: modelDirectory
        )

        let momURL = bundle.url(
            forResource: resource,
            withExtension: "mom",
            subdirectory: modelDirectory
        )

        guard
            let modelURL = omoURL ?? momURL,
            let model = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Unable to load model in bundle for resource \(resource)")
        }

        return model
    }

    private func createMapping(
        from sourceModel: NSManagedObjectModel,
        nextModel: NSManagedObjectModel
    ) throws -> NSMappingModel {
        let maybeCustomMapping = NSMappingModel(
            from: [Bundle.main],
            forSourceModel: sourceModel,
            destinationModel: nextModel
        )

        if let customMapping = maybeCustomMapping {
            return customMapping
        }

        return try NSMappingModel.inferredMappingModel(
            forSourceModel: sourceModel,
            destinationModel: nextModel
        )
    }

    private func forceWALCheckpointingForStore(at storeURL: URL) {
        let maybeMetadata = try? NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType,
            at: storeURL,
            options: nil
        )

        guard
            let metadata = maybeMetadata,
            let currentModel = NSManagedObjectModel.mergedModel(
                from: [Bundle.main],
                forStoreMetadata: metadata
            ) else {
            return
        }

        do {
            let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: currentModel)

            let options = [NSSQLitePragmasOption: ["journal_mode": "DELETE"]]
            let store = try persistentStoreCoordinator.addPersistentStore(at: storeURL, options: options)
            try persistentStoreCoordinator.remove(store)
        } catch {
            fatalError("Failed to force WAL checkpointing, error: \(error)")
        }
    }
}

extension SubstrateStorageMigrator: StorageMigrating {
    func requiresMigration() -> Bool {
        checkIfMigrationNeeded(to: targetVersion)
    }

    func migrate(_ completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.performMigration()

            DispatchQueue.main.async {
                completion()
            }
        }
    }
}
