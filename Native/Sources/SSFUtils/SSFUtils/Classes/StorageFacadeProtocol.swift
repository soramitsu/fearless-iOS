import CoreData
import Foundation
import RobinHood

public protocol StorageFacadeProtocol: AnyObject {
    var databaseService: CoreDataServiceProtocol { get }

    func createRepository<T, U>(
        filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor],
        mapper: AnyCoreDataMapper<T, U>
    ) -> CoreDataRepository<T, U>
        where T: Identifiable, U: NSManagedObject
}

public extension StorageFacadeProtocol {
    func createRepository<T, U>(
        mapper: AnyCoreDataMapper<T, U>
    ) -> CoreDataRepository<T, U> where T: Identifiable, U: NSManagedObject {
        createRepository(filter: nil, sortDescriptors: [], mapper: mapper)
    }

    func createRepository<T, U>()
        -> CoreDataRepository<T, U> where T: Identifiable & Codable,
        U: NSManagedObject & CoreDataCodable
    {
        let mapper = AnyCoreDataMapper(CodableCoreDataMapper<T, U>())
        return createRepository(filter: nil, sortDescriptors: [], mapper: mapper)
    }

    func createRepository<T, U>(
        filter: NSPredicate
    ) -> CoreDataRepository<T, U> where T: Identifiable & Codable,
        U: NSManagedObject & CoreDataCodable
    {
        let mapper = AnyCoreDataMapper(CodableCoreDataMapper<T, U>())
        return createRepository(filter: filter, sortDescriptors: [], mapper: mapper)
    }

    func createRepository<T, U>(
        sortDescriptors: [NSSortDescriptor]
    ) -> CoreDataRepository<T, U> where T: Identifiable & Codable,
        U: NSManagedObject & CoreDataCodable
    {
        let mapper = AnyCoreDataMapper(CodableCoreDataMapper<T, U>())
        return createRepository(filter: nil, sortDescriptors: sortDescriptors, mapper: mapper)
    }

    func createRepository<T, U>(
        filter: NSPredicate,
        sortDescriptors: [NSSortDescriptor]
    ) -> CoreDataRepository<T, U> where T: Identifiable & Codable,
        U: NSManagedObject & CoreDataCodable
    {
        let mapper = AnyCoreDataMapper(CodableCoreDataMapper<T, U>())
        return createRepository(filter: filter, sortDescriptors: sortDescriptors, mapper: mapper)
    }
}
