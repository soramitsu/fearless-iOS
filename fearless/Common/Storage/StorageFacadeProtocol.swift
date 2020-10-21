import Foundation
import RobinHood
import CoreData

protocol StorageFacadeProtocol: class {
    var databaseService: CoreDataServiceProtocol { get }

    func createRepository<T, U>(filter: NSPredicate?,
                                sortDescriptors: [NSSortDescriptor],
                                mapper: AnyCoreDataMapper<T, U>) -> CoreDataRepository<T, U>
        where T: Identifiable, U: NSManagedObject
}

extension StorageFacadeProtocol {
    func createRepository<T, U>(mapper: AnyCoreDataMapper<T, U>) -> CoreDataRepository<T, U>
    where T: Identifiable, U: NSManagedObject {
        return createRepository(filter: nil, sortDescriptors: [], mapper: mapper)
    }

    func createRepository<T, U>() -> CoreDataRepository<T, U>
    where T: Identifiable & Codable, U: NSManagedObject & CoreDataCodable {
        let mapper = AnyCoreDataMapper(CodableCoreDataMapper<T, U>())
        return createRepository(filter: nil, sortDescriptors: [], mapper: mapper)
    }

    func createRepository<T, U>(filter: NSPredicate) -> CoreDataRepository<T, U>
    where T: Identifiable & Codable, U: NSManagedObject & CoreDataCodable {
        let mapper = AnyCoreDataMapper(CodableCoreDataMapper<T, U>())
        return createRepository(filter: filter, sortDescriptors: [], mapper: mapper)
    }

    func createRepository<T, U>(sortDescriptors: [NSSortDescriptor]) -> CoreDataRepository<T, U>
    where T: Identifiable & Codable, U: NSManagedObject & CoreDataCodable {
        let mapper = AnyCoreDataMapper(CodableCoreDataMapper<T, U>())
        return createRepository(filter: nil, sortDescriptors: sortDescriptors, mapper: mapper)
    }

    func createRepository<T, U>(filter: NSPredicate, sortDescriptors: [NSSortDescriptor])
        -> CoreDataRepository<T, U>
        where T: Identifiable & Codable, U: NSManagedObject & CoreDataCodable {
        let mapper = AnyCoreDataMapper(CodableCoreDataMapper<T, U>())
        return createRepository(filter: filter, sortDescriptors: sortDescriptors, mapper: mapper)
    }
}
