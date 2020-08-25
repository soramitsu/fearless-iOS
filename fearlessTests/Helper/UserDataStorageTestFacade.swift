import Foundation
@testable import fearless
import RobinHood
import CoreData

class UserDataStorageTestFacade: StorageFacadeProtocol {
    let databaseService: CoreDataServiceProtocol

    init() {
        let modelName = "UserDataModel"
        let modelURL = Bundle.main.url(forResource: modelName, withExtension: "momd")

        let configuration = CoreDataServiceConfiguration(modelURL: modelURL!,
                                                         storageType: .inMemory)

        databaseService = CoreDataService(configuration: configuration)
    }

    func createRepository<T, U>(filter: NSPredicate?, mapper: AnyCoreDataMapper<T, U>)
        -> CoreDataRepository<T, U> where T: Identifiable & Codable, U: NSManagedObject {
            return CoreDataRepository(databaseService: databaseService, mapper: mapper, filter: filter)
    }
}
