import RobinHood
import CoreData

enum SubstrateStorageParams {
    static let modelVersion: SubstrateStorageVersion = .version10
    static let modelDirectory: String = "SubstrateDataModel.momd"
    static let databaseName = "SubstrateDataModel.sqlite"

    static let storageDirectoryURL: URL = {
        let baseURL = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first?.appendingPathComponent("CoreData")

        return baseURL!
    }()

    static var storageURL: URL {
        storageDirectoryURL.appendingPathComponent(databaseName)
    }
}

/// The last step that keeps a Substrate store problem from stopping startup.
///
/// The Substrate store holds network data and local conveniences, never a
/// wallet or a key. When startup can neither use, migrate nor set aside the
/// installed store, it leaves the store untouched on disk and this launch
/// runs on an in-memory store; the next launch tries the installed store
/// again. It has effect only before `SubstrateDataStorageFacade.shared` is
/// first created, which startup does after its migration steps.
enum SubstrateStoreStartupFallback {
    private static let lock = NSLock()
    private static var inMemoryStoreActive = false

    static var isInMemoryStoreActive: Bool {
        lock.lock()
        defer { lock.unlock() }

        return inMemoryStoreActive
    }

    static func activateInMemoryStore(reason: String) {
        lock.lock()
        let wasActive = inMemoryStoreActive
        inMemoryStoreActive = true
        lock.unlock()

        guard !wasActive else {
            return
        }

        Logger.shared.warning(
            "Substrate store is left untouched on disk; this launch uses an in-memory store (\(reason))"
        )
    }

    #if DEBUG
        /// Tests only: forget an activation so the next test starts clean.
        static func resetForTesting() {
            lock.lock()
            inMemoryStoreActive = false
            lock.unlock()
        }
    #endif
}

class SubstrateDataStorageFacade: StorageFacadeProtocol {
    static let shared = SubstrateDataStorageFacade()

    let databaseService: CoreDataServiceProtocol

    private convenience init() {
        let modelName = "SubstrateDataModel"
        let modelURL = Bundle.main.url(forResource: modelName, withExtension: "momd")

        let baseURL = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first?.appendingPathComponent("CoreData")

        self.init(
            modelURL: modelURL,
            databaseDirectory: baseURL!,
            databaseName: "\(modelName).sqlite",
            inMemory: SubstrateStoreStartupFallback.isInMemoryStoreActive
        )
    }

    init(
        modelURL: URL?,
        databaseDirectory: URL,
        databaseName: String = SubstrateStorageParams.databaseName,
        inMemory: Bool = false
    ) {
        let resolvedModelURL: URL
        if let modelURL {
            resolvedModelURL = modelURL
        } else {
            Logger.shared.error(
                "Required Substrate Core Data model resource is unavailable"
            )
            resolvedModelURL = Bundle.main.bundleURL.appendingPathComponent(
                "__fearless_missing_substrate_model_\(UUID().uuidString).momd"
            )
        }

        let options = [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true
        ]

        let persistentSettings = CoreDataPersistentSettings(
            databaseDirectory: databaseDirectory,
            databaseName: databaseName,
            incompatibleModelStrategy: .ignore,
            options: options
        )

        let configuration = CoreDataServiceConfiguration(
            modelURL: resolvedModelURL,
            storageType: inMemory ? .inMemory : .persistent(settings: persistentSettings)
        )

        databaseService = CoreDataService(configuration: configuration)

        #if DEBUG
            Logger.shared.debug("Substrate Storage URL: \(SubstrateStorageParams.storageURL)")
        #endif
    }

    func createRepository<T, U>(
        filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor],
        mapper: AnyCoreDataMapper<T, U>
    ) -> CoreDataRepository<T, U> where T: Identifiable, U: NSManagedObject {
        CoreDataRepository(
            databaseService: databaseService,
            mapper: mapper,
            filter: filter,
            sortDescriptors: sortDescriptors
        )
    }

    func createAsyncRepository<T, U>(
        filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor],
        mapper: AnyCoreDataMapper<T, U>
    ) -> AsyncCoreDataRepositoryDefault<T, U> where T: Identifiable, U: NSManagedObject {
        AsyncCoreDataRepositoryDefault(
            databaseService: databaseService,
            mapper: mapper,
            filter: filter,
            sortDescriptors: sortDescriptors
        )
    }
}
