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

        let staking: RawStakingType?
        if let entityStaking = entity.staking {
            staking = RawStakingType(rawValue: entityStaking)
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
            ethereumType: createEthereumAssetType(from: entity.ethereumType)
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
        entity.ethereumType = model.ethereumType?.rawValue
        entity.type = model.type?.rawValue
        entity.ethereumType = model.ethereumType?.rawValue
    }

    private func createChainAssetModelType(from rawValue: String?) -> SubstrateAssetType? {
        guard let rawValue = rawValue else {
            return nil
        }
        return SubstrateAssetType(rawValue: rawValue)
    }

    private func createEthereumAssetType(from rawValue: String?) -> EthereumAssetType? {
        guard let rawValue = rawValue else {
            return nil
        }
        return EthereumAssetType(rawValue: rawValue)
    }
}
