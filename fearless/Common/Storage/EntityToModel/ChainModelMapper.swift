import Foundation
import CoreData
import RobinHood
import SSFModels

final class ChainModelMapper {
    var entityIdentifierFieldName: String { #keyPath(CDChain.chainId) }

    typealias DataProviderModel = ChainModel
    typealias CoreDataEntity = CDChain

    // TODO: replace precondition failure to optional
    private func createAsset(from entity: CDAsset) -> AssetModel {
        var symbol: String?

        if let entitySymbol = entity.symbol {
            symbol = entitySymbol
        } else {
            symbol = entity.id
        }
        guard
            let id = entity.id,
            let chainId = entity.chainId,
            let symbol = symbol
        else {
            preconditionFailure()
        }

        return AssetModel(
            id: id,
            symbol: symbol,
            chainId: chainId,
            precision: UInt16(bitPattern: entity.precision),
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

    private func createChainAsset(from entity: CDChainAsset, parentChain: ChainModel) -> ChainAssetModel {
        guard let assetId = entity.assetId,
              let asset = entity.asset else {
            preconditionFailure()
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
        return ChainAssetModel(
            assetId: assetId,
            staking: staking,
            purchaseProviders: purchaseProviders,
            type: createChainAssetModelType(from: entity.type),
            asset: createAsset(from: asset),
            chain: parentChain,
            isUtility: entity.isUtility,
            isNative: entity.isNative
        )
    }

    private func createChainNode(from entity: CDChainNode) -> ChainNodeModel {
        let apiKey: ChainNodeModel.ApiKey?

        if let queryName = entity.apiQueryName, let keyName = entity.apiKeyName {
            apiKey = ChainNodeModel.ApiKey(queryName: queryName, keyName: keyName)
        } else {
            apiKey = nil
        }

        return ChainNodeModel(
            url: entity.url!,
            name: entity.name!,
            apikey: apiKey
        )
    }

    private func updateEntityChainAssets(
        for entity: CDChain,
        from model: ChainModel,
        context: NSManagedObjectContext
    ) {
        let assetEntities: [CDChainAsset] = model.assets.map { asset in
            let assetEntity: CDChainAsset

            let maybeExistingEntity = entity.assets?
                .first { ($0 as? CDChainAsset)?.assetId == asset.assetId } as? CDChainAsset

            if let existingEntity = maybeExistingEntity {
                assetEntity = existingEntity
            } else {
                assetEntity = CDChainAsset(context: context)
            }

            let purchaseProviders: [String]? = asset.purchaseProviders?.map(\.rawValue)

            assetEntity.assetId = asset.assetId
            assetEntity.purchaseProviders = purchaseProviders
            assetEntity.staking = asset.staking?.rawValue
            assetEntity.type = asset.type.rawValue
            assetEntity.isUtility = asset.isUtility
            assetEntity.isNative = asset.isNative

            updateEntityAsset(
                for: assetEntity,
                from: asset,
                context: context
            )

            return assetEntity
        }

        let existingAssetIds = Set(model.assets.map(\.assetId))

        if let oldAssets = entity.assets as? Set<CDChainAsset> {
            for oldAsset in oldAssets {
                if let oldAssetId = oldAsset.assetId {
                    if !existingAssetIds.contains(oldAssetId) {
                        context.delete(oldAsset)
                    }
                }
            }
        }

        entity.assets = Set(assetEntities) as NSSet
    }

    private func updateEntityAsset(
        for entity: CDChainAsset,
        from model: ChainAssetModel,
        context: NSManagedObjectContext
    ) {
        if let oldAsset = entity.asset {
            context.delete(oldAsset)
        }

        let assetEntity = CDAsset(context: context)
        assetEntity.id = model.asset.id
        assetEntity.chainId = model.asset.chainId
        assetEntity.icon = model.asset.icon
        assetEntity.precision = Int16(bitPattern: model.asset.precision)
        assetEntity.priceId = model.asset.priceId
        assetEntity.price = model.asset.price as NSDecimalNumber?
        assetEntity.fiatDayChange = model.asset.fiatDayChange as NSDecimalNumber?
        assetEntity.symbol = model.asset.symbol
        assetEntity.transfersEnabled = model.asset.transfersEnabled
        assetEntity.currencyId = model.asset.currencyId
        assetEntity.displayName = model.asset.displayName
        assetEntity.existentialDeposit = model.asset.existentialDeposit
        assetEntity.color = model.asset.color

        entity.asset = assetEntity
    }

    private func updateEntityNodes(
        for entity: CDChain,
        from model: ChainModel,
        context: NSManagedObjectContext
    ) {
        let nodeEntities: [CDChainNode] = model.nodes.map { node in
            let nodeEntity: CDChainNode

            let maybeExistingEntity = entity.nodes?
                .first { ($0 as? CDChainNode)?.url == node.url } as? CDChainNode

            if let existingEntity = maybeExistingEntity {
                nodeEntity = existingEntity
            } else {
                nodeEntity = CDChainNode(context: context)
            }

            nodeEntity.url = node.url
            nodeEntity.name = node.name
            nodeEntity.apiQueryName = node.apikey?.queryName
            nodeEntity.apiKeyName = node.apikey?.keyName

            return nodeEntity
        }

        let existingNodeIds = Set(model.nodes.map(\.url))

        if let oldNodes = entity.nodes as? Set<CDChainNode> {
            for oldNode in oldNodes {
                if !existingNodeIds.contains(oldNode.url!) {
                    context.delete(oldNode)
                }
            }
        }

        entity.nodes = Set(nodeEntities) as NSSet
    }

    private func updateEntityCustomNodes(
        for entity: CDChain,
        from model: ChainModel,
        context: NSManagedObjectContext
    ) {
        guard let customNodes = model.customNodes else {
            return
        }

        let nodeEntities: [CDChainNode] = customNodes.map { node in
            let nodeEntity: CDChainNode

            let maybeExistingEntity = entity.customNodes?
                .first { ($0 as? CDChainNode)?.url == node.url } as? CDChainNode

            if let existingEntity = maybeExistingEntity {
                nodeEntity = existingEntity
            } else {
                nodeEntity = CDChainNode(context: context)
            }

            nodeEntity.url = node.url
            nodeEntity.name = node.name
            nodeEntity.apiQueryName = node.apikey?.queryName
            nodeEntity.apiKeyName = node.apikey?.keyName

            return nodeEntity
        }

        let existingNodeIds = Set(customNodes.map(\.url))

        if let oldNodes = entity.customNodes as? Set<CDChainNode> {
            for oldNode in oldNodes {
                if !existingNodeIds.contains(oldNode.url!) {
                    context.delete(oldNode)
                }
            }
        }

        entity.customNodes = Set(nodeEntities) as NSSet
    }

    private func updateEntitySelectedNode(
        for entity: CDChain,
        from model: ChainModel,
        context: NSManagedObjectContext
    ) {
        guard let node = model.selectedNode else {
            entity.selectedNode = nil
            return
        }
        let nodeEntity: CDChainNode

        var allNodes = NSSet()

        if let nodes = entity.nodes {
            allNodes = allNodes.addingObjects(from: Set(_immutableCocoaSet: nodes)) as NSSet
        }

        if let customNodes = entity.customNodes {
            allNodes = allNodes.addingObjects(from: Set(_immutableCocoaSet: customNodes)) as NSSet
        }

        let maybeExistingEntity = allNodes
            .first { ($0 as? CDChainNode)?.url == node.url } as? CDChainNode

        if let existingEntity = maybeExistingEntity {
            nodeEntity = existingEntity
        } else {
            nodeEntity = CDChainNode(context: context)
        }

        nodeEntity.url = node.url
        nodeEntity.name = node.name
        nodeEntity.apiQueryName = node.apikey?.queryName
        nodeEntity.apiKeyName = node.apikey?.keyName

        entity.selectedNode = nodeEntity
    }

    private func createExternalApi(from entity: CDChain) -> ChainModel.ExternalApiSet? {
        var staking: ChainModel.BlockExplorer?
        if let type = entity.stakingApiType, let url = entity.stakingApiUrl {
            staking = ChainModel.BlockExplorer(type: type, url: url)
        }

        var history: ChainModel.BlockExplorer?
        if let type = entity.historyApiType, let url = entity.historyApiUrl {
            history = ChainModel.BlockExplorer(type: type, url: url)
        }

        var crowdloans: ChainModel.ExternalResource?
        if let type = entity.crowdloansApiType, let url = entity.crowdloansApiUrl {
            crowdloans = ChainModel.ExternalResource(type: type, url: url)
        }

        let explorers = createExplorers(from: entity)

        if staking != nil || history != nil || crowdloans != nil || explorers != nil {
            return ChainModel.ExternalApiSet(staking: staking, history: history, crowdloans: crowdloans, explorers: explorers)
        } else {
            return nil
        }
    }

    private func createXcmConfig(from entity: CDChain) -> XcmChain? {
        guard let versionRaw = entity.xcmConfig?.xcmVersion else {
            return nil
        }

        let version = XcmCallFactoryVersion(rawValue: versionRaw)
        let assets = entity.xcmConfig?.availableAssets as? [String] ?? []
        let destinationEntities = entity.xcmConfig?.availableDestinations?.allObjects as? [CDXcmAvailableDestination] ?? []
        let destinations: [XcmAvailableDestination] = destinationEntities.compactMap {
            guard let chainId = $0.chainId, let assets = $0.assets else {
                return nil
            }

            return XcmAvailableDestination(
                chainId: chainId,
                assets: assets
            )
        }

        return XcmChain(
            xcmVersion: version,
            availableAssets: assets,
            availableDestinations: destinations
        )
    }

    private func createExplorers(from entity: CDChain) -> [ChainModel.ExternalApiExplorer]? {
        let explorers: [ChainModel.ExternalApiExplorer]? = entity.explorers?.compactMap {
            guard let explorer = $0 as? CDExternalApi,
                  let type = explorer.type,
                  let types = explorer.types as? [String],
                  let url = explorer.url
            else {
                return nil
            }
            let externapApiTypes = types.compactMap {
                ChainModel.SubscanType(rawValue: $0)
            }
            return ChainModel.ExternalApiExplorer(
                type: ChainModel.ExternalApiExplorerType(rawValue: type) ?? .unknown,
                types: externapApiTypes,
                url: url
            )
        }
        return explorers
    }

    private func updateEplorersApis(
        in entity: CDChain,
        from apis: [ChainModel.ExternalApiExplorer]?,
        context: NSManagedObjectContext
    ) {
        guard let apis = apis else {
            return
        }
        let explorers: [CDExternalApi] = apis.map { api in
            let explorer = CDExternalApi(context: context)
            explorer.type = api.type.rawValue
            explorer.types = api.types.compactMap { $0.rawValue } as? NSArray
            explorer.url = api.url
            return explorer
        }
        entity.explorers = Set(explorers) as NSSet
    }

    private func updateExternalApis(in entity: CDChain, from apis: ChainModel.ExternalApiSet?) {
        entity.stakingApiType = apis?.staking?.type.rawValue
        entity.stakingApiUrl = apis?.staking?.url

        entity.historyApiType = apis?.history?.type.rawValue
        entity.historyApiUrl = apis?.history?.url

        entity.crowdloansApiType = apis?.crowdloans?.type
        entity.crowdloansApiUrl = apis?.crowdloans?.url
    }

    private func createChainAssetModelType(from rawValue: String?) -> ChainAssetType {
        guard let rawValue = rawValue else {
            return .normal
        }
        return ChainAssetType(rawValue: rawValue) ?? .normal
    }

    private func updateXcmConfig(
        in entity: CDChain,
        from xcmConfig: XcmChain?,
        context: NSManagedObjectContext
    ) {
        guard let xcmConfig = xcmConfig else {
            return
        }

        let configEntity = CDChainXcmConfig(context: context)
        configEntity.xcmVersion = xcmConfig.xcmVersion?.rawValue
        configEntity.availableAssets = xcmConfig.availableAssets
        let destinationEntities = xcmConfig.availableDestinations.compactMap {
            let destinationEntity = CDXcmAvailableDestination(context: context)
            destinationEntity.chainId = $0.chainId
            destinationEntity.assets = $0.assets
            return destinationEntity
        }
        configEntity.availableDestinations = Set(destinationEntities) as NSSet

        entity.xcmConfig = configEntity
    }
}

extension ChainModelMapper: CoreDataMapperProtocol {
    func transform(entity: CDChain) throws -> ChainModel {
        let nodes: [ChainNodeModel] = entity.nodes?.compactMap { anyNode in
            guard let node = anyNode as? CDChainNode else {
                return nil
            }

            return createChainNode(from: node)
        } ?? []

        let customNodes: [ChainNodeModel]? = entity.customNodes?.compactMap { anyNode in
            guard let node = anyNode as? CDChainNode else {
                return nil
            }

            return createChainNode(from: node)
        }

        var customNodesSet: Set<ChainNodeModel>?
        if let nodes = customNodes {
            customNodesSet = Set(nodes)
        }

        var selectedNode: ChainNodeModel?

        if let selectedNodeEntity = entity.selectedNode {
            selectedNode = createChainNode(from: selectedNodeEntity)
        }

        let types: ChainModel.TypesSettings?

        if let url = entity.types, let overridesCommon = entity.typesOverrideCommon {
            types = .init(url: url, overridesCommon: overridesCommon.boolValue)
        } else {
            types = nil
        }

        let options = entity.options as? [String]

        let externalApiSet = createExternalApi(from: entity)

        let xcm = createXcmConfig(from: entity)

        let chainModel = ChainModel(
            chainId: entity.chainId!,
            parentId: entity.parentId,
            name: entity.name!,
            nodes: Set(nodes),
            addressPrefix: UInt16(bitPattern: entity.addressPrefix),
            types: types,
            icon: entity.icon,
            options: options?.compactMap { ChainOptions(rawValue: $0) },
            externalApi: externalApiSet,
            selectedNode: selectedNode,
            customNodes: customNodesSet,
            iosMinAppVersion: entity.minimalAppVersion,
            xcm: xcm
        )

        let chainAssetsArray: [ChainAssetModel] = entity.assets?.compactMap { anyAsset in
            guard let asset = anyAsset as? CDChainAsset else {
                return nil
            }

            return createChainAsset(from: asset, parentChain: chainModel)
        } ?? []
        let chainAssets = Set(chainAssetsArray)

        chainModel.assets = chainAssets

        return chainModel
    }

    func populate(
        entity: CDChain,
        from model: ChainModel,
        using context: NSManagedObjectContext
    ) throws {
        entity.chainId = model.chainId
        entity.parentId = model.parentId
        entity.name = model.name
        entity.types = model.types?.url
        entity.typesOverrideCommon = model.types.map { NSNumber(value: $0.overridesCommon) }

        entity.addressPrefix = Int16(bitPattern: model.addressPrefix)
        entity.icon = model.icon
        entity.isEthereumBased = model.isEthereumBased
        entity.isTestnet = model.isTestnet
        entity.hasCrowdloans = model.hasCrowdloans
        entity.isTipRequired = model.isTipRequired
        entity.minimalAppVersion = model.iosMinAppVersion
        entity.options = model.options?.map(\.rawValue) as? NSArray

        updateEntityChainAssets(for: entity, from: model, context: context)
        updateEntityNodes(for: entity, from: model, context: context)
        updateExternalApis(in: entity, from: model.externalApi)
        updateEntityCustomNodes(for: entity, from: model, context: context)
        updateEntitySelectedNode(for: entity, from: model, context: context)
        updateEplorersApis(in: entity, from: model.externalApi?.explorers, context: context)
        updateXcmConfig(in: entity, from: model.xcm, context: context)
    }
}
