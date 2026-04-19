import Foundation
#if canImport(SSFAssetManagmentStorage)
    import SSFAssetManagmentStorage
#endif
import CoreData
import RobinHood
import SSFModels
import SSFUtils

enum AssetModelMapperError: Error {
    case missedRequiredFields
}

extension AssetModel: RobinHood.Identifiable {
    public var identifier: String { id }
}

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
}

extension AssetModelMapper: CoreDataMapperProtocol {
    typealias DataProviderModel = AssetModel
    typealias CoreDataEntity = CDAsset

    // Avoid #keyPath ambiguity with Identifiable.id in Swift 6
    var entityIdentifierFieldName: String { "id" }

    func transform(entity: CDAsset) throws -> AssetModel {
        guard let id = entity.id else {
            throw AssetModelMapperError.missedRequiredFields
        }

        let symbol = entity.symbol ?? id
        let name = entity.name ?? symbol

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

        let price: Decimal? = {
            guard entity.entity.propertiesByName["price"] != nil else {
                return nil
            }
            if let value = entity.value(forKey: "price") as? NSDecimalNumber {
                return value.decimalValue
            }
            if let value = entity.value(forKey: "price") as? Decimal {
                return value
            }
            return nil
        }()

        let fiatDayChange: Decimal? = {
            guard entity.entity.propertiesByName["fiatDayChange"] != nil else {
                return nil
            }
            if let value = entity.value(forKey: "fiatDayChange") as? NSDecimalNumber {
                return value.decimalValue
            }
            if let value = entity.value(forKey: "fiatDayChange") as? Decimal {
                return value
            }
            return nil
        }()

        return AssetModel(
            id: id,
            name: name,
            symbol: symbol,
            precision: UInt16(bitPattern: entity.precision),
            icon: entity.icon,
            price: price,
            fiatDayChange: fiatDayChange,
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
            coingeckoPriceId: entity.priceId
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
        entity.type = model.type?.rawValue
        entity.isUtility = model.isUtility
        entity.isNative = model.isNative
        entity.staking = model.staking?.rawValue
        entity.ethereumType = model.ethereumType?.rawValue
        if entity.entity.propertiesByName["price"] != nil {
            entity.setValue(model.price as NSDecimalNumber?, forKey: "price")
        }
        if entity.entity.propertiesByName["fiatDayChange"] != nil {
            entity.setValue(model.fiatDayChange as NSDecimalNumber?, forKey: "fiatDayChange")
        }

        let priceProviderContext = CDPriceProvider(context: context)
        priceProviderContext.type = model.priceProvider?.type.rawValue
        priceProviderContext.id = model.priceProvider?.id
        if let precision = model.priceProvider?.precision {
            priceProviderContext.precision = "\(precision)"
        }
        entity.priceProvider = priceProviderContext

        let purchaseProviders: [String]? = model.purchaseProviders?.map(\.rawValue)
        entity.purchaseProviders = purchaseProviders
    }
}
