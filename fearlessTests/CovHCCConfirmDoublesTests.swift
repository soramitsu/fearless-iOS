import BigInt
import IrohaCrypto
import RobinHood
import SoraKeystore
import SSFModels
import SSFRuntimeCodingService
import SSFUtils
import UIKit
import Web3
import XCTest
@testable import fearless

// Shared fixtures and doubles for the CrossChainConfirmation lane-H tests.

enum CovHCCConfirmFixture {
    static let liberlandId = ReviewedXcmRouteRegistry.liberlandChainId
    static let soraId = ReviewedXcmRouteRegistry.soraChainId

    private static var cachedChains: [ChainModel]?
    private static var cachedRuntime: (catalog: TypeRegistryCatalogProtocol, metadata: RuntimeMetadata)?

    static func registryChains() throws -> [ChainModel] {
        if let cachedChains { return cachedChains }
        let url = try XCTUnwrap(Bundle(for: CovHCCConfirmBundleToken.self).url(
            forResource: "chains_v13_owned_20261029", withExtension: "json", subdirectory: "Registry"
        ))
        let data = try Data(contentsOf: url)
        let chains: [ChainModel]
        if let decoded = try? JSONDecoder().decode([ChainModel].self, from: data) {
            chains = decoded
        } else {
            chains = try JSONDecoder().decode([ChainModel].self, from: ChainSyncService.coerceChainsPayloadForCompatibility(data))
        }
        cachedChains = chains
        return chains
    }

    static func liberland() throws -> ChainModel {
        try XCTUnwrap(registryChains().first { $0.chainId == liberlandId })
    }

    static func sora() throws -> ChainModel {
        try XCTUnwrap(registryChains().first { $0.chainId == soraId })
    }

    static func route(_ symbol: String) throws -> ReviewedXcmRouteDefinition {
        try XCTUnwrap(ReviewedXcmRouteRegistry.routes.first { $0.originSymbol == symbol })
    }

    static func context(_ definition: ReviewedXcmRouteDefinition) -> ReviewedCrossChainRouteContext {
        ReviewedCrossChainRouteContext(definition: definition, providerId: "sora-liberland-xcm")
    }

    static func origin(_ definition: ReviewedXcmRouteDefinition) throws -> ChainAsset {
        try XCTUnwrap(liberland().chainAssets.first { $0.asset.id == definition.originAssetId })
    }

    static func runtimeParts() throws -> (catalog: TypeRegistryCatalogProtocol, metadata: RuntimeMetadata) {
        if let cachedRuntime { return cachedRuntime }
        let bundle = Bundle(for: CovHCCConfirmBundleToken.self)
        let metadataURL = try XCTUnwrap(bundle.url(forResource: "liberland-metadata-spec34", withExtension: "hex", subdirectory: "Registry"))
        let typesURL = try XCTUnwrap(bundle.url(forResource: "liberland-chain-types-20261024", withExtension: "json", subdirectory: "Registry"))
        let hex = try String(contentsOf: metadataURL).trimmingCharacters(in: .whitespacesAndNewlines)
        let metadata = try RuntimeMetadata(scaleDecoder: try ScaleDecoder(data: try Data(hexStringSSF: hex)))
        var usedRuntimePaths = UsedRuntimePaths()
        let catalog = try TypeRegistryCatalog.createFromTypeDefinition(
            try JSONEncoder().encode(JSON.dictionaryValue(["types": .dictionaryValue([:])])),
            versioningData: try Data(contentsOf: typesURL),
            runtimeMetadata: metadata,
            usedRuntimePaths: usedRuntimePaths.usedRuntimePaths
        )
        cachedRuntime = (catalog, metadata)
        return (catalog, metadata)
    }

    static func coderFactory() throws -> RuntimeCoderFactoryProtocol {
        let parts = try runtimeParts()
        return CovHCCConfirmCoderFactory(catalog: parts.catalog, specVersion: 34, txVersion: 2, metadata: parts.metadata)
    }

    static func snapshot() throws -> RuntimeSnapshot {
        let parts = try runtimeParts()
        return RuntimeSnapshot(typeRegistryCatalog: parts.catalog, specVersion: 34, txVersion: 2, metadata: parts.metadata)
    }

    static func confirmationData(
        symbol: String = "LLD",
        wallet: MetaAccountModel = AccountGenerator.generateMetaAccount(),
        recipient: String = "recipient",
        destinationFee: Decimal = .zero,
        amount: BigUInt = 2_000_000_000_000
    ) throws -> CrossChainConfirmationData {
        let definition = try route(symbol)
        return CrossChainConfirmationData(
            wallet: wallet,
            originChainAsset: try origin(definition),
            destChainModel: try sora(),
            amount: amount,
            displayAmount: "2",
            originChainFee: BalanceViewModel(amount: "0.01", price: nil),
            destChainFee: BalanceViewModel(amount: "0", price: nil),
            destChainFeeDecimal: destinationFee,
            recipientAddress: recipient,
            reviewedRoute: context(definition)
        )
    }

    static func execution(
        call: ReviewedCrossChainRuntimeCall = .soraBridgeProxyBurn,
        asset: ReviewedCrossChainRuntimeAssetDescriptor = .soraAsset(currencyId: "0x0200000000000000000000000000000000000000000000000000000000000000"),
        network: ReviewedCrossChainSubNetwork = .kusama,
        recipient: ReviewedCrossChainRecipientDescriptor = .relay(accountNetwork: .kusama),
        callIndex: ReviewedCrossChainCallIndex? = ReviewedCrossChainCallIndex(palletIndex: 81, callIndex: 3)
    ) -> ReviewedCrossChainExecutionDescriptor {
        ReviewedCrossChainExecutionDescriptor(
            runtimeCall: call,
            asset: asset,
            destinationChainId: soraId,
            network: network,
            recipient: recipient,
            minimumAmount: nil,
            callIndex: callIndex
        )
    }

    static func definition(
        from base: ReviewedXcmRouteDefinition,
        execution: ReviewedCrossChainExecutionDescriptor
    ) -> ReviewedXcmRouteDefinition {
        ReviewedXcmRouteDefinition(
            originChainId: base.originChainId,
            originAssetId: base.originAssetId,
            xcmAssetId: base.xcmAssetId,
            originSymbol: base.originSymbol,
            originPrecision: base.originPrecision,
            destinationChainIds: base.destinationChainIds,
            minimumDisplay: base.minimumDisplay,
            feeDisplay: base.feeDisplay,
            estimatedTimeDisplay: base.estimatedTimeDisplay,
            warnings: base.warnings,
            execution: execution
        )
    }

    static func capability(specVersion: UInt32 = 34) -> ReviewedCrossChainRuntimeCapability {
        ReviewedCrossChainRuntimeCapability(
            moduleName: "SoraBridgeApp",
            callName: "burn",
            specVersion: specVersion,
            callIndex: ReviewedCrossChainCallIndex(palletIndex: 81, callIndex: 3)
        )
    }

    static func spin(timeout: TimeInterval = 3, until predicate: () -> Bool) {
        let deadline = Date().addingTimeInterval(timeout)
        while !predicate(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }
}

final class CovHCCConfirmBundleToken {}

enum CovHCCConfirmError: Error, Equatable {
    case stub
}

final class CovHCCConfirmCoderFactory: RuntimeCoderFactoryProtocol {
    private let catalog: TypeRegistryCatalogProtocol
    let specVersion: UInt32
    let txVersion: UInt32
    let metadata: RuntimeMetadata

    init(catalog: TypeRegistryCatalogProtocol, specVersion: UInt32, txVersion: UInt32, metadata: RuntimeMetadata) {
        self.catalog = catalog
        self.specVersion = specVersion
        self.txVersion = txVersion
        self.metadata = metadata
    }

    func createEncoder() -> DynamicScaleEncoding {
        DynamicScaleEncoder(registry: catalog, version: UInt64(specVersion))
    }

    func createDecoder(from data: Data) throws -> DynamicScaleDecoding {
        try DynamicScaleDecoder(data: data, registry: catalog, version: UInt64(specVersion))
    }
}

/// A runtime provider double: an optional snapshot and a coder factory or a failure.
final class CovHCCConfirmRuntime: SSFRuntimeCodingService.RuntimeProviderProtocol {
    var runtimeSpecVersion: RuntimeSpecVersion = .defaultVersion
    var snapshot: RuntimeSnapshot?
    var factory: RuntimeCoderFactoryProtocol?

    init(snapshot: RuntimeSnapshot? = nil, factory: RuntimeCoderFactoryProtocol? = nil) {
        self.snapshot = snapshot
        self.factory = factory
    }

    func setup() {}
    func setupHot() {}
    func cleanup() {}

    func readySnapshot() async throws -> RuntimeSnapshot {
        guard let snapshot else { throw CovHCCConfirmError.stub }
        return snapshot
    }

    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        let factory = factory
        return ClosureOperation {
            guard let factory else { throw CovHCCConfirmError.stub }
            return factory
        }
    }

    func fetchCoderFactory() async throws -> RuntimeCoderFactoryProtocol {
        guard let factory else { throw CovHCCConfirmError.stub }
        return factory
    }
}

/// Builds the app's runtime provider from a fixed snapshot, so `mutationAuthorizationSpecVersion` is answered.
final class CovHCCConfirmSnapshotFactory: fearless.RuntimeSnapshotFactoryProtocol {
    let snapshot: RuntimeSnapshot

    init(snapshot: RuntimeSnapshot) {
        self.snapshot = snapshot
    }

    func createRuntimeSnapshotWrapper(
        chainTypes _: Data,
        chainMetadata _: fearless.RuntimeMetadataItem,
        usedRuntimePaths _: [String: [String]]
    ) -> ClosureOperation<RuntimeSnapshot?> {
        let snapshot = snapshot
        return ClosureOperation { snapshot }
    }
}

/// A node that answers `chain_getBlockHash` with a scripted hash and fails everything else at once.
final class CovHCCConfirmEngine: JSONRPCEngine {
    var connectionName: String?
    var url: URL?
    var pendingEngineRequests: [JSONRPCRequest] { [] }

    var genesisHash: String?
    var throwsOnCall = false
    private let lock = NSLock()
    private var recordedMethods: [String] = []

    var methods: [String] {
        lock.lock()
        defer { lock.unlock() }
        return recordedMethods
    }

    func callMethod<P: Codable, T: Decodable>(
        _ method: String,
        params _: P?,
        options _: JSONRPCOptions,
        completion closure: ((Result<T, Error>) -> Void)?
    ) throws -> UInt16 {
        lock.lock()
        recordedMethods.append(method)
        lock.unlock()
        if throwsOnCall {
            throw CovHCCConfirmError.stub
        }
        guard method == RPCMethod.getBlockHash, let genesisHash else {
            closure?(.failure(JSONRPCEngineError.unknownError))
            return 0
        }
        let data = try JSONSerialization.data(withJSONObject: [genesisHash])
        closure?(Result { try JSONDecoder().decode([T].self, from: data)[0] })
        return 0
    }

    func subscribe<P: Codable, T: Decodable>(
        _: String,
        params _: P?,
        updateClosure _: @escaping (T) -> Void,
        failureClosure _: @escaping (Error, Bool) -> Void
    ) throws -> UInt16 {
        0
    }

    func addSubscription(_: JSONRPCSubscribing) {}
    func cancelForIdentifier(_: UInt16) {}
    func generateRequestId() -> UInt16 { 1 }
    func connectIfNeeded() {}
    func disconnectIfNeeded() {}
    func unsubsribe(_: UInt16) throws {}
}

final class CovHCCConfirmRegistry: ChainRegistryProtocol {
    var chains: [ChainModel.Id: ChainModel] = [:]
    var authorizationChains: [ChainModel.Id: ChainModel]?
    var runtime: RuntimeProviderProtocol?
    var connection: ChainConnection?

    init(chains: [ChainModel] = []) {
        self.chains = Dictionary(chains.map { ($0.chainId, $0) }, uniquingKeysWith: { first, _ in first })
    }

    var availableChainIds: Set<ChainModel.Id>? { Set(chains.keys) }
    var availableChains: [ChainModel] { Array(chains.values) }
    var chainsTypesMap: [String: Data] { [:] }
    func resetConnection(for _: ChainModel.Id) {}
    func retryConnection(for _: ChainModel.Id) {}
    func getConnection(for _: ChainModel.Id) -> ChainConnection? { connection }
    func getEthereumConnection(for _: ChainModel.Id) -> Web3.Eth? { nil }
    func getTonApiClientFactory() throws -> TonAPIClientFactory { throw CovHCCConfirmError.stub }
    func getRuntimeProvider(for _: ChainModel.Id) -> RuntimeProviderProtocol? { runtime }
    func getChain(for chainId: ChainModel.Id) -> ChainModel? { chains[chainId] }
    func getChainForMutationAuthorization(for chainId: ChainModel.Id) -> ChainModel? {
        (authorizationChains ?? chains)[chainId]
    }

    func chainsSubscribe(_: AnyObject, runningInQueue _: DispatchQueue, updateClosure _: @escaping ([DataProviderChange<ChainModel>]) -> Void) {}
    func chainsUnsubscribe(_: AnyObject) {}
    func syncUp() {}
    func performHotBoot() {}
    func performColdBoot() {}
    func subscribeToChains() {}
}

final class CovHCCConfirmKeystore: KeystoreProtocol {
    var hasKey: Bool
    var throwsOnCheck = false
    private(set) var checkedTags: [String] = []

    init(hasKey: Bool) {
        self.hasKey = hasKey
    }

    func addKey(_: Data, with _: String) throws {}
    func updateKey(_: Data, with _: String) throws {}
    func fetchKey(for _: String) throws -> Data { throw CovHCCConfirmError.stub }
    func checkKey(for identifier: String) throws -> Bool {
        checkedTags.append(identifier)
        if throwsOnCheck { throw CovHCCConfirmError.stub }
        return hasKey
    }

    func deleteKey(for _: String) throws {}
}

struct CovHCCConfirmGenesisReader: ReviewedCrossChainGenesisReading {
    let result: Result<String, Error>

    func genesisHash(connection _: JSONRPCEngine) async throws -> String {
        try result.get()
    }
}

struct CovHCCConfirmNegotiator: ReviewedCrossChainRuntimeNegotiating {
    let result: Result<ReviewedCrossChainRuntimeCapability, Error>

    func negotiate(
        runtime _: RuntimeProviderProtocol,
        descriptor _: ReviewedCrossChainExecutionDescriptor
    ) async throws -> ReviewedCrossChainRuntimeCapability {
        try result.get()
    }
}

final class CovHCCConfirmAccountInfoService: AccountInfoRemoteService {
    var infos: [ChainAssetId: AccountInfo?] = [:]
    var error: Error?
    private(set) var requests = 0

    func fetchAccountInfos(for _: ChainModel, wallet _: MetaAccountModel) async throws -> [ChainAssetId: AccountInfo?] {
        requests += 1
        if let error { throw error }
        return infos
    }

    func fetchAccountInfo(for chainAsset: ChainAsset, wallet _: MetaAccountModel) async throws -> AccountInfo? {
        if let error { throw error }
        return infos[chainAsset.chainAssetId] ?? nil
    }
}

final class CovHCCConfirmExtrinsicService: ExtrinsicServiceProtocol {
    var feeResult: Result<RuntimeDispatchInfo, Error> = .success(RuntimeDispatchInfo(feeValue: 7))
    var submitResult: Result<String, Error> = .success("subscription")
    var extrinsicHex: String? = "0x0102"
    private(set) var submitAndWatchCount = 0

    func estimateFee(_: @escaping ExtrinsicBuilderClosure, runningIn queue: DispatchQueue, completion completionClosure: @escaping EstimateFeeClosure) {
        let result = feeResult
        queue.async { completionClosure(result) }
    }

    func estimateFee(
        _: @escaping ExtrinsicBuilderIndexedClosure,
        runningIn queue: DispatchQueue,
        numberOfExtrinsics: Int,
        completion completionClosure: @escaping EstimateFeeIndexedClosure
    ) {
        let result = feeResult
        queue.async { completionClosure(Array(repeating: result, count: numberOfExtrinsics)) }
    }

    func submit(
        _: @escaping ExtrinsicBuilderClosure,
        signer _: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping ExtrinsicSubmitClosure
    ) {
        let result = submitResult
        queue.async { completionClosure(result) }
    }

    func submit(
        _: @escaping ExtrinsicBuilderIndexedClosure,
        signer _: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        numberOfExtrinsics: Int,
        completion completionClosure: @escaping ExtrinsicSubmitIndexedClosure
    ) {
        let result = submitResult
        queue.async { completionClosure(Array(repeating: result, count: numberOfExtrinsics)) }
    }

    func submitAndWatch(
        _: @escaping ExtrinsicBuilderClosure,
        signer _: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping ExtrinsicSubmitAndWatchClosure
    ) {
        submitAndWatchCount += 1
        let result = submitResult
        let hex = extrinsicHex
        queue.async { completionClosure(result, hex) }
    }
}

final class CovHCCConfirmSigner: SigningWrapperProtocol {
    let authorization: MutationOperationAuthorization?

    init(authorization: MutationOperationAuthorization?) {
        self.authorization = authorization
    }

    var mutationAuthorization: MutationOperationAuthorization? { authorization }

    func sign(_: Data) throws -> IRSignatureProtocol {
        throw CovHCCConfirmError.stub
    }
}

struct CovHCCConfirmWatcher: ReviewedCrossChainDispatchWatching {
    let result: ReviewedCrossChainDispatchOutcome

    func outcome(subscriptionId _: String, extrinsicHash _: String) async -> ReviewedCrossChainDispatchOutcome {
        result
    }
}

/// Runs an async throwing body on a task and spins the main run loop until it ends.
final class CovHCCConfirmAsyncBox<T> {
    private let lock = NSLock()
    private var stored: Result<T, Error>?

    var result: Result<T, Error>? {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    init(timeout: TimeInterval = 10, _ body: @escaping () async throws -> T) {
        Task {
            let value: Result<T, Error>
            do {
                value = .success(try await body())
            } catch {
                value = .failure(error)
            }
            self.lock.lock()
            self.stored = value
            self.lock.unlock()
        }
        CovHCCConfirmFixture.spin(timeout: timeout) { result != nil }
    }

    var error: Error? {
        guard case let .failure(error)? = result else { return nil }
        return error
    }

    var value: T? {
        guard case let .success(value)? = result else { return nil }
        return value
    }
}
