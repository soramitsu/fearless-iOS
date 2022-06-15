import Foundation
import RobinHood
import CoreData

enum AssetModelMapperError: Error {
    case requiredFieldsMissing
}

final class AssetModelMapper: CoreDataMapperProtocol {
    var entityIdentifierFieldName: String { "id" }

    func transform(entity: CDAsset) throws -> AssetModel {
        guard
            let id = entity.id,
            let chainId = entity.chainId,
            let symbol = entity.symbol,
            let typeRawValue = entity.type,
            let type = ChainAssetType(rawValue: typeRawValue)
        else {
            throw AssetModelMapperError.requiredFieldsMissing
        }

        return AssetModel(
            id: id,
            symbol: symbol,
            chainId: chainId,
            precision: UInt16(entity.precision),
            icon: entity.icon,
            priceId: entity.priceId,
            price: entity.price as Decimal?,
            transfersEnabled: entity.transfersEnabled,
            type: type,
            currencyId: entity.currencyId,
            displayName: entity.displayName,
            existentialDeposit: entity.existentialDeposit
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
        entity.symbol = model.symbol
        entity.transfersEnabled = model.transfersEnabled ?? true
        entity.type = model.type.rawValue
        entity.currencyId = model.currencyId
        entity.existentialDeposit = model.existentialDeposit
    }
}
