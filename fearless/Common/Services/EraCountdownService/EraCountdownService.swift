import RobinHood
import FearlessUtils
import SoraKeystore

protocol EraCountdownServiceProtocol {
    func fetchCountdownOperationWrapper() -> CompoundOperationWrapper<UInt64>
}

final class EraCountdownService: EraCountdownServiceProtocol {
    let chain: Chain
    let runtimeCodingService: RuntimeCodingServiceProtocol
    let storageRequestFactory: StorageRequestFactoryProtocol
    let engine: JSONRPCEngine

    init(
        chain: Chain,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        storageRequestFactory: StorageRequestFactoryProtocol,
        engine: JSONRPCEngine
    ) {
        self.chain = chain
        self.runtimeCodingService = runtimeCodingService
        self.storageRequestFactory = storageRequestFactory
        self.engine = engine
    }

    func fetchCountdownOperationWrapper() -> CompoundOperationWrapper<UInt64> {
        do {
            let stepsOperation = try createStepsOperationWrapper()
            let mapOperation = ClosureOperation<UInt64> {
                let steps = try stepsOperation.targetOperation.extractNoCancellableResultData()
                let time = self.calculateEraCompletionTime(steps: steps)
                return time
            }

            let dependencies = stepsOperation.allOperations
            dependencies.forEach { mapOperation.addDependency($0) }

            return CompoundOperationWrapper(
                targetOperation: mapOperation,
                dependencies: dependencies
            )
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }

    private func calculateEraCompletionTime(steps: EraCountdownSteps) -> UInt64 {
        let numberOfSlotsPerSession = UInt64(steps.sessionLength)
        let currentSessionIndex = UInt64(steps.currentSessionIndex)

        let sessionStartSlot = currentSessionIndex * numberOfSlotsPerSession + steps.genesisSlot
        let sessionProgress = steps.currentSlot - sessionStartSlot
        let eraProgress = (currentSessionIndex - UInt64(steps.eraStartSessionIndex)) * numberOfSlotsPerSession + sessionProgress
        let eraRemained = UInt64(steps.eraLength) * numberOfSlotsPerSession - eraProgress
        let result = eraRemained * UInt64(steps.blockCreationTime)
        return result
    }

    private func createStepsOperationWrapper() throws -> CompoundOperationWrapper<EraCountdownSteps> {
        let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()
        let keyFactory = StorageKeyFactory()

        let eraLengthWrapper: CompoundOperationWrapper<SessionIndex> = createFetchConstantWrapper(
            for: .eraLength,
            codingFactoryOperation: codingFactoryOperation
        )

        let sessionLengthWrapper: CompoundOperationWrapper<SessionIndex> = createFetchConstantWrapper(
            for: .sessionLength,
            codingFactoryOperation: codingFactoryOperation
        )

        let blockTimeWrapper: CompoundOperationWrapper<Moment> = createFetchConstantWrapper(
            for: .babeBlockTime,
            codingFactoryOperation: codingFactoryOperation
        )

        let sessionIndexWrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<SessionIndex>>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keys: { [try keyFactory.currentSessionIndex()] },
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: .currentSessionIndex
            )

        let currentSlotWrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<Slot>>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keys: { [try keyFactory.currentSlot()] },
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: .currentSlot
            )

        let genesisSlotWrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<Slot>>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keys: { [try keyFactory.genesisSlot()] },
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: .genesisSlot
            )

        let activeEraWrapper: CompoundOperationWrapper<[StorageResponse<ActiveEraInfo>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keys: { [try keyFactory.activeEra()] },
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: .activeEra
            )

        let startSessionWrapper = createEraStartSessionIndex(
            dependingOn: activeEraWrapper.targetOperation,
            codingFactoryOperation: codingFactoryOperation
        )

        let dependecies = eraLengthWrapper.allOperations
            + sessionLengthWrapper.allOperations
            + blockTimeWrapper.allOperations
            + sessionIndexWrapper.allOperations
            + currentSlotWrapper.allOperations
            + genesisSlotWrapper.allOperations
            + activeEraWrapper.allOperations
            + startSessionWrapper.allOperations
        dependecies.forEach { $0.addDependency(codingFactoryOperation) }

        let mergeOperation = ClosureOperation<EraCountdownSteps> {
            guard
                let eraLength = try? eraLengthWrapper.targetOperation.extractNoCancellableResultData(),
                let sessionLength = try? sessionLengthWrapper.targetOperation.extractNoCancellableResultData(),
                let babeBlockTime = try? blockTimeWrapper.targetOperation.extractNoCancellableResultData(),
                let currentSessionIndex = try? sessionIndexWrapper.targetOperation
                .extractNoCancellableResultData().first?.value?.value,
                let currentSlot = try? currentSlotWrapper.targetOperation
                .extractNoCancellableResultData().first?.value?.value,
                let genesisSlot = try? genesisSlotWrapper.targetOperation
                .extractNoCancellableResultData().first?.value?.value,
                let eraStartSessionIndex = try? startSessionWrapper.targetOperation
                .extractNoCancellableResultData().first?.value?.value
            else {
                throw PayoutRewardsServiceError.unknown
            }

            return EraCountdownSteps(
                eraLength: eraLength,
                sessionLength: sessionLength,
                eraStartSessionIndex: eraStartSessionIndex,
                currentSessionIndex: currentSessionIndex,
                currentSlot: currentSlot,
                genesisSlot: genesisSlot,
                blockCreationTime: babeBlockTime
            )
        }

        dependecies.forEach { mergeOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: dependecies + [codingFactoryOperation]
        )
    }

    private func createEraStartSessionIndex(
        dependingOn activeEra: BaseOperation<[StorageResponse<ActiveEraInfo>]>,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<[StorageResponse<StringScaleMapper<SessionIndex>>]> {
        let keyParams: () throws -> [StringScaleMapper<EraIndex>] = {
            let activeEraIndex = try activeEra.extractNoCancellableResultData().first?.value?.index ?? 0
            return [StringScaleMapper(value: activeEraIndex)]
        }

        let wrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<SessionIndex>>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keyParams: keyParams,
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: .eraStartSessionIndex
            )
        wrapper.addDependency(operations: [activeEra])

        return wrapper
    }

    private func createFetchConstantWrapper<T: LosslessStringConvertible & Equatable>(
        for path: ConstantCodingPath,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<T> {
        let constOperation = PrimitiveConstantOperation<T>(path: path)
        constOperation.configurationBlock = {
            do {
                constOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                constOperation.result = .failure(error)
            }
        }

        return CompoundOperationWrapper(targetOperation: constOperation)
    }
}
