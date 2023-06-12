import Foundation
import RobinHood
import CoreData
import SSFModels

enum AssetModelMapperError: Error {
    case requiredFieldsMissing
}

final class AssetModelMapper: CoreDataMapperProtocol {
    var entityIdentifierFieldName: String { "id" }

    func transform(entity: CDAsset) throws -> AssetModel {
        guard
            let id = entity.id,
            let symbol = entity.symbol,
            let name = entity.name
        else {
            throw AssetModelMapperError.requiredFieldsMissing
        }

        let staking: StakingType?
        if let entityStaking = entity.staking {
            staking = StakingType(rawValue: entityStaking)
        } else {
            staking = nil
        }
        let purchaseProviders: [PurchaseProvider]? = entity.purchaseProviders?.compactMap {
            PurchaseProvider(rawValue: $0)
        }

        return AssetModel(
            id: id,
            name: name,
            symbol: symbol,
            precision: UInt16(entity.precision),
            icon: entity.icon,
            priceId: entity.priceId,
            price: entity.price as Decimal?,
            fiatDayChange: entity.fiatDayChange as Decimal?,
            currencyId: entity.currencyId,
            existentialDeposit: entity.existentialDeposit,
            color: entity.color,
            isUtility: entity.isUtility,
            isNative: entity.isNative,
            staking: staking,
            purchaseProviders: purchaseProviders,
            type: createChainAssetModelType(from: entity.type),
            smartContract: entity.smartContract
        )
    }

    func populate(
        entity: CDAsset,
        from model: AssetModel,
        using _: NSManagedObjectContext
    ) throws {
        entity.id = model.id
        entity.precision = Int16(model.precision)
        entity.icon = model.icon
        entity.priceId = model.priceId
        entity.price = model.price as NSDecimalNumber?
        entity.fiatDayChange = model.fiatDayChange as NSDecimalNumber?
        entity.symbol = model.symbol
        entity.existentialDeposit = model.existentialDeposit
        entity.color = model.color
        entity.smartContract = model.smartContract
    }

    private func createChainAssetModelType(from rawValue: String?) -> ChainAssetType {
        guard let rawValue = rawValue else {
            return .normal
        }
        return ChainAssetType(rawValue: rawValue) ?? .normal
    }
}
