import Foundation
import RobinHood
import FearlessUtils

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
        let method = RPCMethod.getRuntimeMetadata
        let metaOperation = JSONRPCOperation<[String], String>(
            engine: engine,
            method: method
        )

        metaOperation.configurationBlock = {
            do {
                let currentItem = try localFetch
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                if let item = currentItem, item.version == runtimeVersion.specVersion {
                    metaOperation.result = .failure(RuntimeVersionSubscriptionError.skipUnchangedVersion)
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
