import Foundation
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
}

extension AssetModelMapper: CoreDataMapperProtocol {
    var entityIdentifierFieldName: String { #keyPath(CDAsset.priceId) }

    private func createPriceData(from entity: CDPriceData) -> PriceData? {
        guard let currencyId = entity.currencyId,
              let priceId = entity.priceId,
              let price = entity.price else {
            return nil
        }
        return PriceData(
            currencyId: currencyId,
            priceId: priceId,
            price: price,
            fiatDayChange: Decimal(string: entity.fiatDayByChange ?? ""),
            coingeckoPriceId: entity.coingeckoPriceId
        )
    }

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

        let priceDatas: [PriceData] = entity.priceData.or([]).compactMap { data in
            guard let priceData = data as? CDPriceData else {
                return nil
            }
            return createPriceData(from: priceData)
        }

        print("asset mapper create, array: \(priceDatas)")

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
        entity.type = model.type?.rawValue
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

        let priceData: [CDPriceData] = model.priceData.map { priceData in
            let entity = CDPriceData(context: context)
            entity.currencyId = priceData.currencyId
            entity.priceId = priceData.priceId
            entity.price = priceData.price
            entity.fiatDayByChange = String("\(priceData.fiatDayChange)")
            entity.coingeckoPriceId = priceData.coingeckoPriceId
            return entity
        }

        entity.priceData = Set(priceData) as NSSet

        print("asset mapper populate, array: \(priceData)")
    }
}
