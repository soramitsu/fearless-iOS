import CoreData
import Foundation
import RobinHood
import SSFAccountManagmentStorage
import SSFUtils

@testable import SSFAccountManagment

public final class AccountStorageTestFacade: StorageFacadeProtocol {
    public let databaseService: CoreDataServiceProtocol

    public init() {
        let configuration = CoreDataServiceConfiguration(
            modelURL: UserStorageParams.momURL!,
            storageType: .inMemory
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
}
