import RobinHood
import FearlessUtils
import BigInt

struct PayoutFirstStepsResult {
    let currentEra: EraIndex
    let activeEra: EraIndex
    let historyDepth: UInt32
}

extension PayoutRewardsService {
    func createFetchFirstStepsOperation(
        engine: JSONRPCEngine,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) throws -> CompoundOperationWrapper<PayoutFirstStepsResult> {
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

        let res = CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: currentEra.allOperations + activeEra.allOperations + historyDepth.allOperations
        )
        return res
    }

    func createFetchTotalRewardOperation(
        dependingOn basedOperation: BaseOperation<PayoutFirstStepsResult>,
        engine: JSONRPCEngine,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) throws -> CompoundOperationWrapper<[EraIndex: BigUInt]> {
        let mapOperation = MapKeyEncodingOperation<String>(
            path: .totalValidatorReward,
            storageKeyFactory: StorageKeyFactory()
        )

        mapOperation.configurationBlock = {
            do {
                let result = try basedOperation.extractNoCancellableResultData()
                let eras = result.currentEra - result.historyDepth ... result.activeEra - 1
                mapOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
                mapOperation.keyParams = eras.map(\.description)
            } catch {
                mapOperation.result = .failure(error)
            }
        }

        let requestFactory = StorageRequestFactory(remoteFactory: StorageKeyFactory())

        let wrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<BigUInt>>]> =
            requestFactory.queryItems(
                engine: engine,
                keys: { try mapOperation.extractNoCancellableResultData() },
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: .totalValidatorReward
            )
        wrapper.allOperations.forEach { $0.addDependency(mapOperation) }

        let mergeOperation = ClosureOperation<[EraIndex: BigUInt]> {
            let result = try basedOperation.extractNoCancellableResultData()
            let eras = Array(result.currentEra - result.historyDepth ... result.activeEra - 1)
            let keys = try mapOperation.extractNoCancellableResultData()

            let results = try wrapper.targetOperation.extractNoCancellableResultData()
                .reduce(into: [EraIndex: BigUInt]()) { dict, item in
                    guard let eraIndex = keys.firstIndex(of: item.key) else {
                        return
                    }
                    guard let itemValue = item.value?.value else {
                        return
                    }

                    let era = eras[eraIndex]
                    dict[era] = itemValue
                }
            return results
        }
        wrapper.allOperations.forEach { mergeOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: [mapOperation] + wrapper.allOperations
        )
    }

    func createValidatorRewardPointsOperation(
        dependingOn baseOperation: BaseOperation<PayoutFirstStepsResult>,
        engine: JSONRPCEngine,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) throws -> CompoundOperationWrapper<[EraIndex: EraRewardPoints]> {
        let mapOperation = MapKeyEncodingOperation<String>(
            path: .rewardPointsPerValidator,
            storageKeyFactory: StorageKeyFactory()
        )

        mapOperation.configurationBlock = {
            do {
                let result = try baseOperation.extractNoCancellableResultData()
                let eras = result.currentEra - result.historyDepth ... result.activeEra - 1
                mapOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
                mapOperation.keyParams = eras.map(\.description)
            } catch {
                mapOperation.result = .failure(error)
            }
        }

        let requestFactory = StorageRequestFactory(remoteFactory: StorageKeyFactory())

        let wrapper: CompoundOperationWrapper<[StorageResponse<EraRewardPoints>]> =
            requestFactory.queryItems(
                engine: engine,
                keys: { try mapOperation.extractNoCancellableResultData() },
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: .rewardPointsPerValidator
            )
        wrapper.allOperations.forEach { $0.addDependency(mapOperation) }

        let mergeOperation = ClosureOperation<[EraIndex: EraRewardPoints]> {
            let result = try baseOperation.extractNoCancellableResultData()
            let eras = Array(result.currentEra - result.historyDepth ... result.activeEra - 1)
            let keys = try mapOperation.extractNoCancellableResultData()

            let results = try wrapper.targetOperation.extractNoCancellableResultData()
                .reduce(into: [EraIndex: EraRewardPoints]()) { dict, item in
                    guard let eraIndex = keys.firstIndex(of: item.key) else {
                        return
                    }
                    guard let itemValue = item.value else {
                        return
                    }

                    let era = eras[eraIndex]
                    dict[era] = itemValue
                }
            return results
        }
        wrapper.allOperations.forEach { mergeOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: [mapOperation] + wrapper.allOperations
        )
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
