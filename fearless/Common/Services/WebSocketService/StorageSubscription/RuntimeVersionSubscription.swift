// import Foundation
// import RobinHood
// import FearlessUtils
// import SoraKeystore
// import Rswift
//
// enum RuntimeVersionSubscriptionError: Error {
//    case skipUnchangedVersion
//    case unexpectedEmptyMetadata
// }
//
// final class RuntimeVersionSubscription: WebSocketSubscribing {
//    let chain: Chain
//    let storage: AnyDataProviderRepository<RuntimeMetadataItem>
//    let engine: JSONRPCEngine
//    let operationManager: OperationManagerProtocol
//    let logger: LoggerProtocol
//
//    private let dataOperationFactory = DataOperationFactory()
//
//    private var subscriptionId: UInt16?
//
//    init(
//        chain: Chain,
//        storage: AnyDataProviderRepository<RuntimeMetadataItem>,
//        engine: JSONRPCEngine,
//        operationManager: OperationManagerProtocol,
//        logger: LoggerProtocol
//    ) {
//        self.chain = chain
//        self.storage = storage
//        self.engine = engine
//        self.operationManager = operationManager
//        self.logger = logger
//
//        subscribe()
//    }
//
//    deinit {
//        unsubscribe()
//    }
//
//    private func subscribe() {
//        do {
//            let updateClosure: (RuntimeVersionUpdate) -> Void = { [weak self] update in
//                let runtimeVersion = update.params.result
//                self?.logger.debug("Did receive spec version: \(runtimeVersion.specVersion)")
//                self?.logger.debug("Did receive tx version: \(runtimeVersion.transactionVersion)")
//
//                self?.handle(runtimeVersion: runtimeVersion)
//            }
//
//            let failureClosure: (Error, Bool) -> Void = { [weak self] error, unsubscribed in
//                self?.logger.error("Did receive subscription error: \(error) \(unsubscribed)")
//            }
//
//            let params: [String] = []
//            subscriptionId = try engine.subscribe(
//                RPCMethod.runtimeVersionSubscribe,
//                params: params,
//                updateClosure: updateClosure,
//                failureClosure: failureClosure
//            )
//        } catch {
//            logger.error("Can't subscribe to storage: \(error)")
//        }
//    }
//
//    private func unsubscribe() {
//        if let identifier = subscriptionId {
//            engine.cancelForIdentifier(identifier)
//        }
//    }
//
//    private func handle(runtimeVersion: RuntimeVersion) {
//        let breakingUpgradeState = chain.metadataBreakingUpgradeState(for: runtimeVersion.specVersion)
//        var forceOverridesOperation: BaseOperation<Data>?
//        if case let .forceResponse(_, url) = breakingUpgradeState, let url = url {
//            forceOverridesOperation = dataOperationFactory.fetchData(from: url)
//        }
//
//        let fetchCurrentOperation = storage.fetchOperation(
//            by: chain.genesisHash,
//            options: RepositoryFetchOptions()
//        )
//
//        let metaOperation = createMetadataOperation(
//            dependingOn: fetchCurrentOperation,
//            runtimeVersion: runtimeVersion
//        )
//        metaOperation.addDependency(fetchCurrentOperation)
//
//        let saveOperation = createSaveOperation(
//            dependingOn: metaOperation,
//            runtimeOverrides: forceOverridesOperation,
//            runtimeVersion: runtimeVersion
//        )
//
//        if let forceOverridesOperation = forceOverridesOperation {
//            saveOperation.addDependency(forceOverridesOperation)
//        }
//        saveOperation.addDependency(metaOperation)
//
//        saveOperation.completionBlock = { [weak self] in
//            guard let strongSelf = self else { return }
//            do {
//                _ = try saveOperation
//                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
//                strongSelf.logger.debug("Did save runtime metadata:")
//                strongSelf.logger.debug("spec version: \(runtimeVersion.specVersion)")
//                strongSelf.logger.debug("transaction version: \(runtimeVersion.transactionVersion)")
//
//                switch breakingUpgradeState {
//                case let .applyTemporarySolution(_, breakingUpgrade):
//                    breakingUpgrade.temporarySolutionApplied(for: strongSelf.chain, value: true)
//                case let .overrideTemporarySolution(breakingUpgrade):
//                    breakingUpgrade.temporarySolutionApplied(for: strongSelf.chain, value: false)
//                default:
//                    break
//                }
//            } catch {
//                if let internalError = error as? RuntimeVersionSubscriptionError,
//                   internalError == RuntimeVersionSubscriptionError.skipUnchangedVersion {
//                    strongSelf.logger
//                        .debug("No need to update metadata for version \(runtimeVersion.specVersion)")
//                } else {
//                    strongSelf.logger.error("Did recieve error: \(error)")
//                }
//            }
//        }
//
//        let operations = [forceOverridesOperation, fetchCurrentOperation, metaOperation, saveOperation].compactMap { $0 }
//        operationManager.enqueue(operations: operations, in: .transient)
//    }
//
//    private func createMetadataOperation(
//        dependingOn localFetch: BaseOperation<RuntimeMetadataItem?>,
//        runtimeVersion: RuntimeVersion
//    ) -> BaseOperation<String> {
//        let breakingUpgradeState = chain.metadataBreakingUpgradeState(for: runtimeVersion.specVersion)
//
//        let parameters: [String]?
//        switch breakingUpgradeState {
//        case let .applyTemporarySolution(array, _):
//            parameters = array
//        default:
//            parameters = nil
//        }
//
//        let method = RPCMethod.getRuntimeMetadata
//        let metaOperation = JSONRPCOperation<[String], String>(
//            engine: engine,
//            method: method,
//            parameters: parameters
//        )
//
//        metaOperation.configurationBlock = {
//            do {
//                switch breakingUpgradeState {
//                case let .forceResponse(response, _):
//                    metaOperation.result = .success(response)
//                default:
//                    break
//                }
//
//                let currentItem = try localFetch
//                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
//
//                if let item = currentItem, item.version == runtimeVersion.specVersion {
//                    switch breakingUpgradeState {
//                    case .notAffected:
//                        metaOperation.result = .failure(RuntimeVersionSubscriptionError.skipUnchangedVersion)
//                    default:
//                        // Do not skip, proceed with update
//                        break
//                    }
//                }
//            } catch {
//                metaOperation.result = .failure(error)
//            }
//        }
//
//        return metaOperation
//    }
//
//    private func createSaveOperation(
//        dependingOn meta: BaseOperation<String>,
//        runtimeOverrides: BaseOperation<Data>?,
//        runtimeVersion: RuntimeVersion
//    ) -> BaseOperation<Void> {
//        storage.saveOperation({
//            let metadataHex = try meta
//                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
//            var rawMetadata = try Data(hexString: metadataHex)
//            let decoder = try ScaleDecoder(data: rawMetadata)
//            let metadata = try RuntimeMetadata(scaleDecoder: decoder)
//
//            func overridenRuntime() -> RuntimeMetadata? {
//                guard let data = try? runtimeOverrides?.extractResultData(),
//                      let overrides = try? JSONDecoder().decode(RuntimeOverrides.self, from: data),
//                      !overrides.modules.isEmpty,
//                      metadata.version < 14
//                else {
//                    return nil
//                }
//
//                typealias ModuleMetadata = RuntimeMetadataV1.ModuleMetadata
//                typealias ModuleConstantMetadata = RuntimeMetadataV1.ModuleConstantMetadata
//                typealias ExtrinsicMetadata = RuntimeMetadataV1.ExtrinsicMetadata
//                typealias StorageMetadata = RuntimeMetadataV1.StorageMetadata
//                typealias FunctionMetadata = RuntimeMetadataV1.FunctionMetadata
//                typealias EventMetadata = RuntimeMetadataV1.EventMetadata
//                typealias ErrorMetadata = RuntimeMetadataV1.ErrorMetadata
//
//                var modules: [ModuleMetadata] = []
//                for module in metadata.modules {
//                    guard let module = module as? ModuleMetadata else {
//                        assertionFailure()
//                        return nil
//                    }
//
//                    guard let override = overrides.modules.first(where: { $0.name == module.name }) else {
//                        modules.append(module)
//                        continue
//                    }
//
//                    var constants: [ModuleConstantMetadata] = []
//                    if let constantOverrides = override.constants {
//                        for constant in module.constants {
//                            guard let constant = constant as? ModuleConstantMetadata else {
//                                assertionFailure()
//                                return nil
//                            }
//
//                            guard let override = constantOverrides.first(where: { $0.name == constant.name }) else {
//                                constants.append(constant)
//                                continue
//                            }
//
//                            constants.append(ModuleConstantMetadata(
//                                name: constant.name,
//                                type: constant.type,
//                                value: (try? Data(hexString: override.value)) ?? constant.value,
//                                documentation: constant.documentation
//                            ))
//                        }
//                    } else {
//                        for constant in module.constants {
//                            guard let constant = constant as? ModuleConstantMetadata else {
//                                assertionFailure()
//                                return nil
//                            }
//
//                            constants.append(constant)
//                        }
//                    }
//
//                    guard let moduleStorage = module.storage as? StorageMetadata?,
//                          let moduleCalls = try? module.calls(using: metadata.schemaResolver) as? [FunctionMetadata]?,
//                          let moduleEvents = try? module.events(using: metadata.schemaResolver) as? [EventMetadata]?,
//                          let moduleErrors = try? module.errors(using: metadata.schemaResolver) as? [ErrorMetadata]
//                    else {
//                        assertionFailure()
//                        return nil
//                    }
//
//                    modules.append(ModuleMetadata(
//                        name: module.name,
//                        storage: moduleStorage,
//                        calls: moduleCalls,
//                        events: moduleEvents,
//                        constants: constants,
//                        errors: moduleErrors,
//                        index: override.index ?? module.index
//                    ))
//                }
//
//                guard let moduleExtrinsic = metadata.extrinsic as? ExtrinsicMetadata else {
//                    assertionFailure()
//                    return nil
//                }
//
//                return try? RuntimeMetadata.v1(modules: modules, extrinsic: moduleExtrinsic)
//            }
//
//            if let overriden = overridenRuntime() {
//                let encoder = ScaleEncoder()
//                try overriden.encode(scaleEncoder: encoder)
//                rawMetadata = encoder.encode()
//            }
//
//            let item = RuntimeMetadataItem(
//                chain: self.chain.genesisHash,
//                version: runtimeVersion.specVersion,
//                txVersion: runtimeVersion.transactionVersion,
//                metadata: rawMetadata
//            )
//
//            return [item]
//
//        }, { [] })
//    }
// }
//
//// MARK: - RuntimeMetadataBreakingUpgrade
//
// private protocol RuntimeMetadataBreakingUpgrade {
//    var versionIssueIntroduced: UInt32 { get }
//    var isFixed: Bool { get }
//    func blockHashForBackwardCompatibility(for chain: Chain) -> String?
//    func forcedResponse(for chain: Chain) -> String?
//    func overridesUrl(for chain: Chain) -> URL?
// }
//
// private extension RuntimeMetadataBreakingUpgrade {
//    /// Provides settings key only if block hash known
//    private func settingsKey(for chain: Chain) -> String? {
//        blockHashForBackwardCompatibility(for: chain).map {
//            "runtime.metadata.breaking.update.\(chain.rawValue).\($0)"
//        }
//    }
//
//    func isTemporarySolutionApplied(for chain: Chain) -> Bool {
//        settingsKey(for: chain).map {
//            SettingsManager.shared.bool(for: $0) ?? false
//        } ?? false
//    }
//
//    func temporarySolutionApplied(for chain: Chain, value: Bool) {
//        if let key = settingsKey(for: chain) {
//            SettingsManager.shared.set(value: value, for: key)
//        }
//    }
// }
//
//// MARK: - RuntimeOverrides
//
// private struct RuntimeOverrides: Decodable {
//    struct ModuleOverride: Decodable {
//        struct ConstantOverride: Decodable {
//            let name: String
//            let value: String
//        }
//
//        var name: String
//        let index: UInt8?
//        let constants: [ConstantOverride]?
//    }
//
//    let modules: [ModuleOverride]
// }
//
//// MARK: - Known RuntimeMetadataBreakingUpgrades
//
// private struct RuntimeMetadataV14BreakingUpdate: RuntimeMetadataBreakingUpgrade {
//    let versionIssueIntroduced: UInt32 = 9110
//    let isFixed = true
//
//    func blockHashForBackwardCompatibility(for chain: Chain) -> String? {
//        switch chain {
//        case .kusama: // block #9 624 000
//            return "0x331cd3019b10cb639b6855e10f411bce33e65c2d129381907ac69f62bc054df9"
//        case .polkadot: // block #7 227 700
//            return "0xe8af816df50b4cabb3f396b61d4574925b2aa6fae556626804aab22fea276234"
//        case .westend: // block #7 500 000
//            return "0xa300b367c112c55e137a6fbba806975910695057ed0f7a3e37ac2fcbe19d70c1"
//        default:
//            return nil
//        }
//    }
//
//    func forcedResponse(for chain: Chain) -> String? {
//        func asString(_ resource: FileResource) -> String? {
//            resource.path().map {
//                try? String(contentsOfFile: $0)
//            } ?? nil
//        }
//
//        switch chain {
//        case .polkadot:
//            return asString(R.file.polkadotV14Runtime)
//        default:
//            return nil
//        }
//    }
//
//    func overridesUrl(for chain: Chain) -> URL? {
//        switch chain {
//        case .polkadot:
//            return URL(string: "https://raw.githubusercontent.com/soramitsu/fearless-utils/crowdloands/moonbeam/scalecodec/type_registry/polkadot-overrides.json")
//        default:
//            return nil
//        }
//    }
// }
//
//// Should be pre-sorted in ascending order
//// Should be left for history purposes, never clear these
// private let knownRuntimeMetadataBreakingUpgrades: [RuntimeMetadataBreakingUpgrade] = [
//    RuntimeMetadataV14BreakingUpdate()
// ]
//
//// MARK: - RuntimeMetadataBreakingUpgradeState
//
// private enum RuntimeMetadataBreakingUpgradeState {
//    case applyTemporarySolution([String], RuntimeMetadataBreakingUpgrade)
//    case overrideTemporarySolution(RuntimeMetadataBreakingUpgrade)
//    case forceResponse(String, URL?)
//    case notAffected
// }
//
//// MARK: - Chain based breaking update fixes
//
// private extension Chain {
//    private var temporarySolutionApplied: RuntimeMetadataBreakingUpgrade? {
//        knownRuntimeMetadataBreakingUpgrades.first(where: { $0.isTemporarySolutionApplied(for: self) })
//    }
//
//    private func recentBreakingUpgrade(for version: UInt32) -> RuntimeMetadataBreakingUpgrade? {
//        knownRuntimeMetadataBreakingUpgrades
//            .filter { $0.versionIssueIntroduced <= version }
//            .last
//    }
//
//    func metadataBreakingUpgradeState(for version: UInt32) -> RuntimeMetadataBreakingUpgradeState {
//        guard let recent = recentBreakingUpgrade(for: version) else {
//            // No breaking changes known so far
//            return .notAffected
//        }
//
//        if !recent.isFixed, let response = recent.forcedResponse(for: self) {
//            return .forceResponse(response, recent.overridesUrl(for: self))
//        }
//
//        if let applied = temporarySolutionApplied {
//            if applied.versionIssueIntroduced == recent.versionIssueIntroduced {
//                if applied.isFixed {
//                    // Previously applied temporary solution no longer needed, as runtime parsing fixed
//                    return .overrideTemporarySolution(applied)
//                } // else issue not fixed, stick with applied solution
//            } else { // recent > applied, provide solution for recent version
//                // also reset applied state, so it no more recognized as applied
//                applied.temporarySolutionApplied(for: self, value: false)
//            }
//        }
//
//        guard !recent.isFixed, let blockHash = recent.blockHashForBackwardCompatibility(for: self) else {
//            // Recent breaking update already supported or no temporary solution known, do nothing
//            return .notAffected
//        }
//
//        // Apply fix from recent breaking upgrade
//        return .applyTemporarySolution([blockHash], recent)
//    }
// }
