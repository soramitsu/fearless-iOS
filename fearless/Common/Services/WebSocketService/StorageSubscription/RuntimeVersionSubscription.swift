import Foundation
import RobinHood
import FearlessUtils
import SoraKeystore

enum RuntimeVersionSubscriptionError: Error {
    case skipUnchangedVersion
    case unexpectedEmptyMetadata
}

final class RuntimeVersionSubscription: WebSocketSubscribing {
    let chain: Chain
    let storage: AnyDataProviderRepository<RuntimeMetadataItem>
    let engine: JSONRPCEngine
    let operationManager: OperationManagerProtocol
    let logger: LoggerProtocol

    private var subscriptionId: UInt16?

    init(
        chain: Chain,
        storage: AnyDataProviderRepository<RuntimeMetadataItem>,
        engine: JSONRPCEngine,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.chain = chain
        self.storage = storage
        self.engine = engine
        self.operationManager = operationManager
        self.logger = logger

        subscribe()
    }

    deinit {
        unsubscribe()
    }

    private func subscribe() {
        do {
            let updateClosure: (RuntimeVersionUpdate) -> Void = { [weak self] update in
                let runtimeVersion = update.params.result
                self?.logger.debug("Did receive spec version: \(runtimeVersion.specVersion)")
                self?.logger.debug("Did receive tx version: \(runtimeVersion.transactionVersion)")

                self?.handle(runtimeVersion: runtimeVersion)
            }

            let failureClosure: (Error, Bool) -> Void = { [weak self] error, unsubscribed in
                self?.logger.error("Did receive subscription error: \(error) \(unsubscribed)")
            }

            let params: [String] = []
            subscriptionId = try engine.subscribe(
                RPCMethod.runtimeVersionSubscribe,
                params: params,
                updateClosure: updateClosure,
                failureClosure: failureClosure
            )
        } catch {
            logger.error("Can't subscribe to storage: \(error)")
        }
    }

    private func unsubscribe() {
        if let identifier = subscriptionId {
            engine.cancelForIdentifier(identifier)
        }
    }

    private func handle(runtimeVersion: RuntimeVersion) {
        let fetchCurrentOperation = storage.fetchOperation(
            by: chain.genesisHash,
            options: RepositoryFetchOptions()
        )

        let metaOperation = createMetadataOperation(
            dependingOn: fetchCurrentOperation,
            runtimeVersion: runtimeVersion
        )
        metaOperation.addDependency(fetchCurrentOperation)

        let saveOperation = createSaveOperation(
            dependingOn: metaOperation,
            runtimeVersion: runtimeVersion
        )
        saveOperation.addDependency(metaOperation)

        saveOperation.completionBlock = {
            do {
                _ = try saveOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                self.logger.debug("Did save runtime metadata:")
                self.logger.debug("spec version: \(runtimeVersion.specVersion)")
                self.logger.debug("transaction version: \(runtimeVersion.transactionVersion)")

                let breakingUpgradeState = self.chain.metadataBreakingUpgradeState(for: runtimeVersion.specVersion)
                switch breakingUpgradeState {
                case let .applyTemporarySolution(_, breakingUpgrade):
                    breakingUpgrade.temporarySolutionApplied(for: self.chain, value: true)
                case let .overrideTemporarySolution(breakingUpgrade):
                    breakingUpgrade.temporarySolutionApplied(for: self.chain, value: false)
                default:
                    break
                }
            } catch {
                if let internalError = error as? RuntimeVersionSubscriptionError,
                   internalError == RuntimeVersionSubscriptionError.skipUnchangedVersion {
                    self.logger
                        .debug("No need to update metadata for version \(runtimeVersion.specVersion)")
                } else {
                    self.logger.error("Did recieve error: \(error)")
                }
            }
        }

        operationManager.enqueue(
            operations: [fetchCurrentOperation, metaOperation, saveOperation],
            in: .transient
        )
    }

    private func createMetadataOperation(
        dependingOn localFetch: BaseOperation<RuntimeMetadataItem?>,
        runtimeVersion: RuntimeVersion
    ) -> BaseOperation<String> {
        let breakingUpgradeState = chain.metadataBreakingUpgradeState(for: runtimeVersion.specVersion)

        let parameters: [String]?
        switch breakingUpgradeState {
        case let .applyTemporarySolution(array, _):
            parameters = array
        default:
            parameters = nil
        }

        let method = RPCMethod.getRuntimeMetadata
        let metaOperation = JSONRPCOperation<[String], String>(
            engine: engine,
            method: method,
            parameters: parameters
        )

        metaOperation.configurationBlock = {
            do {
                switch breakingUpgradeState {
                case let .forceResponse(response):
                    metaOperation.result = .success(response)
                default:
                    break
                }

                let currentItem = try localFetch
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

                if let item = currentItem, item.version == runtimeVersion.specVersion {
                    switch breakingUpgradeState {
                    case .notAffected:
                        metaOperation.result = .failure(RuntimeVersionSubscriptionError.skipUnchangedVersion)
                    default:
                        // Do not skip, proceed with update
                        break
                    }
                }
            } catch {
                metaOperation.result = .failure(error)
            }
        }

        return metaOperation
    }

    private func createSaveOperation(
        dependingOn meta: BaseOperation<String>,
        runtimeVersion: RuntimeVersion
    ) -> BaseOperation<Void> {
        storage.saveOperation({
            let metadataHex = try meta
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            let rawMetadata = try Data(hexString: metadataHex)
            let decoder = try ScaleDecoder(data: rawMetadata)
            _ = try RuntimeMetadata(scaleDecoder: decoder)

            let item = RuntimeMetadataItem(
                chain: self.chain.genesisHash,
                version: runtimeVersion.specVersion,
                txVersion: runtimeVersion.transactionVersion,
                metadata: rawMetadata
            )

            return [item]

        }, { [] })
    }
}

// MARK: - RuntimeMetadataBreakingUpgrade

private protocol RuntimeMetadataBreakingUpgrade {
    var versionIssueIntroduced: UInt32 { get }
    var isFixed: Bool { get }
    func blockHashForBackwardCompatibility(for chain: Chain) -> String?
    func forcedResponse(for chain: Chain) -> String?
}

private extension RuntimeMetadataBreakingUpgrade {
    /// Provides settings key only if block hash known
    private func settingsKey(for chain: Chain) -> String? {
        blockHashForBackwardCompatibility(for: chain).map {
            "runtime.metadata.breaking.update.\(chain.rawValue).\($0)"
        }
    }

    func isTemporarySolutionApplied(for chain: Chain) -> Bool {
        settingsKey(for: chain).map {
            SettingsManager.shared.bool(for: $0) ?? false
        } ?? false
    }

    func temporarySolutionApplied(for chain: Chain, value: Bool) {
        if let key = settingsKey(for: chain) {
            SettingsManager.shared.set(value: value, for: key)
        }
    }
}

// MARK: - Known RuntimeMetadataBreakingUpgrades

private struct RuntimeMetadataV14BreakingUpdate: RuntimeMetadataBreakingUpgrade {
    let versionIssueIntroduced: UInt32 = 9110
    let isFixed = false

    func blockHashForBackwardCompatibility(for chain: Chain) -> String? {
        switch chain {
        case .kusama: // block #9 624 000
            return "0x331cd3019b10cb639b6855e10f411bce33e65c2d129381907ac69f62bc054df9"
        case .polkadot: // block #7 227 700
            return "0xe8af816df50b4cabb3f396b61d4574925b2aa6fae556626804aab22fea276234"
        case .westend: // block #7 500 000
            return "0xa300b367c112c55e137a6fbba806975910695057ed0f7a3e37ac2fcbe19d70c1"
        default:
            return nil
        }
    }

    func forcedResponse(for chain: Chain) -> String? {
        switch chain {
        #if F_DEV
            case .moonbeam:
                return R.file.moonbeamTestNodeRuntime.path().map {
                    try? String(contentsOfFile: $0)
                } ?? nil
        #endif
        default:
            return nil
        }
    }
}

// Should be pre-sorted in ascending order
// Should be left for history purposes, never clear these
private let knownRuntimeMetadataBreakingUpgrades: [RuntimeMetadataBreakingUpgrade] = [
    RuntimeMetadataV14BreakingUpdate()
]

// MARK: - RuntimeMetadataBreakingUpgradeState

private enum RuntimeMetadataBreakingUpgradeState {
    case applyTemporarySolution([String], RuntimeMetadataBreakingUpgrade)
    case overrideTemporarySolution(RuntimeMetadataBreakingUpgrade)
    case forceResponse(String)
    case notAffected
}

// MARK: - Chain based breaking update fixes

private extension Chain {
    private var temporarySolutionApplied: RuntimeMetadataBreakingUpgrade? {
        knownRuntimeMetadataBreakingUpgrades.first(where: { $0.isTemporarySolutionApplied(for: self) })
    }

    private func recentBreakingUpgrade(for version: UInt32) -> RuntimeMetadataBreakingUpgrade? {
        knownRuntimeMetadataBreakingUpgrades
            .filter { $0.versionIssueIntroduced <= version }
            .last
    }

    func metadataBreakingUpgradeState(for version: UInt32) -> RuntimeMetadataBreakingUpgradeState {
        guard let recent = recentBreakingUpgrade(for: version) else {
            // No breaking changes known so far
            return .notAffected
        }

        if let response = recent.forcedResponse(for: self) {
            return .forceResponse(response)
        }

        if let applied = temporarySolutionApplied {
            if applied.versionIssueIntroduced == recent.versionIssueIntroduced {
                if applied.isFixed {
                    // Previously applied temporary solution no longer needed, as runtime parsing fixed
                    return .overrideTemporarySolution(applied)
                } // else issue not fixed, stick with applied solution
            } else { // recent > applied, provide solution for recent version
                // also reset applied state, so it no more recognized as applied
                applied.temporarySolutionApplied(for: self, value: false)
            }
        }

        guard !recent.isFixed, let blockHash = recent.blockHashForBackwardCompatibility(for: self) else {
            // Recent breaking update already supported or no temporary solution known, do nothing
            return .notAffected
        }

        // Apply fix from recent breaking upgrade
        return .applyTemporarySolution([blockHash], recent)
    }
}
