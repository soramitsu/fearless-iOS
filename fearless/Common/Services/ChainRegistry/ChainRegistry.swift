import Foundation
import RobinHood
import SSFUtils
import SSFModels
import Web3
import SSFChainRegistry
import SSFRuntimeCodingService
import SSFChainConnection
import TonAPI
import OpenAPIRuntime
import HTTPTypes

enum TonAPITransportError: Error {
    case invalidRequestURL(path: String, method: HTTPRequest.Method, baseURL: URL)
    case notHTTPResponse(URLResponse)
}

private final class TonAPIURLSessionTransport: ClientTransport, @unchecked Sendable {
    private let session: URLSession

    init(configuration: URLSessionConfiguration = .default) {
        session = URLSession(configuration: configuration)
    }

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID _: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var urlRequest = try await URLRequest(request, body: body, baseURL: baseURL)
        urlRequest.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        let (data, response) = try await session.data(for: urlRequest)
        let httpResponse = try HTTPResponse.from(urlResponse: response)
        let responseBody: HTTPBody? = data.isEmpty ? nil : HTTPBody(data)
        return (httpResponse, responseBody)
    }
}

private struct TonAPIAuthorizationMiddleware: ClientMiddleware {
    let token: String

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID _: String,
        next: @Sendable(HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        guard !token.isEmpty else {
            return try await next(request, body, baseURL)
        }

        var authenticated = request
        authenticated.headerFields[.authorization] = "Bearer \(token)"
        return try await next(authenticated, body, baseURL)
    }
}

final class TonAPIClientFactory {
    private let tonAPIURL: URL
    private let token: String

    init(tonAPIURL: URL, token: String) {
        self.tonAPIURL = tonAPIURL
        self.token = token
    }

    func tonAPIClient() -> Client {
        let transport = TonAPIURLSessionTransport()
        let middlewares: [any ClientMiddleware] = token.isEmpty ? [] : [TonAPIAuthorizationMiddleware(token: token)]

        return Client(
            serverURL: tonAPIURL,
            transport: transport,
            middlewares: middlewares
        )
    }
}

private extension URLRequest {
    init(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL
    ) async throws {
        guard
            var baseURLComponents = URLComponents(string: baseURL.absoluteString),
            let requestURLComponents = URLComponents(string: request.path ?? "")
        else {
            throw TonAPITransportError.invalidRequestURL(
                path: request.path ?? "<nil>",
                method: request.method,
                baseURL: baseURL
            )
        }

        baseURLComponents.percentEncodedPath += requestURLComponents.percentEncodedPath
        baseURLComponents.percentEncodedQuery = requestURLComponents.percentEncodedQuery

        guard let resolvedURL = baseURLComponents.url else {
            throw TonAPITransportError.invalidRequestURL(
                path: request.path ?? "<nil>",
                method: request.method,
                baseURL: baseURL
            )
        }

        self.init(url: resolvedURL)
        httpMethod = request.method.rawValue

        for header in request.headerFields {
            setValue(header.value, forHTTPHeaderField: header.name.canonicalName)
        }

        if let body {
            httpBody = try await Data(collecting: body, upTo: .max)
        }
    }
}

private extension HTTPResponse {
    static func from(urlResponse: URLResponse) throws -> HTTPResponse {
        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw TonAPITransportError.notHTTPResponse(urlResponse)
        }

        var headers = HTTPFields()
        for (key, value) in httpResponse.allHeaderFields {
            guard
                let rawName = key as? String,
                let name = HTTPField.Name(rawName),
                let stringValue = value as? String
            else {
                continue
            }

            headers[name] = stringValue
        }

        return HTTPResponse(status: .init(code: httpResponse.statusCode), headerFields: headers)
    }
}

protocol ChainRegistryProtocol: AnyObject {
    var availableChainIds: Set<ChainModel.Id>? { get }
    var availableChains: [ChainModel] { get }
    var chainsTypesMap: [String: Data] { get }

    func resetConnection(for chainId: ChainModel.Id)
    func retryConnection(for chainId: ChainModel.Id)
    func getConnection(for chainId: ChainModel.Id) -> ChainConnection?
    func getEthereumConnection(for chainId: ChainModel.Id) -> Web3.Eth?
    func getTonApiClientFactory() throws -> TonAPIClientFactory
    func getRuntimeProvider(for chainId: ChainModel.Id) -> RuntimeProviderProtocol?
    func getChain(for chainId: ChainModel.Id) -> ChainModel?
    func chainsSubscribe(
        _ target: AnyObject,
        runningInQueue: DispatchQueue,
        updateClosure: @escaping ([DataProviderChange<ChainModel>]) -> Void
    )
    func chainsUnsubscribe(_ target: AnyObject)
    func syncUp()
    func performHotBoot()
    func performColdBoot()
    func subscribeToChains()
}

final class ChainRegistry {
    private let snapshotHotBootBuilder: SnapshotHotBootBuilderProtocol
    private let runtimeProviderPool: RuntimeProviderPoolProtocol
    private let connectionPools: [any ConnectionPoolProtocol]
    private let chainSyncService: ChainSyncServiceProtocol
    private let runtimeSyncService: RuntimeSyncServiceProtocol
    private let chainsTypesSyncService: ChainsTypesSyncServiceProtocol
    private let chainProvider: StreamableProvider<ChainModel>
    private let specVersionSubscriptionFactory: SpecVersionSubscriptionFactoryProtocol
    private let processingQueue = DispatchQueue(label: "jp.co.soramitsu.chain.registry")
    private let logger: LoggerProtocol?
    private let eventCenter: EventCenterProtocol
    private let networkIssuesCenter: NetworkIssuesCenterProtocol
    private let tonChainSelectionToggleSource: TonChainSelection.ToggleSource
    private lazy var readLock = ReaderWriterLock()

    private var substrateConnectionPool: ConnectionPool? {
        connectionPools.first(where: { $0 is ConnectionPool }) as? ConnectionPool
    }

    private var ethereumConnectionPool: EthereumConnectionPool? {
        connectionPools.first(where: { $0 is EthereumConnectionPool }) as? EthereumConnectionPool
    }

    // MARK: - State

    private var chains: [ChainModel] = []
    private(set) var chainsTypesMap: [String: Data] = [:]
    private var runtimeVersionSubscriptions: [ChainModel.Id: SpecVersionSubscriptionProtocol] = [:]
    private(set) var tonApiClientFactory: TonAPIClientFactory?
    private var tonApiChainId: ChainModel.Id?

    // MARK: - Constructor

    init(
        snapshotHotBootBuilder: SnapshotHotBootBuilderProtocol,
        runtimeProviderPool: RuntimeProviderPoolProtocol,
        connectionPools: [any ConnectionPoolProtocol],
        chainSyncService: ChainSyncServiceProtocol,
        runtimeSyncService: RuntimeSyncServiceProtocol,
        chainsTypesSyncService: ChainsTypesSyncServiceProtocol,
        chainProvider: StreamableProvider<ChainModel>,
        specVersionSubscriptionFactory: SpecVersionSubscriptionFactoryProtocol,
        networkIssuesCenter: NetworkIssuesCenterProtocol,
        logger: LoggerProtocol? = nil,
        eventCenter: EventCenterProtocol,
        tonChainSelectionToggleSource: TonChainSelection.ToggleSource = LocalToggleService.shared
    ) {
        self.snapshotHotBootBuilder = snapshotHotBootBuilder
        self.runtimeProviderPool = runtimeProviderPool
        self.connectionPools = connectionPools
        self.chainSyncService = chainSyncService
        self.runtimeSyncService = runtimeSyncService
        self.chainsTypesSyncService = chainsTypesSyncService
        self.chainProvider = chainProvider
        self.specVersionSubscriptionFactory = specVersionSubscriptionFactory
        self.networkIssuesCenter = networkIssuesCenter
        self.logger = logger
        self.eventCenter = eventCenter
        self.tonChainSelectionToggleSource = tonChainSelectionToggleSource
        self.eventCenter.add(observer: self, dispatchIn: .global())

        connectionPools.forEach { $0.setDelegate(self) }
    }

    // MARK: - Private handle subscription methods

    private func handleChainModel(_ changes: [DataProviderChange<ChainModel>]) {
        guard !changes.isEmpty else {
            return
        }

        readLock.exclusivelyWrite { [weak self] in
            guard let self else {
                return
            }

            changes.forEach { change in
                do {
                    switch change {
                    case let .insert(newChain):
                        try self.handleInsert(newChain)
                    case let .update(updatedChain):
                        let currentChain = self.chains.first { $0.chainId == updatedChain.chainId }
                        if let chain = currentChain,
                           chain.nodes != updatedChain.nodes || chain.selectedNode != updatedChain.selectedNode {
                            try self.handleUpdate(updatedChain)
                        }
                    case let .delete(chainId):
                        self.handleDelete(chainId)
                    }
                } catch {
                    let chainName = change.item?.name ?? "unknown"
                    self.logger?.error("Chain: \(chainName), Unexpected error on handling chains update: \(error)")
                }
            }

            self.eventCenter.notify(with: ChainsSetupCompleted())
        }
    }

    // MARK: - Private DataProviderChange handle methods

    private func handleInsert(_ chain: ChainModel) throws {
        switch chainKind(for: chain) {
        case .substrate:
            try handleNewSubstrateChain(newChain: chain)
        case .ethereum:
            try handleNewEthereumChain(newChain: chain)
        case .ton:
            handleTonChain(chain)
        }
    }

    private func handleUpdate(_ chain: ChainModel) throws {
        switch chainKind(for: chain) {
        case .substrate:
            try handleUpdatedSubstrateChain(updatedChain: chain)
        case .ethereum:
            try handleUpdatedEthereumChain(updatedChain: chain)
        case .ton:
            handleTonChain(chain)
        }
    }

    private func handleDelete(_ chainId: ChainModel.Id) {
        guard let removedChain = chains.first(where: { $0.chainId == chainId }) else {
            return
        }

        switch chainKind(for: removedChain) {
        case .substrate:
            handleDeletedSubstrateChain(chainId: chainId)
        case .ethereum:
            handleDeletedEthereumChain(chainId: chainId)
        case .ton:
            handleDeletedChain(chainId: chainId)
        }
    }

    // MARK: - Private substrate methods

    private func setupRuntimeVersionSubscription(for chain: ChainModel, connection: ChainConnection) {
        let subscription = specVersionSubscriptionFactory.createSubscription(
            for: chain.chainId,
            connection: connection
        )

        subscription.subscribe()

        runtimeVersionSubscriptions[chain.chainId] = subscription
    }

    private func clearRuntimeSubscription(for chainId: ChainModel.Id) {
        if let subscription = runtimeVersionSubscriptions[chainId] {
            subscription.unsubscribe()
        }

        runtimeVersionSubscriptions[chainId] = nil
    }

    private func handleNewSubstrateChain(newChain: ChainModel) throws {
        guard let substrateConnectionPool = self.substrateConnectionPool else {
            return
        }

        let connection = try substrateConnectionPool.setupConnection(for: newChain)
        let chainTypes = chainsTypesMap[newChain.chainId]

        runtimeProviderPool.setupRuntimeProvider(for: newChain, chainTypes: chainTypes)
        runtimeSyncService.register(chain: newChain, with: connection)
        setupRuntimeVersionSubscription(for: newChain, connection: connection)

        chains.append(newChain)
    }

    private func handleUpdatedSubstrateChain(updatedChain: ChainModel) throws {
        guard let substrateConnectionPool = self.substrateConnectionPool else {
            return
        }

        clearRuntimeSubscription(for: updatedChain.chainId)

        let connection = try substrateConnectionPool.setupConnection(for: updatedChain)
        let chainTypes = chainsTypesMap[updatedChain.chainId]

        runtimeProviderPool.setupRuntimeProvider(for: updatedChain, chainTypes: chainTypes)
        setupRuntimeVersionSubscription(for: updatedChain, connection: connection)

        chains = chains.filter { $0.chainId != updatedChain.chainId }
        chains.append(updatedChain)
    }

    private func handleDeletedSubstrateChain(chainId: ChainModel.Id) {
        runtimeProviderPool.destroyRuntimeProvider(for: chainId)
        clearRuntimeSubscription(for: chainId)
        runtimeSyncService.unregister(chainId: chainId)
        chains = chains.filter { $0.chainId != chainId }
    }

    private func resetSubstrateConnection(for chainId: ChainModel.Id) {
        guard let substrateConnectionPool = self.substrateConnectionPool else {
            return
        }

        substrateConnectionPool.resetConnection(for: chainId)
    }

    // MARK: - Private ethereum methods

    private func handleNewEthereumChain(newChain: ChainModel) throws {
        guard let ethereumConnectionPool = self.ethereumConnectionPool else {
            return
        }
        chains.append(newChain)

        do {
            _ = try ethereumConnectionPool.setupConnection(for: newChain)
        } catch {
            logger?.customError(error)
        }
    }

    private func handleUpdatedEthereumChain(updatedChain: ChainModel) throws {
        guard let ethereumConnectionPool = self.ethereumConnectionPool else {
            return
        }

        do {
            _ = try ethereumConnectionPool.setupConnection(for: updatedChain)
        } catch {
            logger?.customError(error)
        }

        chains = chains.filter { $0.chainId != updatedChain.chainId }
        chains.append(updatedChain)
    }

    private func handleDeletedEthereumChain(chainId: ChainModel.Id) {
        resetEthereumConnection(for: chainId)
        chains = chains.filter { $0.chainId != chainId }
    }

    private func resetEthereumConnection(for chainId: ChainModel.Id) {
        guard let ethereumConnectionPool else {
            return
        }

        ethereumConnectionPool.resetConnection(for: chainId)
    }

    private func handleTonChain(_ chain: ChainModel) {
        chains = chains.filter { $0.chainId != chain.chainId }
        chains.append(chain)

        let token = currentTonApiKey
        guard let node = Self.resolveTonNode(for: chain) else {
            logger?.error("Missing TON node URL")
            if tonApiChainId == chain.chainId {
                tonApiClientFactory = nil
                tonApiChainId = nil
            }
            return
        }

        guard shouldUseTonChain(chain) else {
            if tonApiChainId == chain.chainId {
                tonApiClientFactory = nil
                tonApiChainId = nil
            }
            return
        }

        tonApiClientFactory = TonAPIClientFactory(tonAPIURL: node.url, token: token)
        tonApiChainId = chain.chainId
    }

    static func resolveTonNode(for chain: ChainModel) -> ChainNodeModel? {
        chain.selectedNode ?? chain.nodes.sorted { $0.url.absoluteString < $1.url.absoluteString }.first
    }

    private var currentTonApiKey: String {
        #if DEBUG
            TonNodeApiKeyDebug.tonApiKey
        #else
            TonNodeApiKey.tonApiKey
        #endif
    }

    private func handleDeletedChain(chainId: ChainModel.Id) {
        chains = chains.filter { $0.chainId != chainId }
        if tonApiChainId == chainId {
            tonApiClientFactory = nil
            tonApiChainId = nil
        }
    }

    // MARK: - Private others methods

    private func syncUpServices() {
        chainSyncService.syncUp()
        chainsTypesSyncService.syncUp()
    }
}

// MARK: - ChainRegistryProtocol

extension ChainRegistry: ChainRegistryProtocol {
    var availableChainIds: Set<ChainModel.Id>? {
        readLock.concurrentlyRead {
            var availableIds = Set(runtimeVersionSubscriptions.keys)
            availableIds.formUnion(chains.filter { $0.isEthereum }.map(\.chainId))

            if let tonChainId = chains.first(where: shouldUseTonChain)?.chainId {
                availableIds.insert(tonChainId)
            }

            return availableIds
        }
    }

    var availableChains: [ChainModel] {
        readLock.concurrentlyRead {
            chains
        }
    }

    func performColdBoot() {
        subscribeToChains()
        syncUpServices()
    }

    func performHotBoot() {
        guard chains.isEmpty else { return }
        snapshotHotBootBuilder.startHotBoot()
    }

    func subscribeToChains() {
        let updateClosure: ([DataProviderChange<ChainModel>]) -> Void = { [weak self] changes in
            self?.handleChainModel(changes)
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.logger?.error("Unexpected error chains listener setup: \(error)")
        }

        let options = StreamableProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false,
            refreshWhenEmpty: false
        )

        chainProvider.removeObserver(self)

        chainProvider.addObserver(
            self,
            deliverOn: DispatchQueue.global(qos: .userInitiated),
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }

    func getConnection(for chainId: ChainModel.Id) -> ChainConnection? {
        guard let substrateConnectionPool = self.substrateConnectionPool else {
            return nil
        }

        return substrateConnectionPool.getConnection(for: chainId)
    }

    func getEthereumConnection(for chainId: ChainModel.Id) -> Web3.Eth? {
        readLock.concurrentlyRead {
            guard
                let ethereumConnectionPool = self.ethereumConnectionPool,
                let chain = chains.first(where: { $0.chainId == chainId })
            else {
                return nil
            }

            return try? ethereumConnectionPool.setupConnection(for: chain)
        }
    }

    func getChain(for chainId: ChainModel.Id) -> ChainModel? {
        readLock.concurrentlyRead { chains.first(where: { $0.chainId == chainId }) }
    }

    func getRuntimeProvider(for chainId: ChainModel.Id) -> RuntimeProviderProtocol? {
        runtimeProviderPool.getRuntimeProvider(for: chainId)
    }

    func getTonApiClientFactory() throws -> TonAPIClientFactory {
        let resolvedTonApiClientFactory = readLock.concurrentlyRead { () -> TonAPIClientFactory? in
            guard let selectedTonChain = chains.first(where: shouldUseTonChain) else {
                return nil
            }

            if tonApiChainId == selectedTonChain.chainId, let cachedTonApiClientFactory = self.tonApiClientFactory {
                return cachedTonApiClientFactory
            }

            guard let node = Self.resolveTonNode(for: selectedTonChain) else {
                logger?.error("Missing TON node URL")
                return nil
            }

            return TonAPIClientFactory(tonAPIURL: node.url, token: currentTonApiKey)
        }

        guard let resolvedTonApiClientFactory else {
            throw ChainRegistryError.connectionUnavailable
        }

        return resolvedTonApiClientFactory
    }

    func chainsSubscribe(
        _ target: AnyObject,
        runningInQueue: DispatchQueue,
        updateClosure: @escaping ([DataProviderChange<ChainModel>]) -> Void
    ) {
        let observerUpdateClosure = updateClosure
        let updateClosure: ([DataProviderChange<ChainModel>]) -> Void = { changes in
            runningInQueue.async {
                observerUpdateClosure(changes)
            }
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.logger?.error("Unexpected error chains listener setup: \(error)")
        }

        let options = StreamableProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false,
            refreshWhenEmpty: false
        )

        chainProvider.addObserver(
            target,
            deliverOn: processingQueue,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }

    func chainsUnsubscribe(_ target: AnyObject) {
        chainProvider.removeObserver(target)
    }

    func syncUp() {
        DispatchQueue.global().async {
            self.syncUpServices()
        }
    }

    func resetConnection(for chainId: ChainModel.Id) {
        guard let chain = chains.first(where: { $0.chainId == chainId }) else {
            return
        }

        switch chainKind(for: chain) {
        case .substrate:
            resetSubstrateConnection(for: chain.chainId)
        case .ethereum:
            resetEthereumConnection(for: chain.chainId)
        case .ton:
            break
        }
    }

    func retryConnection(for chainId: ChainModel.Id) {
        guard let currentConnection = getConnection(for: chainId) else {
            return
        }
        currentConnection.connectIfNeeded()
    }
}

private extension ChainRegistry {
    enum ChainKind {
        case substrate
        case ethereum
        case ton
    }

    func chainKind(for chain: ChainModel) -> ChainKind {
        if chain.isTonCompatibilityChain {
            return .ton
        }

        if chain.chainBaseType == .ethereum {
            return .ethereum
        }

        return .substrate
    }

    func shouldUseTonChain(_ chain: ChainModel) -> Bool {
        let isTestnetEnabled = tonChainSelectionToggleSource.tonEnvListToggle.storageValue
        return TonChainSelection.matchesSelectedEnvironment(chain: chain, isTestnetEnabled: isTestnetEnabled)
    }
}

// MARK: - ConnectionPoolDelegate

extension ChainRegistry: ConnectionPoolDelegate {
    func webSocketDidChangeState(chainId: SSFModels.ChainModel.Id, state: SSFUtils.WebSocketEngine.State) {
        guard let changedStateChain = chains.first(where: { chain in
            chain.chainId == chainId
        }) else {
            return
        }

        let reconnectedEvent = ChainReconnectingEvent(chain: changedStateChain, state: state)
        eventCenter.notify(with: reconnectedEvent)
    }
}

// MARK: - EventVisitorProtocol

extension ChainRegistry: EventVisitorProtocol {
    func processRuntimeChainsTypesSyncCompleted(event: RuntimeChainsTypesSyncCompleted) {
        chainsTypesMap = event.versioningMap
    }
}

// MARK: - SSF ChainRegistryProtocol adoptation

extension ChainRegistry: SSFChainRegistry.ChainRegistryProtocol {
    func getRuntimeProvider(
        chainId: SSFModels.ChainModel.Id,
        usedRuntimePaths _: [String: [String]],
        runtimeItem _: SSFModels.RuntimeMetadataItemProtocol?
    ) async throws -> SSFRuntimeCodingService.RuntimeProviderProtocol {
        guard let chain = chains.first(where: { $0.chainId == chainId }) else {
            throw ChainRegistryError.chainUnavailable(chainId: chainId)
        }
        let chainTypes = chainsTypesMap[chainId]

        let runtimeProvider = runtimeProviderPool.setupRuntimeProvider(for: chain, chainTypes: chainTypes)
        return runtimeProvider
    }

    func getSubstrateConnection(for chain: SSFModels.ChainModel) throws -> SSFChainConnection.SubstrateConnection {
        guard let substrateConnectionPool = self.substrateConnectionPool else {
            throw ChainRegistryError.connectionUnavailable
        }
        let connection = try substrateConnectionPool.setupConnection(for: chain)
        return connection
    }

    func getEthereumConnection(for chain: SSFModels.ChainModel) throws -> SSFChainConnection.Web3EthConnection {
        guard let ethereumConnectionPool = self.ethereumConnectionPool else {
            throw ChainRegistryError.connectionUnavailable
        }
        let connection = try ethereumConnectionPool.setupConnection(for: chain)
        return connection
    }

    func getChain(for chainId: SSFModels.ChainModel.Id) async throws -> SSFModels.ChainModel {
        let chain = readLock.concurrentlyRead { chains.first(where: { $0.chainId == chainId }) }

        guard let chain else {
            throw ChainRegistryError.chainUnavailable(chainId: chainId)
        }

        return chain
    }

    func getChains() async throws -> [SSFModels.ChainModel] {
        availableChains
    }

    func getReadySnapshot(
        chainId: SSFModels.ChainModel.Id,
        usedRuntimePaths _: [String: [String]],
        runtimeItem _: SSFModels.RuntimeMetadataItemProtocol?
    ) async throws -> SSFRuntimeCodingService.RuntimeSnapshot {
        guard let runtimeProvider = getRuntimeProvider(for: chainId) else {
            throw RuntimeProviderError.providerUnavailable
        }
        guard let runtimeSnapshot = runtimeProvider.snapshot else {
            let snapshot = try await runtimeProvider.readySnapshot()
            return snapshot
        }
        return runtimeSnapshot
    }
}
