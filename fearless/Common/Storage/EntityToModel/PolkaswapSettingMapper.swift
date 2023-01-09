import Foundation
import RobinHood
import CoreData

enum PolkaswapSettingMapperError: Error {
    case requiredFieldsMissing
}

final class PolkaswapSettingMapper {
    var entityIdentifierFieldName: String { #keyPath(CDPolkaswapRemoteSettings.version) }

    typealias DataProviderModel = PolkaswapRemoteSettings
    typealias CoreDataEntity = CDPolkaswapRemoteSettings
}

extension PolkaswapSettingMapper: CoreDataMapperProtocol {
    func transform(entity: CDPolkaswapRemoteSettings) throws -> PolkaswapRemoteSettings {
        guard let version = entity.version,
              let availableSources = entity.availableSources?.compactMap({
                  LiquiditySourceType(rawValue: $0)
              }),
              let forceSmartIds = entity.forceSmartIds,
              let availableDexIdsSet = entity.availableDexIds,
              let xstusdId = entity.xstusdId
        else {
            throw PolkaswapSettingMapperError.requiredFieldsMissing
        }

        let availableDexIds: [PolkaswapDex] = availableDexIdsSet.compactMap { dex -> PolkaswapDex? in
            guard
                let dex = dex as? CDPolkaswapDex,
                let name = dex.name,
                let assetId = dex.assetId
            else {
                return nil
            }

            return PolkaswapDex(
                name: name,
                code: UInt32(dex.code),
                assetId: assetId
            )
        }

        return PolkaswapRemoteSettings(
            version: version,
            availableDexIds: availableDexIds,
            availableSources: availableSources,
            forceSmartIds: forceSmartIds,
            xstusdId: xstusdId
        )
    }

    func populate(
        entity: CDPolkaswapRemoteSettings,
        from model: PolkaswapRemoteSettings,
        using context: NSManagedObjectContext
    ) throws {
        entity.version = model.version
        entity.availableSources = model.availableSources.map { $0.rawValue }
        entity.forceSmartIds = model.forceSmartIds
        entity.xstusdId = model.xstusdId

        let availableDexIds = model.availableDexIds.map {
            let entity = CDPolkaswapDex(context: context)
            entity.name = $0.name
            entity.code = Int32($0.code)
            entity.assetId = $0.assetId

            return entity
        }
        entity.availableDexIds = Set(availableDexIds) as NSSet
    }
}
