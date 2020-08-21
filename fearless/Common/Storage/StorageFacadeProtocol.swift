import Foundation
import RobinHood
import CoreData

protocol StorageFacadeProtocol: class {
    var databaseService: CoreDataServiceProtocol { get }

    func createRepository<T, U>(filter: NSPredicate?, mapper: AnyCoreDataMapper<T, U>) -> CoreDataRepository<T, U>
        where T: Identifiable & Codable, U: NSManagedObject
}

extension StorageFacadeProtocol {
    func createRepository<T, U>(mapper: AnyCoreDataMapper<T, U>) -> CoreDataRepository<T, U>
    where T: Identifiable & Codable, U: NSManagedObject {
        return createRepository(filter: nil, mapper: mapper)
    }

    func createRepository<T, U>() -> CoreDataRepository<T, U>
    where T: Identifiable & Codable, U: NSManagedObject & CoreDataCodable {
        let mapper = AnyCoreDataMapper(CodableCoreDataMapper<T, U>())
        return createRepository(filter: nil, mapper: mapper)
    }
}
