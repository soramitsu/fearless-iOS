import Foundation
import RobinHood
import SSFModels
import SSFRuntimeCodingService
import SSFUtils
import Web3
import XCTest
@testable import fearless

enum CovFBalError: Error {
    case expected
}

/// A 64-character hex chain id that no bundled or stored chain uses.
func covFBalChainId() -> String {
    (UUID().uuidString + UUID().uuidString).replacingOccurrences(of: "-", with: "").lowercased()
}

/// Runs the current run loop until `condition` holds or `timeout` passes.
@discardableResult
func covFBalEventually(timeout: TimeInterval = 4, _ condition: () -> Bool) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition(), Date() < deadline {
        RunLoop.current.run(until: Date().addingTimeInterval(0.02))
    }
    return condition()
}

/// Lets queued barrier writes and short tasks finish.
func covFBalSettle(_ seconds: TimeInterval = 0.25) {
    RunLoop.current.run(until: Date().addingTimeInterval(seconds))
}

enum CovFBalChains {
    static func asset(
        id: String = "0",
        type: SubstrateAssetType? = .normal,
        utility: Bool = true,
        currencyId: String? = nil,
        ethereumType: EthereumAssetType? = nil
    ) -> AssetModel {
        AssetModel(
            id: id, name: "Coverage", symbol: "COV", precision: 12, currencyId: currencyId,
            isUtility: utility, isNative: utility, staking: nil, type: type, ethereumType: ethereumType
        )
    }

    static func chain(
        id: String = covFBalChainId(),
        name: String = "Coverage Balance",
        assets: [AssetModel],
        options: [ChainOptions]? = nil
    ) -> ChainModel {
        ChainModel(
            rank: nil, disabled: false, chainId: id, parentId: nil, paraId: nil, name: name, assets: Set(assets),
            xcm: nil, nodes: [], addressPrefix: 42, icon: nil, options: options, iosMinAppVersion: nil, identityChain: nil
        )
    }

    static func chainAsset(
        _ model: AssetModel = CovFBalChains.asset(),
        chainId: String = covFBalChainId(),
        options: [ChainOptions]? = nil
    ) -> ChainAsset {
        ChainAsset(chain: CovFBalChains.chain(id: chainId, assets: [model], options: options), asset: model)
    }
}

enum CovFBalWallets {
    /// A wallet without any Substrate, Ethereum or chain account.
    static func empty() -> fearless.MetaAccountModel {
        fearless.MetaAccountModel(
            metaId: UUID().uuidString, name: "cov-f-bal", substrateAccountId: nil, substrateCryptoType: 0,
            substratePublicKey: nil, ethereumAddress: nil, ethereumPublicKey: nil, chainAccounts: [],
            assetKeysOrder: nil, canExportEthereumMnemonic: false, unusedChainIds: nil,
            selectedCurrency: Currency.defaultCurrency(), networkManagmentFilter: nil, assetsVisibility: [],
            hasBackup: false, favouriteChainIds: []
        )
    }

    static func withChainAccount(chainId: String, accountId: Data) -> fearless.MetaAccountModel {
        AccountGenerator.generateMetaAccount(with: [
            ChainAccountModel(chainId: chainId, accountId: accountId, publicKey: accountId, cryptoType: 0, ethereumBased: false)
        ])
    }
}

/// Runtime with the storage entries the remote subscription services encode keys for.
enum CovFBalRuntime {
    static func make() throws -> CovFRuntime {
        let modules = [
            module("System", [map("Account"), plain("Number")], index: 0),
            module("Balances", [plain("TotalIssuance")], index: 1),
            module("Staking", [
                plain("ActiveEra"), plain("CurrentEra"), plain("MinNominatorBond"), plain("MaxNominatorsCount"),
                plain("CounterForNominators"), map("Bonded"), map("Ledger")
            ], index: 2),
            module("NominationPools", [map("PoolMembers")], index: 3)
        ]
        let metadata = try RuntimeMetadata.v1(modules: modules, extrinsic: .init(version: 4, signedExtensions: []))
        let catalog = try TypeRegistryCatalog.createFromTypeDefinition(
            Data(#"{"types":{"AccountId":"[u8; 32]"}}"#.utf8), runtimeMetadata: metadata, usedRuntimePaths: [:]
        )
        return CovFRuntime(factory: TestRuntimeCoderFactory(catalog: catalog, specVersion: 1, txVersion: 1, metadata: metadata))
    }

    /// The hex storage key prefix (module + item hashes) of a storage item.
    static func prefix(_ module: String, _ item: String) throws -> String {
        try StorageKeyFactory().createStorageKey(moduleName: module, storageName: item).toHex(includePrefix: true)
    }

    private static func plain(_ name: String) -> RuntimeMetadataV1.StorageEntryMetadata {
        RuntimeMetadataV1.StorageEntryMetadata(
            name: name, modifier: .optional, type: .plain(PlainEntry(stringValue: "u32")), defaultValue: Data(), documentation: []
        )
    }

    private static func map(_ name: String) -> RuntimeMetadataV1.StorageEntryMetadata {
        RuntimeMetadataV1.StorageEntryMetadata(
            name: name, modifier: .optional,
            type: .map(MapEntry(hasher: .blake128Concat, key: "AccountId", value: "u32", unused: false)),
            defaultValue: Data(), documentation: []
        )
    }

    private static func module(
        _ name: String,
        _ entries: [RuntimeMetadataV1.StorageEntryMetadata],
        index: UInt8
    ) -> RuntimeMetadataV1.ModuleMetadata {
        RuntimeMetadataV1.ModuleMetadata(
            name: name, storage: .init(prefix: name, entries: entries), calls: nil, events: nil, constants: [], errors: [], index: index
        )
    }
}

/// Thread-safe JSON-RPC engine that records storage subscriptions and unsubscriptions.
final class CovFBalEngine: JSONRPCEngine {
    var connectionName: String?
    var url: URL?
    var pendingEngineRequests: [JSONRPCRequest] { [] }
    var subscribeError: Error?

    private let lock = NSLock()
    private var storedKeys: [[String]] = []
    private var storedUnsubscribed: [UInt16] = []
    private var identifier: UInt16 = 0

    var subscribedKeys: [[String]] {
        lock.lock()
        defer { lock.unlock() }
        return storedKeys
    }

    var unsubscribed: [UInt16] {
        lock.lock()
        defer { lock.unlock() }
        return storedUnsubscribed
    }

    func callMethod<P: Codable, T: Decodable>(
        _: String, params _: P?, options _: JSONRPCOptions, completion closure: ((Result<T, Error>) -> Void)?
    ) throws -> UInt16 {
        closure?(.failure(CovFBalError.expected))
        return generateRequestId()
    }

    func subscribe<P: Codable, T: Decodable>(
        _: String, params: P?, updateClosure _: @escaping (T) -> Void, failureClosure _: @escaping (Error, Bool) -> Void
    ) throws -> UInt16 {
        if let subscribeError {
            throw subscribeError
        }
        let keys = (params as? [[String]])?.first ?? []
        lock.lock()
        storedKeys.append(keys)
        lock.unlock()
        return generateRequestId()
    }

    func cancelForIdentifier(_: UInt16) {}

    func generateRequestId() -> UInt16 {
        lock.lock()
        defer { lock.unlock() }
        identifier += 1
        return identifier
    }

    func addSubscription(_: JSONRPCSubscribing) {}
    func reconnect(url: URL) { self.url = url }
    func connectIfNeeded() {}
    func disconnectIfNeeded() {}

    func unsubsribe(_ identifier: UInt16) throws {
        lock.lock()
        storedUnsubscribed.append(identifier)
        lock.unlock()
    }
}

final class CovFBalRegistry: ChainRegistryProtocolStub, @unchecked Sendable {
    var availableIds: Set<ChainModel.Id>?
    var runtime: RuntimeProviderProtocol?
    var connection: ChainConnection?
    var ethereum: Web3.Eth?

    private let lock = NSLock()
    private var storedRuntimeRequests: [ChainModel.Id] = []
    private var storedEthereumRequests: [ChainModel.Id] = []
    private var storedChainsClosure: (([DataProviderChange<ChainModel>]) -> Void)?
    private var storedUnsubscribeCount = 0

    var runtimeRequests: [ChainModel.Id] {
        lock.lock()
        defer { lock.unlock() }
        return storedRuntimeRequests
    }

    var ethereumRequests: [ChainModel.Id] {
        lock.lock()
        defer { lock.unlock() }
        return storedEthereumRequests
    }

    var chainsUnsubscribeCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return storedUnsubscribeCount
    }

    var hasChainsSubscription: Bool {
        lock.lock()
        defer { lock.unlock() }
        return storedChainsClosure != nil
    }

    func deliver(_ changes: [DataProviderChange<ChainModel>]) {
        lock.lock()
        let closure = storedChainsClosure
        lock.unlock()
        closure?(changes)
    }

    override var availableChainIds: Set<ChainModel.Id>? { availableIds }

    override func getRuntimeProvider(for chainId: ChainModel.Id) -> RuntimeProviderProtocol? {
        lock.lock()
        storedRuntimeRequests.append(chainId)
        lock.unlock()
        return runtime
    }

    override func getConnection(for _: ChainModel.Id) -> ChainConnection? { connection }

    override func getEthereumConnection(for chainId: ChainModel.Id) -> Web3.Eth? {
        lock.lock()
        storedEthereumRequests.append(chainId)
        lock.unlock()
        return ethereum
    }

    override func chainsSubscribe(
        _: AnyObject,
        runningInQueue _: DispatchQueue,
        updateClosure: @escaping ([DataProviderChange<ChainModel>]) -> Void
    ) {
        lock.lock()
        storedChainsClosure = updateClosure
        lock.unlock()
    }

    override func chainsUnsubscribe(_: AnyObject) {
        lock.lock()
        storedUnsubscribeCount += 1
        lock.unlock()
    }
}

final class CovFBalLogger: LoggerProtocol {
    private let lock = NSLock()
    private var storedErrors: [String] = []
    private var storedInfos: [String] = []
    var onError: ((String) -> Void)?

    var errors: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storedErrors
    }

    var infos: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storedInfos
    }

    func verbose(message _: String, file _: String, function _: String, line _: Int) {}
    func debug(message _: String, file _: String, function _: String, line _: Int) {}
    func warning(message _: String, file _: String, function _: String, line _: Int) {}
    func customError(error _: Error, file _: String, function _: String, line _: Int) {}

    func info(message: String, file _: String, function _: String, line _: Int) {
        lock.lock()
        storedInfos.append(message)
        lock.unlock()
    }

    func error(message: String, file _: String, function _: String, line _: Int) {
        lock.lock()
        storedErrors.append(message)
        let callback = onError
        lock.unlock()
        callback?(message)
    }
}

final class CovFBalEventCenter: EventCenterProtocol {
    private let lock = NSLock()
    private var storedEvents: [EventProtocol] = []
    private var storedObservers = 0
    var onNotify: ((EventProtocol) -> Void)?

    var events: [EventProtocol] {
        lock.lock()
        defer { lock.unlock() }
        return storedEvents
    }

    var addedObservers: Int {
        lock.lock()
        defer { lock.unlock() }
        return storedObservers
    }

    func notify(with event: EventProtocol) {
        lock.lock()
        storedEvents.append(event)
        let callback = onNotify
        lock.unlock()
        callback?(event)
    }

    func add(observer _: EventVisitorProtocol, dispatchIn _: DispatchQueue?) {
        lock.lock()
        storedObservers += 1
        lock.unlock()
    }

    func remove(observer _: EventVisitorProtocol) {}
}
