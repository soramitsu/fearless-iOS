import Foundation
import CoreData
import RobinHood
import SSFModels
import SSFUtils

final class ChainModelMapper {
    var entityIdentifierFieldName: String { #keyPath(CDChain.chainId) }

    typealias DataProviderModel = ChainModel
    typealias CoreDataEntity = CDChain

    private func createAsset(from entity: CDAsset) -> AssetModel? {
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
        guard
            let id = entity.id,
            let symbol = symbol,
            let name = name
        else {
            return nil
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

        return AssetModel(
            id: id,
            name: name,
            symbol: symbol,
            precision: UInt16(bitPattern: entity.precision),
            icon: entity.icon,
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
            ethereumType: createEthereumAssetType(from: entity.ethereumType),
            priceProvider: priceProvider,
            coingeckoPriceId: entity.priceId
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

    private func updateEntityAsset(
        for entity: CDChain,
        from model: ChainModel,
        context: NSManagedObjectContext
    ) {
        let assets = model.assets.map {
            let assetEntity = CDAsset(context: context)
            assetEntity.id = $0.id
            assetEntity.icon = $0.icon
            assetEntity.precision = Int16(bitPattern: $0.precision)
            assetEntity.priceId = $0.coingeckoPriceId
            assetEntity.price = $0.price as NSDecimalNumber?
            assetEntity.fiatDayChange = $0.fiatDayChange as NSDecimalNumber?
            assetEntity.symbol = $0.symbol
            assetEntity.existentialDeposit = $0.existentialDeposit
            assetEntity.color = $0.color
            assetEntity.name = $0.name
            assetEntity.currencyId = $0.currencyId
            assetEntity.type = $0.type?.rawValue
            assetEntity.isUtility = $0.isUtility
            assetEntity.isNative = $0.isNative
            assetEntity.staking = $0.staking?.rawValue
            assetEntity.ethereumType = $0.ethereumType?.rawValue

            let priceProviderContext = CDPriceProvider(context: context)
            priceProviderContext.type = $0.priceProvider?.type.rawValue
            priceProviderContext.id = $0.priceProvider?.id
            if let precision = $0.priceProvider?.precision {
                priceProviderContext.precision = "\(precision)"
            }
            assetEntity.priceProvider = priceProviderContext

            let purchaseProviders: [String]? = $0.purchaseProviders?.map(\.rawValue)
            assetEntity.purchaseProviders = purchaseProviders

            return assetEntity
        }

        entity.assets = Set(assets) as NSSet
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
        let availableXcmAssets = entity.xcmConfig?.availableAssets?.allObjects as? [CDXcmAvailableAsset] ?? []
        let assets: [XcmAvailableAsset] = availableXcmAssets.compactMap { entity in
            guard let id = entity.id, let symbol = entity.symbol else {
                return nil
            }
            return XcmAvailableAsset(id: id, symbol: symbol, minAmount: nil)
        }
        let availableXcmAssetDestinations = entity.xcmConfig?.availableDestinations?.allObjects as? [CDXcmAvailableDestination] ?? []
        let destinations: [XcmAvailableDestination] = availableXcmAssetDestinations.compactMap {
            guard let chainId = $0.chainId else {
                return nil
            }
            let assetsEntities = $0.assets?.allObjects as? [CDXcmAvailableAsset] ?? []
            let assets: [XcmAvailableAsset] = assetsEntities.compactMap { entity in
                guard let id = entity.id, let symbol = entity.symbol else {
                    return nil
                }
                return XcmAvailableAsset(id: id, symbol: symbol, minAmount: nil)
            }
            return XcmAvailableDestination(
                chainId: chainId,
                bridgeParachainId: $0.bridgeParachainId,
                assets: assets
            )
        }

        return XcmChain(
            xcmVersion: version,
            destWeightIsPrimitive: entity.xcmConfig?.destWeightIsPrimitive,
            availableAssets: assets,
            availableDestinations: destinations
        )
    }

    private func createExplorers(from entity: CDChain) -> [ChainModel.ExternalApiExplorer]? {
        guard let entityExplorers = entity.explorers, !entityExplorers.allObjects.isEmpty else {
            return nil
        }

        let explorers: [ChainModel.ExternalApiExplorer]? = entityExplorers.compactMap {
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

    private func updateXcmConfig(
        in entity: CDChain,
        from xcmConfig: XcmChain?,
        context: NSManagedObjectContext
    ) {
        guard let xcmConfig = xcmConfig else {
            entity.xcmConfig = nil
            return
        }

        let configEntity = CDChainXcmConfig(context: context)
        configEntity.xcmVersion = xcmConfig.xcmVersion?.rawValue
        configEntity.destWeightIsPrimitive = xcmConfig.destWeightIsPrimitive ?? false

        let availableAssets = xcmConfig.availableAssets.map {
            let entity = CDXcmAvailableAsset(context: context)
            entity.id = $0.id
            entity.symbol = $0.symbol
            return entity
        }
        configEntity.availableAssets = Set(availableAssets) as NSSet

        let destinationEntities = xcmConfig.availableDestinations.compactMap {
            let destinationEntity = CDXcmAvailableDestination(context: context)
            destinationEntity.chainId = $0.chainId

            let availableAssets = $0.assets.map {
                let entity = CDXcmAvailableAsset(context: context)
                entity.id = $0.id
                entity.symbol = $0.symbol
                return entity
            }
            destinationEntity.assets = Set(availableAssets) as NSSet
            destinationEntity.bridgeParachainId = $0.bridgeParachainId

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

        var customNodesSet: Set<ChainNodeModel>?
        if let entityCustomNodes = entity.customNodes, !entityCustomNodes.allObjects.isEmpty {
            let customNodes: [ChainNodeModel]? = entityCustomNodes.compactMap { anyNode in
                guard let node = anyNode as? CDChainNode else {
                    return nil
                }

                return createChainNode(from: node)
            }

            if let nodes = customNodes {
                customNodesSet = Set(nodes)
            }
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

        var rank: UInt16?
        if let rankString = entity.rank {
            rank = UInt16(rankString)
        }

        let chainModel = ChainModel(
            rank: rank,
            disabled: entity.disabled,
            chainId: entity.chainId!,
            parentId: entity.parentId,
            paraId: entity.paraId,
            name: entity.name!,
            xcm: xcm, nodes: Set(nodes),
            addressPrefix: UInt16(bitPattern: entity.addressPrefix),
            types: types,
            icon: entity.icon,
            options: options?.compactMap { ChainOptions(rawValue: $0) },
            externalApi: externalApiSet,
            selectedNode: selectedNode,
            customNodes: customNodesSet,
            iosMinAppVersion: entity.minimalAppVersion,
            identityChain: entity.identityChain
        )

        let assetsArray: [AssetModel] = entity.assets.or([]).compactMap { anyAsset in
            guard let asset = anyAsset as? CDAsset else {
                return nil
            }

            return createAsset(from: asset)
        }
        let assets = Set(assetsArray)

        chainModel.assets = assets

        return chainModel
    }

    func populate(
        entity: CDChain,
        from model: ChainModel,
        using context: NSManagedObjectContext
    ) throws {
        if let rank = model.rank {
            entity.rank = "\(rank)"
        }
        entity.disabled = model.disabled
        entity.chainId = model.chainId
        entity.paraId = model.paraId
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
        entity.identityChain = model.identityChain
        updateEntityAsset(for: entity, from: model, context: context)
        updateEntityNodes(for: entity, from: model, context: context)
        updateExternalApis(in: entity, from: model.externalApi)
        updateEntityCustomNodes(for: entity, from: model, context: context)
        updateEntitySelectedNode(for: entity, from: model, context: context)
        updateEplorersApis(in: entity, from: model.externalApi?.explorers, context: context)
        updateXcmConfig(in: entity, from: model.xcm, context: context)
    }
}
