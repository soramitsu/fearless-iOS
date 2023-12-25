import Foundation
import RobinHood
import IrohaCrypto
import SSFUtils
import SSFModels

final class StakingAccountResolverV14: BaseStakingAccountResolver {
    override func resolveKeysAndSubscribe() {
        do {
            guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
                throw ChainRegistryError.runtimeMetadaUnavailable
            }

            let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

            let storageKeyFactory = StorageKeyFactory()

            let controllerOperation = MapKeyEncodingOperation(
                path: .controller,
                storageKeyFactory: storageKeyFactory,
                keyParams: [accountId]
            )

            let localKeyFactory = LocalStorageKeyFactory()
            let controllerLocalKey = try LocalStorageKeyFactory().createFromStoragePath(
                .controller,
                chainAssetKey: chainAsset.uniqueKey(accountId: accountId)
            )

            let ledgerOperation = MapKeyEncodingOperation(
                path: .stakingLedger,
                storageKeyFactory: storageKeyFactory,
                keyParams: [accountId]
            )

            let ledgerLocalKey = try localKeyFactory.createFromStoragePath(
                .stakingLedger,
                chainAssetKey: chainAsset.uniqueKey(accountId: accountId)
            )

            [controllerOperation, ledgerOperation].forEach { operation in
                operation.addDependency(codingFactoryOperation)

                operation.configurationBlock = {
                    do {
                        operation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
                    } catch {
                        operation.result = .failure(error)
                    }
                }
            }

            let syncOperation = Operation()
            syncOperation.addDependency(controllerOperation)
            syncOperation.addDependency(ledgerOperation)

            syncOperation.completionBlock = { [weak self] in
                do {
                    let controllerKey = try controllerOperation.extractNoCancellableResultData()[0]
                    let ledgerKey = try ledgerOperation.extractNoCancellableResultData()[0]

                    self?.subscribe(
                        with: SubscriptionStorageKeys(remote: controllerKey, local: controllerLocalKey),
                        ledgerKeys: SubscriptionStorageKeys(remote: ledgerKey, local: ledgerLocalKey)
                    )
                } catch {
                    self?.logger?.error("Did receiver error: \(error)")
                }
            }

            let operations = [codingFactoryOperation, controllerOperation, ledgerOperation, syncOperation]

            operationQueue.addOperations(operations, waitUntilFinished: false)

        } catch {
            logger?.error("Did receive error: \(error)")
        }
    }

    override func createDecodingWrapper(
        from updateData: StorageUpdateData,
        subscription: BaseStakingAccountResolver.Subscription
    ) -> CompoundOperationWrapper<BaseStakingAccountResolver.DecodedChanges> {
        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }

        let codingFactory = runtimeService.fetchCoderFactoryOperation()

        let controllerDecoding: BaseOperation<Data>? = createDecodingOperation(
            for: subscription.controller,
            path: .controller,
            updateData: updateData,
            coderOperation: codingFactory
        )
        controllerDecoding?.addDependency(codingFactory)

        let ledgerDecoding: BaseOperation<StakingLedger>? =
            createDecodingOperation(
                for: subscription.ledger,
                path: .stakingLedger,
                updateData: updateData,
                coderOperation: codingFactory
            )
        ledgerDecoding?.addDependency(codingFactory)

        let mapOperation = ClosureOperation<DecodedChanges> {
            let controller = (try controllerDecoding?.extractNoCancellableResultData())
            let ledger = try ledgerDecoding?.extractNoCancellableResultData()

            return DecodedChanges(controller: controller, ledger: ledger)
        }

        var dependencies: [Operation] = [codingFactory]

        if let operation = controllerDecoding {
            dependencies.append(operation)
        }

        if let operation = ledgerDecoding {
            dependencies.append(operation)
        }

        dependencies.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }
}
