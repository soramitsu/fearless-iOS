import RobinHood
import CoreData

enum SubstrateStorageParams {
    static let modelVersion: SubstrateStorageVersion = .version8
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
            databaseName: "\(modelName).sqlite"
        )
    }

    init(
        modelURL: URL?,
        databaseDirectory: URL,
        databaseName: String = SubstrateStorageParams.databaseName
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
            storageType: .persistent(settings: persistentSettings)
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
