import CoreData
import Foundation
import RobinHood
import SSFAssetManagmentStorage
import SSFUtils

@testable import SSFAssetManagment

public final class SubstrateStorageTestFacade: StorageFacadeProtocol {
    public let databaseService: CoreDataServiceProtocol

    public init() {
        let configuration = CoreDataServiceConfiguration(
            modelURL: SubstrateStorageParams.momURL!,
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
