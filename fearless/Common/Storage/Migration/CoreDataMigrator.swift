import Foundation
import CoreData

protocol CoreDataMigratorProtocol {
    func requiresMigration(at storeURL: URL, toVersion version: CoreDataMigrationVersion) -> Bool
    func migrateStore(at storeURL: URL, toVersion version: CoreDataMigrationVersion)
}

class CoreDataMigrator: CoreDataMigratorProtocol {
    // MARK: - Check

    func requiresMigration(at storeURL: URL, toVersion version: CoreDataMigrationVersion) -> Bool {
        guard let metadata = NSPersistentStoreCoordinator.metadata(at: storeURL) else {
            return false
        }

        return (CoreDataMigrationVersion.compatibleVersionForStoreMetadata(metadata) != version)
    }

    // MARK: - Migration

    func migrateStore(at storeURL: URL, toVersion version: CoreDataMigrationVersion) {
        forceWALCheckpointingForStore(at: storeURL)

        var currentURL = storeURL
        let migrationSteps = migrationStepsForStore(at: storeURL, toVersion: version)

        for migrationStep in migrationSteps {
            let manager = NSMigrationManager(
                sourceModel: migrationStep.sourceModel,
                destinationModel: migrationStep.destinationModel
            )

            let destinationURL = URL(
                fileURLWithPath: NSTemporaryDirectory(),
                isDirectory: true
            ).appendingPathComponent(UUID().uuidString)

            do {
                try manager.migrateStore(
                    from: currentURL,
                    sourceType: NSSQLiteStoreType,
                    options: nil, with: migrationStep.mappingModel,
                    toDestinationURL: destinationURL,
                    destinationType: NSSQLiteStoreType,
                    destinationOptions: nil
                )
            } catch {
                fatalError("failed attempting to migrate from \(migrationStep.sourceModel) to \(migrationStep.destinationModel), error: \(error)")
            }

            if currentURL != storeURL {
                // Destroy intermediate step's store
                NSPersistentStoreCoordinator.destroyStore(at: currentURL)
            }

            currentURL = destinationURL
        }

        NSPersistentStoreCoordinator.replaceStore(at: storeURL, withStoreAt: currentURL)

        if currentURL != storeURL {
            NSPersistentStoreCoordinator.destroyStore(at: currentURL)
        }
    }

    private func migrationStepsForStore(
        at storeURL: URL,
        toVersion destinationVersion: CoreDataMigrationVersion
    ) -> [CoreDataMigrationStep] {
        guard
            let metadata = NSPersistentStoreCoordinator.metadata(at: storeURL),
            let sourceVersion = CoreDataMigrationVersion.compatibleVersionForStoreMetadata(metadata) else {
            fatalError("unknown store version at URL \(storeURL)")
        }

        return migrationSteps(fromSourceVersion: sourceVersion, toDestinationVersion: destinationVersion)
    }

    private func migrationSteps(
        fromSourceVersion sourceVersion: CoreDataMigrationVersion,
        toDestinationVersion destinationVersion: CoreDataMigrationVersion
    ) -> [CoreDataMigrationStep] {
        var sourceVersion = sourceVersion
        var migrationSteps = [CoreDataMigrationStep]()

        while sourceVersion != destinationVersion, let nextVersion = sourceVersion.nextVersion() {
            let migrationStep = CoreDataMigrationStep(sourceVersion: sourceVersion, destinationVersion: nextVersion)
            migrationSteps.append(migrationStep)

            sourceVersion = nextVersion
        }

        return migrationSteps
    }

    // MARK: - WAL

    func forceWALCheckpointingForStore(at storeURL: URL) {
        guard
            let metadata = NSPersistentStoreCoordinator.metadata(at: storeURL),
            let currentModel = NSManagedObjectModel.compatibleModelForStoreMetadata(metadata) else {
            return
        }

        do {
            let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: currentModel)

            let options = [NSSQLitePragmasOption: ["journal_mode": "DELETE"]]
            let store = persistentStoreCoordinator.addPersistentStore(at: storeURL, options: options)
            try persistentStoreCoordinator.remove(store)
        } catch {
            fatalError("failed to force WAL checkpointing, error: \(error)")
        }
    }
}
