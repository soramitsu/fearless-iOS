import Foundation
import SSFAssetManagmentStorage
import CoreData
import RobinHood
import SSFModels
import SSFUtils

final class AssetModelMapper {
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

    private func createPriceData(from object: NSManagedObject) -> PriceData? {
        guard
            let currencyId = object.value(forKey: "currencyId") as? String,
            let priceId = object.value(forKey: "priceId") as? String
        else { return nil }

        let priceString: String? = {
            if let d = object.value(forKey: "price") as? Decimal { return NSDecimalNumber(decimal: d).stringValue }
            if let n = object.value(forKey: "price") as? NSDecimalNumber { return n.stringValue }
            if let s = object.value(forKey: "price") as? String { return s }
            return nil
        }()
        guard let price = priceString else { return nil }

        let fiatDayStr = object.value(forKey: "fiatDayByChange") as? String
        let coingeckoPriceId = object.value(forKey: "coingeckoPriceId") as? String

        return PriceData(
            currencyId: currencyId,
            priceId: priceId,
            price: price,
            fiatDayChange: Decimal(string: fiatDayStr ?? ""),
            coingeckoPriceId: coingeckoPriceId
        )
    }
}

extension AssetModelMapper: CoreDataMapperProtocol {
    // Avoid #keyPath ambiguity with Identifiable.id in Swift 6
    var entityIdentifierFieldName: String { "id" }

    func transform(entity: CDAsset) throws -> AssetModel {
        var symbol: String?
        if let entitySymbol = entity.symbol {
            symbol = entitySymbol
        } else {
            symbol = entity.id
        }

        var name: String?
        if let entityName = entity.name {
            name = entityName
        } else {
            name = entity.symbol
        }

        let staking: SSFModels.RawStakingType?
        if let entityStaking = entity.staking {
            staking = SSFModels.RawStakingType(rawValue: entityStaking)
        } else {
            staking = nil
        }
        let purchaseProviders: [SSFModels.PurchaseProvider]? = entity.purchaseProviders?.compactMap {
            SSFModels.PurchaseProvider(rawValue: $0)
        }

        var priceProvider: PriceProvider?
        if let typeRawValue = entity.priceProvider?.type,
           let type = PriceProviderType(rawValue: typeRawValue),
           let id = entity.priceProvider?.id {
            let precision = entity.priceProvider?.precision ?? ""
            priceProvider = PriceProvider(type: type, id: id, precision: Int16(precision))
        }

        let priceDatas: [PriceData] = {
            if entity.entity.relationshipsByName["priceData"] != nil,
               let set = entity.value(forKey: "priceData") as? NSSet {
                return set.compactMap { $0 as? NSManagedObject }.compactMap { createPriceData(from: $0) }
            } else {
                return []
            }
        }()

        return AssetModel(
            id: entity.id!,
            name: name!,
            symbol: symbol!,
            precision: UInt16(bitPattern: entity.precision),
            icon: entity.icon,
            currencyId: entity.currencyId,
            existentialDeposit: entity.existentialDeposit,
            color: entity.color,
            isUtility: entity.isUtility,
            isNative: entity.isNative,
            staking: staking,
            purchaseProviders: purchaseProviders,
            type: createChainAssetModelType(from: entity.type),
            ethereumType: createEthereumAssetType(from: entity.ethereumType),
            priceProvider: priceProvider,
            coingeckoPriceId: entity.priceId,
            priceData: priceDatas
        )
    }

    func populate(
        entity: CDAsset,
        from model: AssetModel,
        using context: NSManagedObjectContext
    ) throws {
        entity.id = model.id
        entity.icon = model.icon
        entity.precision = Int16(bitPattern: model.precision)
        entity.priceId = model.coingeckoPriceId
        entity.symbol = model.symbol
        entity.existentialDeposit = model.existentialDeposit
        entity.color = model.color
        entity.name = model.name
        entity.currencyId = model.currencyId
        entity.type = model.substrateType?.rawValue
        entity.isUtility = model.isUtility
        entity.isNative = model.isNative
        entity.staking = model.staking?.rawValue
        entity.ethereumType = model.ethereumType?.rawValue

        let priceProviderContext = CDPriceProvider(context: context)
        priceProviderContext.type = model.priceProvider?.type.rawValue
        priceProviderContext.id = model.priceProvider?.id
        if let precision = model.priceProvider?.precision {
            priceProviderContext.precision = "\(precision)"
        }
        entity.priceProvider = priceProviderContext

        let purchaseProviders: [String]? = model.purchaseProviders?.map(\.rawValue)
        entity.purchaseProviders = purchaseProviders

        if entity.entity.relationshipsByName["priceData"] != nil {
            let priceData: [NSManagedObject] = []
            if let oldPrices = entity.value(forKey: "priceData") as? NSSet {
                oldPrices.forEach { any in
                    if let cdPriceData = any as? NSManagedObject,
                       let cid = cdPriceData.value(forKey: "currencyId") as? String,
                       !priceData.contains(where: { ($0.value(forKey: "currencyId") as? String) == cid }) {
                        context.delete(cdPriceData)
                    }
                }
            }
            entity.setValue(Set(priceData) as NSSet, forKey: "priceData")
        }
    }
}
