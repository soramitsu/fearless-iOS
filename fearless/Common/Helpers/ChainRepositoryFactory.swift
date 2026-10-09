import CoreData
import Foundation
import RobinHood
#if canImport(SSFAssetManagmentStorage)
    import SSFAssetManagmentStorage
#endif
import SSFModels

final class ChainRepositoryFactory {
    let storageFacade: StorageFacadeProtocol

    init(storageFacade: StorageFacadeProtocol = SubstrateDataStorageFacade.shared) {
        self.storageFacade = storageFacade
    }

    func createRepository(
        for filter: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor] = []
    ) -> CoreDataRepository<ChainModel, CDChain> {
        let mapper = ChainModelMapper()
        return storageFacade.createRepository(
            filter: filter,
            sortDescriptors: sortDescriptors,
            mapper: AnyCoreDataMapper(mapper)
        )
    }

    func createAsyncRepository(
        for filter: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor] = []
    ) -> AsyncCoreDataRepositoryDefault<ChainModel, CDChain> {
        let mapper = ChainModelMapper()
        return storageFacade.createAsyncRepository(
            filter: filter,
            sortDescriptors: sortDescriptors,
            mapper: AnyCoreDataMapper(mapper)
        )
    }
}

extension ChainRepositoryFactory {
    func createMalformedChainCleanupOperation() -> BaseOperation<Void> {
        ClosureOperation { [storageFacade] in
            let semaphore = DispatchSemaphore(value: 0)
            let result = ChainCleanupResultBox()

            storageFacade.databaseService.performAsync { context, error in
                defer { semaphore.signal() }

                do {
                    if let error {
                        throw error
                    }

                    guard let context else {
                        throw CoreDataRepositoryError.undefined
                    }

                    // Cleanup traverses every persisted CDChain scalar and
                    // relationship. Treat that entire graph, including save,
                    // as one exception-safe transaction so a damaged generated
                    // getter cannot terminate cold boot or leave a partial
                    // quarantine/merge in the context.
                    try SafeObjectiveCExceptionBoundary.perform {
                        let request = NSFetchRequest<CDChain>(
                            entityName: String(describing: CDChain.self)
                        )
                        let chains = try context.fetch(request)
                        self.cleanupMalformedChains(
                            chains,
                            in: context
                        )

                        if context.hasChanges {
                            try context.save()
                        }
                    }

                    result.set(.success(()))
                } catch {
                    // A damaged generated accessor can also be touched while
                    // Core Data unwinds a failed transaction. Keep rollback
                    // inside the same exception-safe contract so the recovery
                    // path cannot terminate the process.
                    try? SafeObjectiveCExceptionBoundary.perform {
                        context?.rollback()
                    }
                    result.set(.failure(error))
                }
            }

            semaphore.wait()
            return try result.get().get()
        }
    }

    private func cleanupMalformedChains(
        _ chains: [CDChain],
        in context: NSManagedObjectContext
    ) {
        var chainsByCanonicalIdentifier: [String: [CDChain]] = [:]
        var chainsWithoutIdentifier: [CDChain] = []

        for chain in chains {
            guard let rawIdentifier = chain.chainId else {
                chainsWithoutIdentifier.append(chain)
                continue
            }

            let canonicalIdentifier = rawIdentifier.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            guard canonicalIdentifier.isNotEmpty else {
                chainsWithoutIdentifier.append(chain)
                continue
            }

            chainsByCanonicalIdentifier[
                canonicalIdentifier,
                default: []
            ].append(chain)
        }

        var occupiedIdentifiers = Set(
            chainsByCanonicalIdentifier.keys
        )
        for chain in chainsWithoutIdentifier.sorted(by: {
            $0.objectID.uriRepresentation().absoluteString
                < $1.objectID.uriRepresentation().absoluteString
        }) {
            quarantineChain(
                chain,
                occupiedIdentifiers: &occupiedIdentifiers
            )
        }

        for (canonicalIdentifier, collidingChains) in
            chainsByCanonicalIdentifier {
            let orderedChains = collidingChains.sorted {
                $0.objectID.uriRepresentation().absoluteString
                    < $1.objectID.uriRepresentation().absoluteString
            }
            guard
                let target = orderedChains.first(where: {
                    $0.chainId == canonicalIdentifier
                }) ?? orderedChains.first
            else {
                continue
            }

            for source in orderedChains where source !== target {
                if let mergePlan = makeLosslessMergePlan(
                    from: source,
                    into: target
                ) {
                    applyLosslessMerge(
                        mergePlan,
                        from: source,
                        into: target
                    )
                    context.delete(source)
                } else {
                    quarantineChain(
                        source,
                        occupiedIdentifiers: &occupiedIdentifiers
                    )
                }
            }

            target.chainId = canonicalIdentifier
        }
    }

    private func makeLosslessMergePlan(
        from source: CDChain,
        into target: CDChain
    ) -> ChainMergePlan? {
        do {
            let targetOptions: [String]? =
                try SafeTransformableValueReader.read(
                    from: target,
                    key: "options"
                )
            let sourceOptions: [String]? =
                try SafeTransformableValueReader.read(
                    from: source,
                    key: "options"
                )

            guard
                scalarValuesCanMerge(
                    from: source,
                    into: target,
                    sourceOptions: sourceOptions,
                    targetOptions: targetOptions
                ),
                target.xcmConfig == nil ||
                source.xcmConfig == nil ||
                target.xcmConfig === source.xcmConfig,
                let targetNodeGraph = makeNodeGraph(for: target),
                let sourceNodeGraph = makeNodeGraph(for: source),
                nodeGraphsCanMerge(
                    sourceNodeGraph,
                    into: targetNodeGraph
                ),
                assetsCanMerge(from: source, into: target)
            else {
                return nil
            }

            return ChainMergePlan(
                targetOptions: targetOptions,
                sourceOptions: sourceOptions,
                targetNodeGraph: targetNodeGraph,
                sourceNodeGraph: sourceNodeGraph,
                sourceAssets: managedObjects(
                    in: source.assets,
                    as: CDAsset.self
                ),
                sourceExplorers: managedObjects(
                    in: source.explorers,
                    as: CDExternalApi.self
                )
            )
        } catch {
            return nil
        }
    }

    private func scalarValuesCanMerge(
        from source: CDChain,
        into target: CDChain,
        sourceOptions: [String]?,
        targetOptions: [String]?
    ) -> Bool {
        guard
            !valuesConflict(target.rank, source.rank),
            target.disabled == source.disabled,
            !valuesConflict(target.parentId, source.parentId),
            !valuesConflict(target.name, source.name),
            !valuesConflict(target.types, source.types),
            !valuesConflict(
                target.typesOverrideCommon?.boolValue,
                source.typesOverrideCommon?.boolValue
            ),
            target.addressPrefix == source.addressPrefix,
            !valuesConflict(target.icon, source.icon),
            target.isEthereumBased == source.isEthereumBased,
            target.isTestnet == source.isTestnet,
            target.hasCrowdloans == source.hasCrowdloans,
            target.isTipRequired == source.isTipRequired,
            !valuesConflict(
                target.minimalAppVersion,
                source.minimalAppVersion
            ),
            !valuesConflict(targetOptions, sourceOptions),
            !valuesConflict(target.stakingApiType, source.stakingApiType),
            !valuesConflict(target.stakingApiUrl, source.stakingApiUrl),
            !valuesConflict(target.historyApiType, source.historyApiType),
            !valuesConflict(target.historyApiUrl, source.historyApiUrl),
            !valuesConflict(
                target.crowdloansApiType,
                source.crowdloansApiType
            ),
            !valuesConflict(
                target.crowdloansApiUrl,
                source.crowdloansApiUrl
            ),
            !valuesConflict(target.pricingApiType, source.pricingApiType),
            !valuesConflict(target.pricingApiUrl, source.pricingApiUrl),
            !valuesConflict(target.identityChain, source.identityChain),
            !valuesConflict(target.paraId, source.paraId),
            target.isOrml == source.isOrml
        else {
            return false
        }

        return true
    }

    private func valuesConflict<Value: Equatable>(
        _ target: Value?,
        _ source: Value?
    ) -> Bool {
        guard let target, let source else {
            return false
        }

        return target != source
    }
}

private extension ChainRepositoryFactory {
    private func makeNodeGraph(for chain: CDChain) -> ChainNodeGraph? {
        let defaultNodes = managedObjects(
            in: chain.nodes,
            as: CDChainNode.self
        )
        let customNodes = managedObjects(
            in: chain.customNodes,
            as: CDChainNode.self
        )
        let rawSelectedNode = chain.selectedNode
        let selectedNode = rawSelectedNode.flatMap {
            isValidNode($0) ? $0 : nil
        }
        let orderedValidNodes = (
            defaultNodes.filter(isValidNode) +
                customNodes.filter(isValidNode) +
                [selectedNode].compactMap { $0 }
        ).sorted {
            $0.objectID.uriRepresentation().absoluteString
                < $1.objectID.uriRepresentation().absoluteString
        }

        var nodesByURL: [URL: CDChainNode] = [:]
        var fingerprintsByURL: [URL: ChainNodeFingerprint] = [:]

        for node in orderedValidNodes {
            guard
                let url = node.url,
                let fingerprint = nodeFingerprint(for: node)
            else {
                continue
            }

            if let existing = fingerprintsByURL[url],
               existing != fingerprint {
                return nil
            }

            if nodesByURL[url] == nil {
                nodesByURL[url] = node
                fingerprintsByURL[url] = fingerprint
            }
        }

        return ChainNodeGraph(
            allDefaultNodes: defaultNodes,
            allCustomNodes: customNodes,
            rawSelectedNode: rawSelectedNode,
            nodesByURL: nodesByURL,
            fingerprintsByURL: fingerprintsByURL
        )
    }

    private func nodeGraphsCanMerge(
        _ source: ChainNodeGraph,
        into target: ChainNodeGraph
    ) -> Bool {
        for (url, sourceFingerprint) in source.fingerprintsByURL {
            if let targetFingerprint = target.fingerprintsByURL[url],
               targetFingerprint != sourceFingerprint {
                return false
            }
        }

        if let targetSelection = target.rawSelectedNode,
           let sourceSelection = source.rawSelectedNode {
            guard
                targetSelection === sourceSelection ||
                (
                    nodeFingerprint(for: targetSelection) != nil &&
                        nodeFingerprint(for: targetSelection) ==
                        nodeFingerprint(for: sourceSelection)
                )
            else {
                return false
            }
        }

        return true
    }

    private func nodeFingerprint(
        for node: CDChainNode
    ) -> ChainNodeFingerprint? {
        guard
            let url = node.url,
            let name = node.name,
            ChainModelMapper.isUsableNodeURL(url),
            name.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isNotEmpty
        else {
            return nil
        }

        return ChainNodeFingerprint(
            url: url,
            name: name,
            apiQueryName: node.apiQueryName,
            apiKeyName: node.apiKeyName
        )
    }

    private func assetsCanMerge(
        from source: CDChain,
        into target: CDChain
    ) -> Bool {
        let targetIdentifiers = validAssetIdentifiers(in: target.assets)
        let sourceIdentifiers = validAssetIdentifiers(in: source.assets)

        guard
            targetIdentifiers.count ==
            Set(targetIdentifiers).count,
            sourceIdentifiers.count ==
            Set(sourceIdentifiers).count
        else {
            return false
        }

        return Set(targetIdentifiers)
            .isDisjoint(with: sourceIdentifiers)
    }

    private func validAssetIdentifiers(in relationship: NSSet?) -> [String] {
        managedObjects(in: relationship, as: CDAsset.self).compactMap {
            guard
                let identifier = $0.id,
                identifier.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isNotEmpty
            else {
                return nil
            }

            return identifier
        }
    }
}

private extension ChainRepositoryFactory {
    private func applyLosslessMerge(
        _ plan: ChainMergePlan,
        from source: CDChain,
        into target: CDChain
    ) {
        mergeScalarValues(plan, from: source, into: target)

        var preferredNodesByURL = plan.targetNodeGraph.nodesByURL
        let resolveNode: (CDChainNode) -> CDChainNode = { node in
            guard
                let url = node.url,
                plan.sourceNodeGraph.fingerprintsByURL[url] != nil
            else {
                return node
            }

            if let existingNode = preferredNodesByURL[url] {
                return existingNode
            }

            preferredNodesByURL[url] = node
            return node
        }

        var targetDefaultNodes = Set(
            managedObjects(in: target.nodes, as: CDChainNode.self)
        )
        for node in plan.sourceNodeGraph.allDefaultNodes {
            targetDefaultNodes.insert(resolveNode(node))
        }

        var targetCustomNodes = Set(
            managedObjects(
                in: target.customNodes,
                as: CDChainNode.self
            )
        )
        for node in plan.sourceNodeGraph.allCustomNodes {
            targetCustomNodes.insert(resolveNode(node))
        }

        if plan.targetNodeGraph.rawSelectedNode == nil,
           let sourceSelectedNode =
           plan.sourceNodeGraph.rawSelectedNode {
            target.selectedNode = resolveNode(sourceSelectedNode)
        }

        target.nodes = NSSet(set: targetDefaultNodes)
        target.customNodes = NSSet(set: targetCustomNodes)

        var targetAssets = Set(
            managedObjects(in: target.assets, as: CDAsset.self)
        )
        targetAssets.formUnion(plan.sourceAssets)
        target.assets = NSSet(set: targetAssets)

        var targetExplorers = Set(
            managedObjects(
                in: target.explorers,
                as: CDExternalApi.self
            )
        )
        targetExplorers.formUnion(plan.sourceExplorers)
        target.explorers = NSSet(set: targetExplorers)

        if target.xcmConfig == nil {
            target.xcmConfig = source.xcmConfig
        }

        source.nodes = NSSet()
        source.customNodes = NSSet()
        source.selectedNode = nil
        source.assets = NSSet()
        source.explorers = NSSet()
        source.xcmConfig = nil
    }

    private func mergeScalarValues(
        _ plan: ChainMergePlan,
        from source: CDChain,
        into target: CDChain
    ) {
        if target.rank == nil {
            target.rank = source.rank
        }
        if target.parentId == nil {
            target.parentId = source.parentId
        }
        if target.name == nil {
            target.name = source.name
        }
        if target.types == nil {
            target.types = source.types
        }
        if target.typesOverrideCommon == nil {
            target.typesOverrideCommon = source.typesOverrideCommon
        }
        if target.icon == nil {
            target.icon = source.icon
        }
        if target.minimalAppVersion == nil {
            target.minimalAppVersion = source.minimalAppVersion
        }
        if plan.targetOptions == nil, let sourceOptions = plan.sourceOptions {
            target.setValue(
                NSArray(array: sourceOptions),
                forKey: "options"
            )
        }
        if target.stakingApiType == nil {
            target.stakingApiType = source.stakingApiType
        }
        if target.stakingApiUrl == nil {
            target.stakingApiUrl = source.stakingApiUrl
        }
        if target.historyApiType == nil {
            target.historyApiType = source.historyApiType
        }
        if target.historyApiUrl == nil {
            target.historyApiUrl = source.historyApiUrl
        }
        if target.crowdloansApiType == nil {
            target.crowdloansApiType = source.crowdloansApiType
        }
        if target.crowdloansApiUrl == nil {
            target.crowdloansApiUrl = source.crowdloansApiUrl
        }
        if target.pricingApiType == nil {
            target.pricingApiType = source.pricingApiType
        }
        if target.pricingApiUrl == nil {
            target.pricingApiUrl = source.pricingApiUrl
        }
        if target.identityChain == nil {
            target.identityChain = source.identityChain
        }
        if target.paraId == nil {
            target.paraId = source.paraId
        }
    }

    private func quarantineChain(
        _ chain: CDChain,
        occupiedIdentifiers: inout Set<String>
    ) {
        let baseIdentifier =
            ChainModelMapper.quarantinedChainIdentifierPrefix +
            chain.objectID.uriRepresentation().absoluteString
        var identifier = baseIdentifier
        var collisionIndex = 0

        while occupiedIdentifiers.contains(identifier) {
            collisionIndex += 1
            identifier = "\(baseIdentifier)#\(collisionIndex)"
        }

        chain.chainId = identifier
        occupiedIdentifiers.insert(identifier)
        chain.disabled = true

        if chain.name?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty != false {
            chain.name = ChainModelMapper.quarantinedChainName
        }
    }

    private func managedObjects<Object: NSManagedObject>(
        in relationship: NSSet?,
        as _: Object.Type
    ) -> [Object] {
        relationship?.compactMap { $0 as? Object } ?? []
    }

    private func isValidNode(_ node: CDChainNode) -> Bool {
        guard
            let url = node.url,
            ChainModelMapper.isUsableNodeURL(url),
            let name = node.name,
            name.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isNotEmpty
        else {
            return false
        }

        return true
    }
}

private struct ChainMergePlan {
    let targetOptions: [String]?
    let sourceOptions: [String]?
    let targetNodeGraph: ChainNodeGraph
    let sourceNodeGraph: ChainNodeGraph
    let sourceAssets: [CDAsset]
    let sourceExplorers: [CDExternalApi]
}

private struct ChainNodeGraph {
    let allDefaultNodes: [CDChainNode]
    let allCustomNodes: [CDChainNode]
    let rawSelectedNode: CDChainNode?
    let nodesByURL: [URL: CDChainNode]
    let fingerprintsByURL: [URL: ChainNodeFingerprint]
}

private struct ChainNodeFingerprint: Equatable {
    let url: URL
    let name: String
    let apiQueryName: String?
    let apiKeyName: String?
}

private final class ChainCleanupResultBox: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<Void, Error>?

    func set(_ result: Result<Void, Error>) {
        lock.lock()
        self.result = result
        lock.unlock()
    }

    func get() -> Result<Void, Error> {
        lock.lock()
        defer { lock.unlock() }

        return result ?? .failure(CoreDataRepositoryError.undefined)
    }
}
