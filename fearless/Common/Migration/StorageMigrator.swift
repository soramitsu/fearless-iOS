import Foundation
import CoreData
import SoraKeystore

protocol StorageMigrating {
    func requiresMigration() -> Bool
    func migrate(_ completion: @escaping () -> Void)
}

enum UserStorageMigratorKeys {
    static let keystoreMigrator = "keystoreMigrator"
    static let settingsMigrator = "settingsMigrator"
}

final class UserStorageMigrator {
    let storageFacade: StorageFacadeProtocol
    let keystore: KeystoreProtocol
    let settings: SettingsManagerProtocol
    let fileManager: FileManager
    let targetVersion: UserStorageVersion

    init(
        targetVersion: UserStorageVersion,
        storageFacade: StorageFacadeProtocol,
        keystore: KeystoreProtocol,
        settings: SettingsManagerProtocol,
        fileManager: FileManager
    ) {
        self.targetVersion = targetVersion
        self.storageFacade = storageFacade
        self.keystore = keystore
        self.settings = settings
        self.fileManager = fileManager
    }

    var storeURL: URL? {
        let storageType = storageFacade.databaseService.configuration.storageType

        switch storageType {
        case let .persistent(settings):
            let storeUrl = settings.databaseDirectory.appendingPathComponent(settings.databaseName)
            return storeUrl
        case .inMemory:
            return nil
        }
    }

    private func performMigration() {
        guard let storeURL = storeURL else {
            return
        }

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
            try performMigration(
                from: sourceVersion,
                to: targetVersion,
                storeURL: storeURL
            )
        } catch {
            fatalError("Migration failed with error \(error)")
        }
    }

    private func performMigration(
        from sourceVersion: UserStorageVersion,
        to destinationVersion: UserStorageVersion,
        storeURL: URL
    ) throws {
        var currentVersion = sourceVersion
        var currentURL = storeURL

        let keystoreMigrator = KeystoreMigrator(
            sourceVersion: sourceVersion,
            destinationVersion: destinationVersion,
            keystore: keystore
        )

        let settingsMigrator = SettingsMigrator(
            sourceVersion: sourceVersion,
            destinationVersion: destinationVersion,
            settings: settings
        )

        while currentVersion != destinationVersion, let nextVersion = currentVersion.nextVersion() {
            let currentModel = createManagedObjectModel(forResource: currentVersion.rawValue)
            let nextModel = createManagedObjectModel(forResource: nextVersion.rawValue)

            try keystoreMigrator.switchVersion()
            try settingsMigrator.switchVersion()

            let mapping = try createMapping(from: currentModel, nextModel: nextModel)

            let manager = NSMigrationManager(sourceModel: currentModel, destinationModel: nextModel)

            var userInfo = manager.userInfo ?? [AnyHashable: Any]()
            userInfo[UserStorageMigratorKeys.keystoreMigrator] = keystoreMigrator
            userInfo[UserStorageMigratorKeys.settingsMigrator] = settingsMigrator

            let nextStepURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                .appendingPathComponent(UUID().uuidString)

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

        try keystoreMigrator.finalize()
        try settingsMigrator.finalize()

        try NSPersistentStoreCoordinator.replaceStore(at: storeURL, withStoreAt: currentURL)

        if currentURL != storeURL {
            try NSPersistentStoreCoordinator.destroyStore(at: currentURL)
        }
    }

    private func checkIfMigrationNeeded(to version: UserStorageVersion) -> Bool {
        guard let storeURL = storeURL, fileManager.fileExists(atPath: storeURL.absoluteString) else {
            return false
        }

        guard let metadata = NSPersistentStoreCoordinator.metadata(at: storeURL) else {
            return false
        }

        let compatibleVersion = compatibleVersionForStoreMetadata(metadata)

        return compatibleVersion != version
    }

    private func compatibleVersionForStoreMetadata(_ metadata: [String: Any]) -> UserStorageVersion? {
        let compatibleVersion = UserStorageVersion.allCases.first {
            let model = createManagedObjectModel(forResource: $0.rawValue)
            return model.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
        }

        return compatibleVersion
    }

    private func createManagedObjectModel(forResource resource: String) -> NSManagedObjectModel {
        let mainBundle = Bundle.main
        let subdirectory = storageFacade.databaseService.configuration.modelURL.lastPathComponent

        let omoURL = mainBundle.url(
            forResource: resource,
            withExtension: "omo",
            subdirectory: subdirectory
        )

        let momURL = mainBundle.url(
            forResource: resource,
            withExtension: "mom",
            subdirectory: subdirectory
        )

        guard let url = omoURL ?? momURL else {
            fatalError("Unable to find model in bundle for resource \(resource)")
        }

        guard let model = NSManagedObjectModel(contentsOf: url) else {
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

extension UserStorageMigrator: StorageMigrating {
    func requiresMigration() -> Bool {
        checkIfMigrationNeeded(to: targetVersion)
    }

    func migrate(_ completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.performMigration()

            DispatchQueue.main.async {
                completion()
            }
        }
    }
}
