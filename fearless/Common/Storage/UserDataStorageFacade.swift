import Foundation
import RobinHood
import CoreData

class UserDataStorageFacade: StorageFacadeProtocol {
    static let shared = UserDataStorageFacade()

    let databaseService: CoreDataServiceProtocol

    private init() {
        let modelName = "UserDataModel"
        let modelURL = Bundle.main.url(forResource: modelName, withExtension: "momd")
        let databaseName = "\(modelName).sqlite"

        let baseURL = FileManager.default.urls(for: .documentDirectory,
                                               in: .userDomainMask).first?.appendingPathComponent("CoreData")

        let persistentSettings = CoreDataPersistentSettings(databaseDirectory: baseURL!,
                                                            databaseName: databaseName,
                                                            incompatibleModelStrategy: .ignore)

        let configuration = CoreDataServiceConfiguration(modelURL: modelURL!,
                                                         storageType: .persistent(settings: persistentSettings))

        databaseService = CoreDataService(configuration: configuration)
    }

    func createRepository<T, U>(filter: NSPredicate?,
                                sortDescriptors: [NSSortDescriptor],
                                mapper: AnyCoreDataMapper<T, U>) -> CoreDataRepository<T, U>
    where T: Identifiable, U: NSManagedObject {
            return CoreDataRepository(databaseService: databaseService,
                                      mapper: mapper, filter: filter,
                                      sortDescriptors: sortDescriptors)
    }
}
