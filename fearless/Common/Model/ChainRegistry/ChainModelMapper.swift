import Foundation
import CoreData
import RobinHood

final class ChainModelMapper {
    var entityIdentifierFieldName: String { #keyPath(CDChain.chainId) }

    typealias DataProviderModel = ChainModel
    typealias CoreDataEntity = CDChain
}

extension ChainModelMapper: CoreDataMapperProtocol {
    func transform(entity: CDChain) throws -> ChainModel {
        let assets: [AssetModel] = entity.assets?.compactMap { anyAsset in
            guard let asset = anyAsset as? CDAsset else {
                return nil
            }

            return AssetModel(
                assetId: UInt32(bitPattern: asset.assetId),
                chainId: entity.chainId!,
                icon: asset.icon,
                name: asset.name!,
                symbol: asset.symbol!,
                precision: UInt16(bitPattern: asset.precision)
            )
        } ?? []

        let nodes: [ChainNodeModel] = entity.nodes?.compactMap { anyNode in
            guard let node = anyNode as? CDChainNode else {
                return nil
            }

            return ChainNodeModel(
                chainId: entity.chainId!,
                url: node.url!,
                name: node.name!
            )
        } ?? []

        let types: ChainModel.TypesSettings?

        if let url = entity.types, let overridesCommon = entity.typesOverrideCommon {
            types = .init(url: url, overridesCommon: overridesCommon.boolValue)
        } else {
            types = nil
        }

        return ChainModel(
            chainId: entity.chainId!,
            assets: assets,
            nodes: nodes,
            addressPrefix: UInt16(bitPattern: entity.addressPrefix),
            types: types,
            icon: entity.icon!,
            isEthereumBased: entity.isEthereumBased
        )
    }

    func populate(entity: CDChain, from model: ChainModel, using context: NSManagedObjectContext) throws {
        entity.chainId = model.chainId
        entity.types = model.types?.url
        entity.typesOverrideCommon = model.types.map { NSNumber(value: $0.overridesCommon) }

        entity.addressPrefix = Int16(bitPattern: model.addressPrefix)
        entity.icon = model.icon
        entity.isEthereumBased = model.isEthereumBased

        model.assets.forEach { asset in
            let assetEntity: CDAsset
            let assetEntityId = Int32(bitPattern: asset.assetId)

            let maybeExistingEntity = entity.assets?
                .first { ($0 as? CDAsset)?.assetId == assetEntityId } as? CDAsset

            if let existingEntity = maybeExistingEntity {
                assetEntity = existingEntity
            } else {
                assetEntity = CDAsset(context: context)
                entity.addToAssets(assetEntity)
            }

            assetEntity.assetId = assetEntityId
            assetEntity.name = asset.name
            assetEntity.precision = Int16(bitPattern: asset.precision)
            assetEntity.icon = asset.icon
            assetEntity.symbol = asset.symbol
        }

        model.nodes.forEach { node in
            let nodeEntity: CDChainNode

            let maybeExistingEntity = entity.nodes?
                .first { ($0 as? CDChainNode)?.url == node.url } as? CDChainNode

            if let existingEntity = maybeExistingEntity {
                nodeEntity = existingEntity
            } else {
                nodeEntity = CDChainNode(context: context)
                entity.addToNodes(nodeEntity)
            }

            nodeEntity.url = node.url
            nodeEntity.name = node.name
        }
    }
}
