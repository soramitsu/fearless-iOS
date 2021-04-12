import RobinHood
import FearlessUtils

struct PayoutFirstStepsResult {
    let currentEra: EraIndex
    let activeEra: EraIndex
    let historyDepth: UInt32
}

extension PayoutRewardsService {
    func createFetchFirstStepsOperation(
        engine: JSONRPCEngine,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) throws -> BaseOperation<PayoutFirstStepsResult> {
        let currentEra = createCurrentEraWrapper(
            engine: engine,
            codingFactory: { try codingFactoryOperation.extractNoCancellableResultData() }
        )
        currentEra.allOperations.forEach { $0.addDependency(codingFactoryOperation) }

        let activeEra = createActiveEraWrapper(
            engine: engine,
            codingFactory: { try codingFactoryOperation.extractNoCancellableResultData() }
        )
        activeEra.allOperations.forEach { $0.addDependency(codingFactoryOperation) }

        let historyDepth = createHistoryDepthWrapper(
            engine: engine,
            codingFactory: { try codingFactoryOperation.extractNoCancellableResultData() }
        )
        historyDepth.allOperations.forEach { $0.addDependency(codingFactoryOperation) }

        let mergeOperation = ClosureOperation<PayoutFirstStepsResult> {
            guard
                let currentEra = try currentEra.targetOperation.extractNoCancellableResultData()
                .first?.value?.value,
                let activeEra = try activeEra.targetOperation.extractNoCancellableResultData()
                .first?.value?.index,
                let historyDepth = try historyDepth.targetOperation.extractNoCancellableResultData()
                .first?.value?.value
            else {
                throw PayoutError.unknown
            }

            return PayoutFirstStepsResult(
                currentEra: currentEra,
                activeEra: activeEra,
                historyDepth: historyDepth
            )
        }

        currentEra.allOperations.forEach { mergeOperation.addDependency($0) }
        activeEra.allOperations.forEach { mergeOperation.addDependency($0) }
        historyDepth.allOperations.forEach { mergeOperation.addDependency($0) }

        return mergeOperation
    }

    private func createCurrentEraWrapper(
        engine: JSONRPCEngine,
        codingFactory: @escaping () throws -> RuntimeCoderFactoryProtocol
    ) -> CompoundOperationWrapper<[StorageResponse<StringScaleMapper<UInt32>>]> {
        let keyFactory = StorageKeyFactory()
        let requestFactory = StorageRequestFactory(remoteFactory: keyFactory)

        let queryWrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<UInt32>>]> =
            requestFactory.queryItems(
                engine: engine,
                keys: { [try keyFactory.currentEra()] },
                factory: codingFactory,
                storagePath: .currentEra
            )
        return queryWrapper
    }

    private func createActiveEraWrapper(
        engine: JSONRPCEngine,
        codingFactory: @escaping () throws -> RuntimeCoderFactoryProtocol
    ) -> CompoundOperationWrapper<[StorageResponse<ActiveEraInfo>]> {
        let keyFactory = StorageKeyFactory()
        let requestFactory = StorageRequestFactory(remoteFactory: keyFactory)

        return requestFactory.queryItems(
            engine: engine,
            keys: { [try keyFactory.activeEra()] },
            factory: codingFactory,
            storagePath: .activeEra
        )
    }

    private func createHistoryDepthWrapper(
        engine: JSONRPCEngine,
        codingFactory: @escaping () throws -> RuntimeCoderFactoryProtocol
    ) -> CompoundOperationWrapper<[StorageResponse<StringScaleMapper<UInt32>>]> {
        let keyFactory = StorageKeyFactory()
        let requestFactory = StorageRequestFactory(remoteFactory: keyFactory)

        return requestFactory.queryItems(
            engine: engine,
            keys: { [try keyFactory.historyDepth()] },
            factory: codingFactory,
            storagePath: .historyDepth
        )
    }
}
