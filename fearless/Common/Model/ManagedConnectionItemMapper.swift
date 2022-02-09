import Foundation
import RobinHood
import CoreData
import IrohaCrypto

enum ManagedConnectionItemMapperError: Error {
    case invalidEntity
}

// TODO: Fix logic
final class ManagedConnectionItemMapper: CoreDataMapperProtocol {
    typealias DataProviderModel = ManagedConnectionItem
    typealias CoreDataEntity = CDChain

    var entityIdentifierFieldName: String {
        #keyPath(CoreDataEntity.chainId)
    }

    func populate(
        entity _: CDChain,
        from _: DataProviderModel,
        using _: NSManagedObjectContext
    ) throws {}

    func transform(entity: CDChain) throws -> DataProviderModel {
        guard
            let identifier = entity.chainId,
            let url = URL(string: identifier),
            let title = entity.name,
            let networkType = SNAddressType(rawValue: UInt8(entity.addressPrefix))
        else {
            throw ManagedAccountItemMapperError.invalidEntity
        }

        return ManagedConnectionItem(
            title: title,
            url: url,
            type: networkType,
            order: 0
        )
    }
}
