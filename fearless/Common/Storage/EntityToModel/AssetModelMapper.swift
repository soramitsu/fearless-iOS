import Foundation
import RobinHood
import CoreData

enum AssetModelMapperError: Error {
    case requiredFieldsMissing
}

class AssetModelMapper: CoreDataMapperProtocol {
    var entityIdentifierFieldName: String { "id" }

    func transform(entity: CDAsset) throws -> AssetModel {
        guard let id = entity.id, let chainId = entity.chainId else {
            throw AssetModelMapperError.requiredFieldsMissing
        }

        return AssetModel(
            id: id,
            chainId: chainId,
            precision: UInt16(entity.precision),
            icon: entity.icon,
            priceId: entity.priceId,
            price: entity.price as Decimal?
        )
    }

    func populate(
        entity: CDAsset,
        from model: AssetModel,
        using _: NSManagedObjectContext
    ) throws {
        entity.id = model.id
        entity.chainId = model.chainId
        entity.precision = Int16(model.precision)
        entity.icon = model.icon
        entity.priceId = model.priceId
        entity.price = model.price as NSDecimalNumber?
    }
}
