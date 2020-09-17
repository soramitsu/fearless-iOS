import Foundation
import RobinHood
import CoreData
import IrohaCrypto

enum ManagedConnectionItemMapperError: Error {
    case invalidEntity
}

final class ManagedConnectionItemMapper: CoreDataMapperProtocol {
    typealias DataProviderModel = ManagedConnectionItem
    typealias CoreDataEntity = CDConnectionItem

    var entityIdentifierFieldName: String {
        #keyPath(CoreDataEntity.identifier)
    }

    func populate(entity: CDConnectionItem,
                  from model: DataProviderModel,
                  using context: NSManagedObjectContext) throws {
        entity.identifier = model.url.absoluteString
        entity.title = model.title
        entity.networkType = Int16(model.type.rawValue)
        entity.order = model.order
    }

    func transform(entity: CDConnectionItem) throws -> DataProviderModel {
        guard
            let identifier = entity.identifier,
            let url = URL(string: identifier),
            let title = entity.title,
            let networkType = SNAddressType(rawValue: UInt8(entity.networkType)) else {
            throw ManagedAccountItemMapperError.invalidEntity
        }

        return ManagedConnectionItem(title: title,
                                     url: url,
                                     type: networkType,
                                     order: entity.order)
    }
}
