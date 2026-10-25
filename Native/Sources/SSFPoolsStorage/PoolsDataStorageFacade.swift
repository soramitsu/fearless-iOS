import CoreData
import RobinHood
import SSFUtils

enum PoolsDataStorageFacadeError: Error {
    case unexpectedError
}

enum PoolsDataStorageParams {
    static let modelName = "PoolsDataModel"
    static let modelDirectory: String = "PoolsDataModel.momd"
    static let databaseName = "PoolsDataModel.sqlite"
    public static let momURL = Bundle.module.url(
        forResource: "PoolsDataModel",
        withExtension: "momd"
    )

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

public final class PoolsDataStorageFacade: StorageFacadeProtocol {
    public let databaseService: CoreDataServiceProtocol

    public init() throws {
        guard let modelURL = Self.createModelURL() else {
            throw PoolsDataStorageFacadeError.unexpectedError
        }

        let persistentSettings = CoreDataPersistentSettings(
            databaseDirectory: PoolsDataStorageParams.storageDirectoryURL,
            databaseName: PoolsDataStorageParams.databaseName,
            incompatibleModelStrategy: .removeStore
        )

        let configuration = CoreDataServiceConfiguration(
            modelURL: modelURL,
            storageType: .persistent(settings: persistentSettings)
        )

        databaseService = CoreDataService(configuration: configuration)
    }

    public func createRepository<T, U>(
        filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor],
        mapper: AnyCoreDataMapper<T, U>
    ) -> CoreDataRepository<T, U>
        where T: Identifiable, U: NSManagedObject
    {
        CoreDataRepository(
            databaseService: databaseService,
            mapper: mapper,
            filter: filter,
            sortDescriptors: sortDescriptors
        )
    }

    private static func createModelURL() -> URL? {
        let bundle = Bundle(for: PoolsDataStorageFacade.self)

        let omoURL = bundle.url(
            forResource: PoolsDataStorageParams.modelName,
            withExtension: "omo",
            subdirectory: PoolsDataStorageParams.modelDirectory
        )

        let momURL = bundle.url(
            forResource: PoolsDataStorageParams.modelName,
            withExtension: "mom",
            subdirectory: PoolsDataStorageParams.modelDirectory
        )

        return omoURL ?? momURL
    }
}
