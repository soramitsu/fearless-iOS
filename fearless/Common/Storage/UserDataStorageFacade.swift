import Foundation
import RobinHood
import CoreData

class UserDataStorageFacade: StorageFacadeProtocol {
    static let modelVersion: UserStorageVersion = .version2
    static let modelDirectory: String = "UserDataModel.momd"

    static let storageDirectoryURL: URL = {
        let baseURL = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first?.appendingPathComponent("CoreData")

        return baseURL!
    }()

    static let databaseName = "UserDataModel.sqlite"

    static var storageURL: URL {
        storageDirectoryURL.appendingPathComponent(databaseName)
    }

    static let shared = UserDataStorageFacade()

    let databaseService: CoreDataServiceProtocol

    private init() {
        let modelName = Self.modelVersion.rawValue
        let bundle = Bundle.main

        let omoURL = bundle.url(
            forResource: modelName,
            withExtension: "omo",
            subdirectory: Self.modelDirectory
        )

        let momURL = bundle.url(
            forResource: modelName,
            withExtension: "mom",
            subdirectory: Self.modelDirectory
        )

        let modelURL = omoURL ?? momURL

        let persistentSettings = CoreDataPersistentSettings(
            databaseDirectory: Self.storageDirectoryURL,
            databaseName: Self.databaseName,
            incompatibleModelStrategy: .ignore
        )

        let configuration = CoreDataServiceConfiguration(
            modelURL: modelURL!,
            storageType: .persistent(settings: persistentSettings)
        )

        databaseService = CoreDataService(configuration: configuration)
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
}
