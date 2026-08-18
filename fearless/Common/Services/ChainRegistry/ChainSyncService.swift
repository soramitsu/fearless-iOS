import Foundation
import SoraFoundation
import RobinHood
import SSFUtils
import SSFNetwork
import SSFModels
import SSFChainRegistry

protocol ChainSyncServiceProtocol {
    func syncUp()
}

enum ChainSyncServiceError: Error {
    case missingLocalFile
    case emptyRemotePayload
    case invalidRemoteChain(String)
    case duplicateRemoteChainIdentifier(String)
}

// Sync validation stays with the state it guards.
// swiftlint:disable:next type_body_length
final class ChainSyncService {
    static let fetchLocalData = false
    static let historyExplorerCompatibilityType = "subsquid"
    static let stakingExplorerCompatibilityType = "subquery"
    static let genericExplorerCompatibilityType = "etherscan"
    private static let soraXorCurrencyId = "0x0200000000000000000000000000000000000000000000000000000000000000"

    struct SyncChanges {
        let newOrUpdatedItems: [ChainModel]
        let removedItems: [ChainModel]
    }

    private let chainsUrl: URL
    private let dataFetchFactory: DataOperationFactoryProtocol
    private let repository: AnyDataProviderRepository<ChainModel>
    private let eventCenter: EventCenterProtocol
    private let retryStrategy: ReconnectionStrategyProtocol
    private let applicationHandler: ApplicationHandlerProtocol
    private let operationQueue: OperationQueue
    private let logger: LoggerProtocol?
    private let malformedChainCleanupOperationFactory: (() -> BaseOperation<Void>)?

    private var retryAttempt: Int = 0
    private var isSyncInFlight = false
    private var isCooldownActive = false
    private var reservationIdentifier: UInt = 0
    private var timerReservationIdentifier: UInt?
    private let mutex = NSLock()
    private let timer: CountdownTimerProtocol
    private let cooldownTimerQueue: DispatchQueue

    private lazy var scheduler = Scheduler(with: self, callbackQueue: DispatchQueue.global())

    init(
        chainsUrl: URL,
        dataFetchFactory: DataOperationFactoryProtocol,
        repository: AnyDataProviderRepository<ChainModel>,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        retryStrategy: ReconnectionStrategyProtocol = ExponentialReconnection(),
        logger: LoggerProtocol? = nil,
        applicationHandler: ApplicationHandlerProtocol,
        malformedChainCleanupOperationFactory: (() -> BaseOperation<Void>)? = nil,
        cooldownTimer: CountdownTimerProtocol = CountdownTimer(
            notificationInterval: 300
        ),
        cooldownTimerQueue: DispatchQueue = .main
    ) {
        self.chainsUrl = chainsUrl
        self.dataFetchFactory = dataFetchFactory
        self.repository = repository
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
        self.retryStrategy = retryStrategy
        self.logger = logger
        self.applicationHandler = applicationHandler
        self.malformedChainCleanupOperationFactory = malformedChainCleanupOperationFactory
        timer = cooldownTimer
        self.cooldownTimerQueue = cooldownTimerQueue
        timer.delegate = self
    }

    private func performSyncUpIfNeeded(
        cancelScheduledRetry: Bool = false,
        installApplicationDelegate: Bool = false
    ) {
        mutex.lock()

        if cancelScheduledRetry, retryAttempt > 0 {
            scheduler.cancel()
        }

        if installApplicationDelegate,
           applicationHandler.delegate == nil {
            applicationHandler.delegate = self
        }

        guard !isSyncInFlight, !isCooldownActive else {
            mutex.unlock()
            logger?.debug("Tried to sync up chains but already syncing")
            return
        }

        isSyncInFlight = true
        isCooldownActive = true
        reservationIdentifier &+= 1
        let currentReservationIdentifier = reservationIdentifier
        retryAttempt += 1
        let currentRetryAttempt = retryAttempt
        mutex.unlock()

        cooldownTimerQueue.async {
            self.mutex.lock()
            let shouldStartTimer =
                self.isCooldownActive &&
                self.reservationIdentifier == currentReservationIdentifier
            self.mutex.unlock()

            guard shouldStartTimer else {
                return
            }

            // CountdownTimer.start() synchronously stops its previous run.
            // Keep every timer mutation on this serial queue, and stop the old
            // run before publishing the new reservation.
            self.timer.stop()

            self.mutex.lock()
            let timerIsCurrent =
                self.isCooldownActive &&
                self.reservationIdentifier == currentReservationIdentifier
            if timerIsCurrent {
                self.timerReservationIdentifier =
                    currentReservationIdentifier
            }
            self.mutex.unlock()

            if timerIsCurrent {
                self.timer.start(with: 300)
            }
        }

        logger?.debug(
            "Will start chain sync with attempt \(currentRetryAttempt)"
        )

        let event = ChainSyncDidStart()
        eventCenter.notify(with: event)

        executeSync()
    }

    private func executeSync() {
        guard let malformedChainCleanupOperationFactory else {
            executeRemoteSync()
            return
        }

        let cleanupOperation = malformedChainCleanupOperationFactory()
        cleanupOperation.completionBlock = { [weak self, weak cleanupOperation] in
            do {
                guard let cleanupOperation else {
                    throw BaseOperationError.parentOperationCancelled
                }

                _ = try cleanupOperation.extractNoCancellableResultData()
                self?.executeRemoteSync()
            } catch {
                self?.complete(result: .failure(error))
            }
        }
        operationQueue.addOperation(cleanupOperation)
    }

    private func executeRemoteSync() {
        if Self.fetchLocalData {
            do {
                let localData = try fetchLocalData()
                handle(remoteChains: localData)
            } catch {
                complete(result: .failure(error))
            }
        } else {
            let fetchOperation = dataFetchFactory.fetchData(from: chainsUrl)
            fetchOperation.completionBlock = { [weak self, weak fetchOperation] in
                guard
                    let self = self,
                    let operation = fetchOperation,
                    !operation.isCancelled
                else {
                    return
                }
                do {
                    let data = try operation.extractNoCancellableResultData()
                    let remoteChains = try self.decodeChainsTolerant(from: data)
                    self.handle(remoteChains: remoteChains)
                } catch {
                    self.ensureAppOwnedChainsBeforeRemoteFailure(error)
                }
            }
            operationQueue.addOperation(fetchOperation)
        }
    }

    private func ensureAppOwnedChainsBeforeRemoteFailure(_ remoteError: Error) {
        let fetchOperation = repository.fetchAllOperation(
            with: RepositoryFetchOptions()
        )
        let bootstrapOperation: BaseOperation<(
            models: [ChainModel],
            deleteIds: [String]
        )> = ClosureOperation {
            let localChains = try fetchOperation.extractNoCancellableResultData()
            let canonicalChains = Self.preservingLocalNodePreferences(
                remoteChains: UniversalWalletRegistry.appOwnedProductionChains,
                localChains: localChains
            )
            let canonicalIds = Set(canonicalChains.map(\.chainId))
            let aliasIds = localChains.compactMap { localChain -> String? in
                let matchesAppOwned = canonicalChains.contains { appOwnedChain in
                    UniversalWalletChainAccountSupport.chainId(
                        localChain.chainId,
                        matches: appOwnedChain.chainId
                    )
                }
                guard matchesAppOwned, !canonicalIds.contains(localChain.chainId) else {
                    return nil
                }
                return localChain.chainId
            }

            return (canonicalChains, aliasIds)
        }
        let saveOperation = repository.saveOperation({
            try bootstrapOperation.extractNoCancellableResultData().models
        }, {
            try bootstrapOperation.extractNoCancellableResultData().deleteIds
        })
        bootstrapOperation.addDependency(fetchOperation)
        saveOperation.addDependency(bootstrapOperation)
        saveOperation.completionBlock = { [weak self, weak saveOperation] in
            do {
                guard let saveOperation else {
                    throw BaseOperationError.parentOperationCancelled
                }
                _ = try saveOperation.extractNoCancellableResultData()
                let updatedChains = try bootstrapOperation
                    .extractNoCancellableResultData().models
                self?.eventCenter.notify(
                    with: ChainsUpdatedEvent(updatedChains: updatedChains)
                )
                self?.complete(result: .failure(remoteError))
            } catch {
                self?.complete(result: .failure(error))
            }
        }

        operationQueue.addOperations(
            [fetchOperation, bootstrapOperation, saveOperation],
            waitUntilFinished: false
        )
    }

    private func decodeChainsTolerant(from data: Data) throws -> [ChainModel] {
        do {
            return try JSONDecoder().decode([ChainModel].self, from: data)
        } catch {
            // Attempt a compatibility coercion for legacy non-token payload differences.
            let coerced = try Self.coerceChainsPayloadForCompatibility(data)
            return try JSONDecoder().decode([ChainModel].self, from: coerced)
        }
    }

    static func coerceChainsPayloadForCompatibility(_ data: Data) throws -> Data {
        let obj = try JSONSerialization.jsonObject(with: data, options: [])
        guard var array = obj as? [[String: Any]] else { return data }

        for index in 0 ..< array.count {
            if array[index]["properties"] == nil {
                let prefixValue = array[index]["addressPrefix"]
                let prefixString: String

                if let intValue = prefixValue as? Int {
                    prefixString = String(intValue)
                } else if let stringValue = prefixValue as? String {
                    prefixString = stringValue
                } else if let number = prefixValue as? NSNumber {
                    prefixString = number.stringValue
                } else {
                    prefixString = "0"
                }

                array[index]["properties"] = ["addressPrefix": prefixString]
            }

            normalizeBlockExplorerTypes(in: &array[index])
        }

        return try JSONSerialization.data(withJSONObject: array, options: [])
    }

    private static func normalizeBlockExplorerTypes(in chainObject: inout [String: Any]) {
        guard var externalApi = chainObject["externalApi"] as? [String: Any] else {
            return
        }

        normalizeBlockExplorerType(
            in: &externalApi,
            key: "history",
            fallbackType: historyExplorerCompatibilityType
        )
        normalizeBlockExplorerType(
            in: &externalApi,
            key: "staking",
            fallbackType: stakingExplorerCompatibilityType
        )

        if var explorers = externalApi["explorers"] as? [[String: Any]] {
            for index in explorers.indices {
                normalizeBlockExplorerType(
                    in: &explorers[index],
                    key: "type",
                    fallbackType: genericExplorerCompatibilityType
                )
            }
            externalApi["explorers"] = explorers
        }

        chainObject["externalApi"] = externalApi
    }

    private static func normalizeBlockExplorerType(
        in object: inout [String: Any],
        key: String,
        fallbackType: String
    ) {
        if var nested = object[key] as? [String: Any] {
            normalizeBlockExplorerType(in: &nested, key: "type", fallbackType: fallbackType)
            object[key] = nested
            return
        }

        guard
            let type = object[key] as? String
        else {
            return
        }

        let normalizedType = type.lowercased()

        if BlockExplorerType(rawValue: normalizedType) != nil {
            object[key] = normalizedType
            return
        }

        switch normalizedType {
        case "blockscout", "klaytn", "kaia":
            object[key] = fallbackType
        default:
            object[key] = fallbackType
        }
    }

    private func handle(remoteChains: [ChainModel]) {
        guard remoteChains.isNotEmpty else {
            ensureAppOwnedChainsBeforeRemoteFailure(
                ChainSyncServiceError.emptyRemotePayload
            )
            return
        }

        let normalizedRemoteChains: [ChainModel]
        do {
            let remoteOnlyChains = Self.removingAppOwnedChainAliases(
                from: remoteChains.map { normalizeSoraNexusChainAssets($0) }
            )
            guard remoteOnlyChains.isNotEmpty else {
                ensureAppOwnedChainsBeforeRemoteFailure(
                    ChainSyncServiceError.emptyRemotePayload
                )
                return
            }

            let downloadedChains = try Self.sanitizingRemoteChains(
                remoteOnlyChains
            )

            normalizedRemoteChains = try Self.sanitizingRemoteChains(
                Self.mergingAppOwnedProductionChains(into: downloadedChains)
            )
        } catch {
            ensureAppOwnedChainsBeforeRemoteFailure(error)
            return
        }

        let localFetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        let processingOperation: BaseOperation<(
            remoteChains: [ChainModel],
            localChains: [ChainModel]
        )> = ClosureOperation {
            let localChains = try localFetchOperation.extractNoCancellableResultData()

            return (
                remoteChains: normalizedRemoteChains,
                localChains: localChains
            )
        }

        processingOperation.completionBlock = { [weak self] in
            guard let result = processingOperation.result else {
                self?.complete(result: .failure(BaseOperationError.parentOperationCancelled))
                return
            }

            switch result {
            case let .success((remoteChains, localChains)):
                self?.syncChanges(
                    remoteChains: remoteChains,
                    localChains: localChains
                )
            case let .failure(error):
                self?.complete(result: .failure(error))
            }
        }

        processingOperation.addDependency(localFetchOperation)
        operationQueue.addOperations(
            [
                localFetchOperation,
                processingOperation
            ],
            waitUntilFinished: false
        )
    }

    static func sanitizingRemoteChains(
        _ remoteChains: [ChainModel]
    ) throws -> [ChainModel] {
        var seenIdentifiers = Set<String>()

        return try remoteChains.map { chain in
            let canonicalIdentifier = chain.chainId.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            guard
                canonicalIdentifier.isNotEmpty,
                canonicalIdentifier == chain.chainId,
                !canonicalIdentifier.hasPrefix(
                    ChainModelMapper.quarantinedChainIdentifierPrefix
                ),
                chain.name.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isNotEmpty
            else {
                throw ChainSyncServiceError.invalidRemoteChain(
                    chain.chainId
                )
            }

            guard seenIdentifiers.insert(chain.chainId).inserted else {
                throw ChainSyncServiceError
                    .duplicateRemoteChainIdentifier(chain.chainId)
            }

            let usableNodesByURL = chain.nodes
                .filter { node in
                    ChainModelMapper.isUsableNodeURL(node.url)
                        && node.name.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isNotEmpty
                        && ChainModelMapper.isNodeCompatibleWithRuntime(
                            node,
                            for: chain
                        )
                }
                .sorted { lhs, rhs in
                    if lhs.url.absoluteString != rhs.url.absoluteString {
                        return lhs.url.absoluteString
                            < rhs.url.absoluteString
                    }

                    if lhs.name != rhs.name {
                        return lhs.name < rhs.name
                    }

                    let lhsQueryName = lhs.apikey?.queryName ?? ""
                    let rhsQueryName = rhs.apikey?.queryName ?? ""
                    if lhsQueryName != rhsQueryName {
                        return lhsQueryName < rhsQueryName
                    }

                    return (lhs.apikey?.keyName ?? "")
                        < (rhs.apikey?.keyName ?? "")
                }
                .reduce(into: [URL: ChainNodeModel]()) { result, node in
                    if result[node.url] == nil {
                        result[node.url] = node
                    }
                }

            guard chain.disabled || usableNodesByURL.isNotEmpty else {
                throw ChainSyncServiceError.invalidRemoteChain(
                    chain.chainId
                )
            }

            return chain
                .replacingNodes(Set(usableNodesByURL.values))
                .replacingCustomNodes([])
                .replacingSelectedNode(nil)
        }
    }

    static func mergingAppOwnedProductionChains(
        into remoteChains: [ChainModel]
    ) -> [ChainModel] {
        let appOwnedChains = UniversalWalletRegistry.appOwnedProductionChains

        return removingAppOwnedChainAliases(from: remoteChains) + appOwnedChains
    }

    static func removingAppOwnedChainAliases(
        from remoteChains: [ChainModel]
    ) -> [ChainModel] {
        let appOwnedChainIds = UniversalWalletRegistry.appOwnedProductionChains.map(\.chainId)

        return remoteChains.filter { remoteChain in
            !appOwnedChainIds.contains { appOwnedChainId in
                UniversalWalletChainAccountSupport.chainId(
                    remoteChain.chainId,
                    matches: appOwnedChainId
                )
            }
        }
    }

    private func normalizeSoraNexusChainAssets(_ chain: ChainModel) -> ChainModel {
        guard isSoraNexus(chain) else {
            return chain
        }

        let hasXor = chain.assets.contains {
            $0.currencyId == Self.soraXorCurrencyId || $0.symbol.lowercased() == "xor"
        }

        guard !hasXor else {
            return chain
        }

        let updatedChain = chain
        let xorAsset = AssetModel(
            id: "b5a44630-920e-43ee-809f-61890d0888b0",
            name: "sora",
            symbol: "xor",
            precision: 18,
            icon: URL(string: "https://raw.githubusercontent.com/soramitsu/shared-features-utils/master/icons/tokens/coloured/XOR.svg"),
            currencyId: Self.soraXorCurrencyId,
            color: "EE2233",
            isUtility: true,
            isNative: true,
            staking: .relayChain,
            type: .soraAsset,
            priceProvider: PriceProvider(
                type: .sorasubquery,
                id: Self.soraXorCurrencyId,
                precision: nil
            ),
            coingeckoPriceId: "sora"
        )
        updatedChain.assets.insert(xorAsset)
        return updatedChain
    }

    private func isSoraNexus(_ chain: ChainModel) -> Bool {
        let name = chain.name.lowercased()
        let chainId = chain.chainId.lowercased()
        return (name.contains("sora") && name.contains("nexus"))
            || chainId.contains("sora-nexus")
            || chainId.contains("soranexus")
    }

    private func syncChanges(
        remoteChains: [ChainModel],
        localChains: [ChainModel]
    ) {
        let mergedRemoteChains = Self.preservingLocalNodePreferences(
            remoteChains: remoteChains,
            localChains: localChains
        )

        let remoteMapping = mergedRemoteChains.reduce(into: [ChainModel.Id: ChainModel]()) { mapping, item in
            mapping[item.chainId] = item
        }

        let localMapping = localChains.reduce(into: [ChainModel.Id: ChainModel]()) { mapping, item in
            mapping[item.chainId] = item
        }

        let appOwnedChainIds = UniversalWalletRegistry.appOwnedProductionChains
            .map(\.chainId)
        let obsoleteAppOwnedAliases = localChains.filter { localItem in
            remoteMapping[localItem.chainId] == nil &&
                appOwnedChainIds.contains { appOwnedChainId in
                    UniversalWalletChainAccountSupport.chainId(
                        localItem.chainId,
                        matches: appOwnedChainId
                    )
                }
        }
        let obsoleteAppOwnedAliasIds = Set(
            obsoleteAppOwnedAliases.map(\.chainId)
        )

        var newOrUpdated: [ChainModel] = mergedRemoteChains.compactMap { remoteItem in
            if let localItem = localMapping[remoteItem.chainId] {
                return localItem != remoteItem ? remoteItem : nil
            } else {
                return remoteItem
            }
        }

        let disabledOmittedChains: [ChainModel] = localChains.compactMap {
            localItem -> ChainModel? in
            guard
                !localItem.chainId.hasPrefix(
                    ChainModelMapper.quarantinedChainIdentifierPrefix
                ),
                remoteMapping[localItem.chainId] == nil,
                !obsoleteAppOwnedAliasIds.contains(localItem.chainId),
                !localItem.disabled
            else {
                return nil
            }

            return localItem.replacingDisabled(true)
        }

        newOrUpdated.append(contentsOf: disabledOmittedChains)

        let syncChanges = SyncChanges(
            newOrUpdatedItems: newOrUpdated,
            removedItems: obsoleteAppOwnedAliases
        )
        handle(syncChanges: syncChanges)
    }

    static func preservingLocalNodePreferences(
        remoteChains: [ChainModel],
        localChains: [ChainModel]
    ) -> [ChainModel] {
        let localMapping = localChains.reduce(into: [ChainModel.Id: ChainModel]()) { mapping, chain in
            mapping[chain.chainId] = chain
        }

        return remoteChains.map { remoteChain in
            guard let localChain = localMapping[remoteChain.chainId] else {
                return remoteChain
            }

            let localCustomNodes = Set(
                (localChain.customNodes ?? []).filter {
                    ChainModelMapper.isUsableNodeURL($0.url)
                        && $0.name.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isNotEmpty
                        && ChainModelMapper
                        .isNodeCompatibleWithRuntime(
                            $0,
                            for: remoteChain
                        )
                }
            )
            let selectedNode: ChainNodeModel?

            if let localSelectedNode = localChain.selectedNode,
               ChainModelMapper.isNodeCompatibleWithRuntime(
                   localSelectedNode,
                   for: remoteChain
               ) {
                selectedNode = remoteChain.nodes.first {
                    $0.url == localSelectedNode.url
                } ?? localCustomNodes.first {
                    $0.url == localSelectedNode.url
                }
            } else {
                selectedNode = nil
            }

            return remoteChain
                .replacingCustomNodes(Array(localCustomNodes))
                .replacingSelectedNode(selectedNode)
        }
    }

    private func handle(syncChanges: SyncChanges) {
        let localSaveOperation = repository.saveOperation({
            syncChanges.newOrUpdatedItems
        }, {
            syncChanges.removedItems.map { $0.identifier }
        })

        localSaveOperation.completionBlock = { [weak self, weak localSaveOperation] in
            let result: Result<SyncChanges, Error>

            do {
                guard let localSaveOperation else {
                    throw BaseOperationError.parentOperationCancelled
                }

                _ = try localSaveOperation.extractNoCancellableResultData()
                result = .success(syncChanges)
            } catch {
                result = .failure(error)
            }

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.complete(result: result)
            }
        }

        operationQueue.addOperation(localSaveOperation)
    }

    private func fetchLocalData() throws -> [ChainModel] {
        guard let chainsUrl = Bundle.main.url(forResource: "chains", withExtension: "json") else {
            throw ChainSyncServiceError.missingLocalFile
        }

        let data = try Data(contentsOf: chainsUrl)
        return try JSONDecoder().decode([ChainModel].self, from: data)
    }

    private func complete(result: Result<SyncChanges, Error>) {
        switch result {
        case let .success(changes):
            if changes.newOrUpdatedItems.isNotEmpty {
                logger?.warning(
                    """
                    !!!! Make shure what chains.json was changed, if you see this message without chains.json changes, equatable ChainModel is broken !!!!
                    """
                )
                logger?.debug(
                    """
                    Sync completed: \(changes.newOrUpdatedItems.map { $0.name }) (new or updated)
                    """
                )
            }
            if changes.removedItems.isNotEmpty {
                logger?.debug(
                    """
                    Sync completed: \(changes.removedItems.map { $0.name }) (removed)
                    """
                )
            }

            mutex.lock()
            isSyncInFlight = false
            retryAttempt = 0
            mutex.unlock()

            let event = ChainSyncDidComplete(
                newOrUpdatedChains: changes.newOrUpdatedItems,
                removedChains: changes.removedItems
            )

            eventCenter.notify(with: event)
        case let .failure(error):
            logger?.error("Sync failed with error: \(error)")
            mutex.lock()
            let failedReservationIdentifier = reservationIdentifier
            isSyncInFlight = false
            isCooldownActive = false
            reservationIdentifier &+= 1
            mutex.unlock()
            stopCooldownTimer(
                forFailedReservation: failedReservationIdentifier
            )
            let event = ChainSyncDidFail(error: error)
            eventCenter.notify(with: event)

            retry()
        }
    }

    private func stopCooldownTimer(
        forFailedReservation failedReservationIdentifier: UInt
    ) {
        cooldownTimerQueue.async {
            self.mutex.lock()
            let shouldStopTimer =
                self.timerReservationIdentifier ==
                failedReservationIdentifier
            if shouldStopTimer {
                self.timerReservationIdentifier = nil
            }
            self.mutex.unlock()

            if shouldStopTimer {
                self.timer.stop()
            }
        }
    }

    private func retry() {
        mutex.lock()
        let currentRetryAttempt = retryAttempt
        mutex.unlock()

        if let nextDelay = retryStrategy.reconnectAfter(
            attempt: currentRetryAttempt
        ) {
            logger?.debug("Scheduling chain sync retry after \(nextDelay)")

            scheduler.notifyAfter(nextDelay)
        }
    }
}

extension ChainSyncService: ChainSyncServiceProtocol {
    func syncUp() {
        performSyncUpIfNeeded(
            cancelScheduledRetry: true,
            installApplicationDelegate: true
        )
    }
}

extension ChainSyncService: SchedulerDelegate {
    func didTrigger(scheduler _: SchedulerProtocol) {
        performSyncUpIfNeeded()
    }
}

extension ChainSyncService: CountdownTimerDelegate {
    func didStart(with _: TimeInterval) {}

    func didCountdown(remainedInterval _: TimeInterval) {}

    func didStop(with _: TimeInterval) {
        mutex.lock()
        defer { mutex.unlock() }

        guard case .stopped = timer.state else {
            return
        }

        guard timerReservationIdentifier == reservationIdentifier else {
            return
        }

        isCooldownActive = false
        timerReservationIdentifier = nil
    }
}

extension ChainSyncService: ApplicationHandlerDelegate {
    func didReceiveDidBecomeActive(notification _: Notification) {
        performSyncUpIfNeeded()
    }
}
