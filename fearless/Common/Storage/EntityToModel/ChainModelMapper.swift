import Foundation
#if canImport(SSFAssetManagmentStorage)
    import SSFAssetManagmentStorage
#endif
import CoreData
import RobinHood
import SSFModels
import SSFUtils

enum ChainModelMapperError: LocalizedError, Equatable {
    case missingNodeURL
    case missingNodeName
    case invalidNodeURL

    var errorDescription: String? {
        switch self {
        case .missingNodeURL:
            return "Stored chain node is missing its URL"
        case .missingNodeName:
            return "Stored chain node is missing its name"
        case .invalidNodeURL:
            return "Stored chain node has an unusable URL"
        }
    }
}

// Fail-closed mapping invariants remain in one mapper.
// swiftlint:disable:next type_body_length
final class ChainModelMapper {
    static let quarantinedChainIdentifierPrefix = "__invalid_local_chain__:"
    static let quarantinedChainName = "Unavailable local chain"
    private static let supportedNodeSchemes = Set(["http", "https", "ws", "wss"])

    private let assetModelMapper = AssetModelMapper()

    var entityIdentifierFieldName: String { #keyPath(CDChain.chainId) }

    typealias DataProviderModel = ChainModel
    typealias CoreDataEntity = CDChain

    func createPriceData(from object: NSManagedObject) -> PriceData? {
        var priceData: PriceData?

        do {
            try SafeObjectiveCExceptionBoundary.perform {
                let attributes = object.entity.attributesByName
                guard
                    attributes["currencyId"] != nil,
                    attributes["priceId"] != nil,
                    attributes["price"] != nil
                else {
                    return
                }

                priceData = self.createPriceDataWithoutExceptionBoundary(
                    from: object,
                    attributes: attributes
                )
            }
        } catch {
            return nil
        }

        return priceData
    }

    private func createPriceDataWithoutExceptionBoundary(
        from object: NSManagedObject,
        attributes: [String: NSAttributeDescription]
    ) -> PriceData? {
        guard
            let currencyId = object.value(forKey: "currencyId") as? String,
            let priceId = object.value(forKey: "priceId") as? String
        else { return nil }

        let priceString: String? = {
            if let decimalValue = object.value(forKey: "price") as? Decimal {
                return NSDecimalNumber(decimal: decimalValue).stringValue
            }
            if let numberValue = object.value(forKey: "price") as? NSDecimalNumber { return numberValue.stringValue }
            if let stringValue = object.value(forKey: "price") as? String { return stringValue }
            return nil
        }()
        guard
            let price = priceString,
            Self.isValidCachedPrice(price)
        else {
            return nil
        }

        let fiatDayStr = attributes["fiatDayByChange"].flatMap { _ in
            object.value(forKey: "fiatDayByChange") as? String
        }
        let coingeckoPriceId = attributes["coingeckoPriceId"].flatMap { _ in
            object.value(forKey: "coingeckoPriceId") as? String
        }

        return PriceData(
            currencyId: currencyId,
            priceId: priceId,
            price: price,
            fiatDayChange: Decimal(string: fiatDayStr ?? ""),
            coingeckoPriceId: coingeckoPriceId
        )
    }

    private func cachedPriceObjects(
        from assetEntity: CDAsset
    ) -> [NSManagedObject] {
        guard
            assetEntity.entity.relationshipsByName["priceData"] != nil
        else {
            return []
        }

        do {
            let rawValue = try SafeTransformableValueReader.readObject(
                from: assetEntity,
                key: "priceData"
            )

            return (rawValue as? NSSet)?
                .compactMap { $0 as? NSManagedObject } ?? []
        } catch {
            return []
        }
    }

    private static func isValidCachedPrice(_ price: String) -> Bool {
        let normalizedPrice = price.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard normalizedPrice.isNotEmpty else {
            return false
        }

        let scanner = Scanner(string: normalizedPrice)
        scanner.locale = Locale(identifier: "en_US_POSIX")
        scanner.charactersToBeSkipped = nil

        guard
            let decimalPrice = scanner.scanDecimal(),
            scanner.isAtEnd,
            !decimalPrice.isNaN
        else {
            return false
        }

        return decimalPrice >= 0
    }

    private func createChainNode(from entity: CDChainNode) throws -> ChainNodeModel {
        guard let url = entity.url else {
            throw ChainModelMapperError.missingNodeURL
        }

        guard Self.isUsableNodeURL(url) else {
            throw ChainModelMapperError.invalidNodeURL
        }

        guard
            let name = entity.name,
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw ChainModelMapperError.missingNodeName
        }

        let apiKey: ChainNodeModel.ApiKey?

        if let queryName = entity.apiQueryName, let keyName = entity.apiKeyName {
            apiKey = ChainNodeModel.ApiKey(queryName: queryName, keyName: keyName)
        } else {
            apiKey = nil
        }

        return ChainNodeModel(
            url: url,
            name: name,
            apikey: apiKey
        )
    }

    static func isUsableNodeURL(_ url: URL) -> Bool {
        guard
            let components = URLComponents(
                url: url,
                resolvingAgainstBaseURL: false
            ),
            let scheme = components.scheme?.lowercased(),
            supportedNodeSchemes.contains(scheme),
            components.host?.isEmpty == false
        else {
            return false
        }

        return true
    }

    static func isNodeCompatibleWithRuntime(
        _ node: ChainNodeModel,
        for chain: ChainModel
    ) -> Bool {
        if chain.isTonCompatibilityChain {
            return TonAPIClientFactory.isValidServerURL(node.url)
        }

        let scheme = node.url.scheme?.lowercased()
        if chain.chainBaseType == .ethereum {
            return scheme == "https" || scheme == "wss"
        }

        return scheme == "ws" || scheme == "wss"
    }

    private func createQuarantinedChain(from entity: CDChain) -> ChainModel {
        let objectIdentifier = entity.objectID.uriRepresentation().absoluteString

        return ChainModel(
            rank: nil,
            disabled: true,
            chainId: Self.quarantinedChainIdentifierPrefix + objectIdentifier,
            parentId: nil,
            paraId: nil,
            name: Self.quarantinedChainName,
            xcm: nil,
            nodes: [],
            addressPrefix: UInt16(bitPattern: entity.addressPrefix),
            types: nil,
            icon: nil,
            options: nil,
            externalApi: nil,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }

    private func updateEntityAsset(
        for entity: CDChain,
        from model: ChainModel,
        context: NSManagedObjectContext
    ) throws {
        let oldAssets = entity.assets as? Set<CDAsset>
        let assets = try model.assets.map { assetModel in
            let assetEntity = CDAsset(context: context)
            try assetModelMapper.populate(entity: assetEntity, from: assetModel, using: context)

            if
                let oldAssets,
                let updatedAsset = oldAssets.first(where: { cdAsset in
                    cdAsset.id == assetModel.id
                }) {
                if updatedAsset.entity.relationshipsByName["priceData"] != nil,
                   let oldPrices = updatedAsset.value(forKey: "priceData") as? NSSet {
                    assetEntity.setValue(oldPrices, forKey: "priceData")
                }
            }

            return assetEntity
        }

        if let oldAssets {
            oldAssets.forEach { cdAsset in
                context.delete(cdAsset)
            }
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

            let existingCustomEntity = entity.customNodes?
                .first { ($0 as? CDChainNode)?.url == node.url } as? CDChainNode

            if let existingEntity = maybeExistingEntity ?? existingCustomEntity {
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

        let retainedNodeEntities = Set(nodeEntities)

        if let oldNodes = entity.nodes as? Set<CDChainNode> {
            for oldNode in oldNodes {
                let oldNodeURL = oldNode.url
                let remainsDefault = retainedNodeEntities.contains(oldNode)
                let remainsSharedCustom = oldNodeURL.map { url in
                    model.customNodes?.contains {
                        $0.url == url
                    } == true &&
                        (entity.customNodes as? Set<CDChainNode>)?
                        .contains(oldNode) == true
                } ?? false
                let remainsSharedSelection =
                    oldNodeURL == model.selectedNode?.url &&
                    entity.selectedNode === oldNode

                if !remainsDefault,
                   !remainsSharedCustom,
                   !remainsSharedSelection {
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

            let existingDefaultEntity = entity.nodes?
                .first { ($0 as? CDChainNode)?.url == node.url } as? CDChainNode

            if let existingEntity = maybeExistingEntity ?? existingDefaultEntity {
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

        let retainedNodeEntities = Set(nodeEntities)

        if let oldNodes = entity.customNodes as? Set<CDChainNode> {
            for oldNode in oldNodes {
                let oldNodeURL = oldNode.url
                let remainsCustom = retainedNodeEntities.contains(oldNode)
                let remainsSharedDefault = oldNodeURL.map { url in
                    model.nodes.contains {
                        $0.url == url
                    } &&
                        (entity.nodes as? Set<CDChainNode>)?
                        .contains(oldNode) == true
                } ?? false
                let remainsSharedSelection =
                    oldNodeURL == model.selectedNode?.url &&
                    entity.selectedNode === oldNode

                if !remainsCustom,
                   !remainsSharedDefault,
                   !remainsSharedSelection {
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

        // Pricing API removed in new SSFModels; ignore if present

        let explorers = createExplorers(from: entity)

        if staking != nil || history != nil || crowdloans != nil || explorers != nil {
            return ChainModel.ExternalApiSet(
                staking: staking,
                history: history,
                crowdloans: crowdloans,
                explorers: explorers,
                pricing: nil
            )
        } else {
            return nil
        }
    }

    private func createXcmConfig(from entity: CDChain) -> XcmChain? {
        guard
            let versionRaw = entity.xcmConfig?.xcmVersion,
            let availableAssets = entity.xcmConfig?.availableAssets,
            let availableDestinations = entity.xcmConfig?.availableDestinations
        else {
            return nil
        }

        let version = XcmCallFactoryVersion(rawValue: versionRaw)
        let assetEntities = availableAssets.allObjects as? [CDXcmAvailableAsset] ?? []
        let assets: [XcmAvailableAsset] = assetEntities.reduce(into: []) { result, entity in
            guard let id = entity.id, let symbol = entity.symbol else {
                return
            }

            result.append(XcmAvailableAsset(id: id, symbol: symbol))
        }
        let destinationEntities = availableDestinations.allObjects as? [CDXcmAvailableDestination] ?? []
        let destinations: [XcmAvailableDestination] = destinationEntities.reduce(into: []) { result, entity in
            guard let chainId = entity.chainId, let assetsEntities = entity.assets else {
                return
            }

            let destinationAssetEntities = assetsEntities.allObjects as? [CDXcmAvailableAsset] ?? []
            let assets: [XcmAvailableAsset] = destinationAssetEntities.reduce(into: []) { result, entity in
                guard let id = entity.id, let symbol = entity.symbol else {
                    return
                }

                result.append(XcmAvailableAsset(id: id, symbol: symbol))
            }
            result.append(XcmAvailableDestination(
                chainId: chainId,
                bridgeParachainId: entity.bridgeParachainId,
                assets: assets
            ))
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

        let explorerEntities = entityExplorers.allObjects as? [CDExternalApi] ?? []
        let explorers: [ChainModel.ExternalApiExplorer] = explorerEntities.reduce(into: []) { result, explorer in
            let storedTypes: [String]? = try? SafeTransformableValueReader.read(
                from: explorer,
                key: "types"
            )
            guard
                let type = explorer.type,
                let types = storedTypes,
                let url = explorer.url
            else {
                return
            }
            let externapApiTypes = types.compactMap {
                ChainModel.SubscanType(rawValue: $0)
            }
            result.append(ChainModel.ExternalApiExplorer(
                type: ChainModel.ExternalApiExplorerType(rawValue: type) ?? .unknown,
                types: externapApiTypes,
                url: url
            ))
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
        if let destWeightIsPrimitive = xcmConfig.destWeightIsPrimitive {
            configEntity.destWeightIsPrimitive = destWeightIsPrimitive
        }

        let availableAssets = xcmConfig.availableAssets.map {
            let entity = CDXcmAvailableAsset(context: context)
            entity.id = $0.id
            entity.symbol = $0.symbol
            return entity
        }
        configEntity.availableAssets = Set(availableAssets) as NSSet

        let destinationEntities = xcmConfig.availableDestinations.map {
            let destinationEntity = CDXcmAvailableDestination(context: context)
            destinationEntity.chainId = $0.chainId

            let availableAssets = $0.assets.map {
                let entity = CDXcmAvailableAsset(context: context)
                entity.id = $0.id
                entity.symbol = $0.symbol
                // minAmount not available in current model
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
        var mappedChain: ChainModel?

        // Mapping a chain traverses several generated Core Data relationships.
        // Any one of those getters can raise NSException for a damaged legacy
        // row, so the complete startup read is an atomic exception boundary.
        try SafeObjectiveCExceptionBoundary.perform {
            mappedChain = try self.transformWithoutExceptionBoundary(
                entity: entity
            )
        }

        guard let mappedChain else {
            throw SafeTransformableValueReaderError.objectiveCException
        }

        return mappedChain
    }

    // Defensive mapping remains one atomic validation.
    // swiftlint:disable:next function_body_length
    private func transformWithoutExceptionBoundary(
        entity: CDChain
    ) throws -> ChainModel {
        guard
            let rawChainId = entity.chainId,
            rawChainId.isNotEmpty
        else {
            return createQuarantinedChain(from: entity)
        }

        let storedChainId = rawChainId.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard
            storedChainId.isNotEmpty,
            storedChainId == rawChainId
        else {
            return createQuarantinedChain(from: entity)
        }

        let storedName = entity.name?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let hasValidName = storedName?.isNotEmpty == true
        let name: String
        if let storedName, storedName.isNotEmpty {
            name = storedName
        } else {
            name = Self.quarantinedChainName
        }

        let nodes: [ChainNodeModel] = entity.nodes?.compactMap { anyNode in
            guard let node = anyNode as? CDChainNode else {
                return nil
            }

            return try? createChainNode(from: node)
        } ?? []

        var customNodesSet: Set<ChainNodeModel>?
        if let entityCustomNodes = entity.customNodes, !entityCustomNodes.allObjects.isEmpty {
            let customNodes: [ChainNodeModel]? = entityCustomNodes.compactMap { anyNode in
                guard let node = anyNode as? CDChainNode else {
                    return nil
                }

                return try? createChainNode(from: node)
            }

            if let nodes = customNodes {
                customNodesSet = Set(nodes)
            }
        }

        var selectedNode: ChainNodeModel?

        if let selectedNodeEntity = entity.selectedNode {
            selectedNode = try? createChainNode(from: selectedNodeEntity)
        }

        let types: ChainModel.TypesSettings?

        if let url = entity.types, let overridesCommon = entity.typesOverrideCommon {
            types = .init(url: url, overridesCommon: overridesCommon.boolValue)
        } else {
            types = nil
        }

        let options: [String]? = try? SafeTransformableValueReader.read(
            from: entity,
            key: "options"
        )
        let externalApiSet = createExternalApi(from: entity)
        let xcm = createXcmConfig(from: entity)
        let paraId: String? = {
            guard entity.entity.propertiesByName["paraId"] != nil else {
                return nil
            }
            return entity.value(forKey: "paraId") as? String
        }()
        let identityChain: String? = {
            guard entity.entity.propertiesByName["identityChain"] != nil else {
                return nil
            }
            return entity.value(forKey: "identityChain") as? String
        }()

        var rank: UInt16?
        if let rankString = entity.rank {
            rank = UInt16(rankString)
        }

        let assetsArray: [AssetModel] = (entity.assets?.compactMap { anyAsset in
            guard let assetEntity = anyAsset as? CDAsset else {
                return nil
            }

            guard let asset = try? assetModelMapper.transform(entity: assetEntity) else {
                return nil
            }
            let cachedPrices = cachedPriceObjects(from: assetEntity)
                .compactMap(createPriceData(from:))
                .sorted(by: Self.cachedPricePrecedes)

            guard let firstCachedPrice = cachedPrices.first else {
                return asset
            }

            if let priceId = asset.priceId,
               let matchingPrice = cachedPrices.first(where: { $0.priceId == priceId }) {
                return asset.replacingPrice(matchingPrice)
            }

            if let matchingCurrency = cachedPrices.first(where: { $0.currencyId == asset.currencyId }) {
                return asset.replacingPrice(matchingCurrency)
            }

            return asset.replacingPrice(firstCachedPrice)
        }) ?? []

        let chainModel = ChainModel(
            rank: rank,
            disabled: entity.disabled || !hasValidName,
            chainId: storedChainId,
            parentId: entity.parentId,
            paraId: paraId,
            name: name,
            xcm: xcm,
            nodes: Set(nodes),
            addressPrefix: UInt16(bitPattern: entity.addressPrefix),
            types: types,
            icon: entity.icon,
            options: options?.compactMap { ChainOptions(rawValue: $0) },
            externalApi: externalApiSet,
            selectedNode: selectedNode,
            customNodes: customNodesSet,
            iosMinAppVersion: entity.minimalAppVersion,
            identityChain: identityChain
        )

        chainModel.assets = Set(assetsArray)

        let compatibleNodes = Set(
            chainModel.nodes.filter {
                Self.isNodeCompatibleWithRuntime($0, for: chainModel)
            }
        )
        let compatibleCustomNodes = chainModel.customNodes.map {
            Set(
                $0.filter {
                    Self.isNodeCompatibleWithRuntime(
                        $0,
                        for: chainModel
                    )
                }
            )
        }
        let compatibleSelectedNode = chainModel.selectedNode.flatMap {
            Self.isNodeCompatibleWithRuntime($0, for: chainModel)
                ? $0
                : nil
        }
        let hasRuntimeEndpoint =
            compatibleNodes.isNotEmpty ||
            compatibleSelectedNode != nil ||
            compatibleCustomNodes?.isNotEmpty == true

        return chainModel
            .replacingNodeConfiguration(
                nodes: compatibleNodes,
                selectedNode: compatibleSelectedNode,
                customNodes: compatibleCustomNodes
            )
            .replacingDisabled(
                chainModel.disabled || !hasRuntimeEndpoint
            )
    }

    private static func cachedPricePrecedes(
        _ lhs: PriceData,
        _ rhs: PriceData
    ) -> Bool {
        let lhsDayChange = lhs.fiatDayChange.map {
            NSDecimalNumber(decimal: $0).stringValue
        } ?? ""
        let rhsDayChange = rhs.fiatDayChange.map {
            NSDecimalNumber(decimal: $0).stringValue
        } ?? ""
        let lhsKey = [
            lhs.priceId,
            lhs.currencyId,
            lhs.coingeckoPriceId ?? "",
            lhs.price,
            lhsDayChange
        ]
        let rhsKey = [
            rhs.priceId,
            rhs.currencyId,
            rhs.coingeckoPriceId ?? "",
            rhs.price,
            rhsDayChange
        ]

        return lhsKey.lexicographicallyPrecedes(rhsKey)
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
        if entity.entity.propertiesByName["paraId"] != nil {
            entity.setValue(model.paraId, forKey: "paraId")
        }
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
        if entity.entity.propertiesByName["identityChain"] != nil {
            entity.setValue(model.identityChain, forKey: "identityChain")
        }
        try updateEntityAsset(for: entity, from: model, context: context)
        updateEntityNodes(for: entity, from: model, context: context)
        updateExternalApis(in: entity, from: model.externalApi)
        updateEntityCustomNodes(for: entity, from: model, context: context)
        updateEntitySelectedNode(for: entity, from: model, context: context)
        updateEplorersApis(in: entity, from: model.externalApi?.explorers, context: context)
        updateXcmConfig(in: entity, from: model.xcm, context: context)
    }
}
