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
            let symbol = entity.symbol
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
            fiatDayChange: entity.fiatDayChange as Decimal?,
            transfersEnabled: entity.transfersEnabled,
            currencyId: entity.currencyId,
            displayName: entity.displayName,
            existentialDeposit: entity.existentialDeposit,
            color: entity.color
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
        entity.fiatDayChange = model.fiatDayChange as NSDecimalNumber?
        entity.symbol = model.symbol
        entity.transfersEnabled = model.transfersEnabled
        entity.currencyId = model.currencyId
        entity.existentialDeposit = model.existentialDeposit
        entity.color = model.color
    }
}
