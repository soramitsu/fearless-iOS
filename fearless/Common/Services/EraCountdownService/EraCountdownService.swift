import RobinHood
import FearlessUtils
import SoraKeystore

protocol EraCountdownServiceProtocol {
    func fetchCountdownOperationWrapper() -> CompoundOperationWrapper<EraCountdownSteps>
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

    func fetchCountdownOperationWrapper() -> CompoundOperationWrapper<EraCountdownSteps> {
        do {
            return try createStepsOperationWrapper()
//            let stepsOperation = try createStepsOperationWrapper()
//            let mapOperation = ClosureOperation<UInt64> {
//                let steps = try stepsOperation.targetOperation.extractNoCancellableResultData()
//                let time: UInt64 = 0
//                return time
//            }
//            stepsOperation.allOperations.forEach { mapOperation.addDependency($0) }
//
//            return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: stepsOperation.allOperations)
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }

    private func createStepsOperationWrapper() throws -> CompoundOperationWrapper<EraCountdownSteps> {
        let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()
        let keyFactory = StorageKeyFactory()

        let eraLengthWrapper: CompoundOperationWrapper<SessionIndex> = createFetchConstantOperation(
            for: .eraLength
        )

        let sessionLengthWrapper: CompoundOperationWrapper<SessionIndex> = createFetchConstantOperation(
            for: .sessionLength
        )

        let blockTimeWrapper: CompoundOperationWrapper<Moment> = createFetchConstantOperation(
            for: .babeBlockTime
        )

        let currentSessionIndexWrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<SessionIndex>>]> =
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

        let dependecies = eraLengthWrapper.allOperations
            + sessionLengthWrapper.allOperations
            + blockTimeWrapper.allOperations
//            + currentSessionIndexWrapper.allOperations
//            + currentSlotWrapper.allOperations
//            + genesisSlotWrapper.allOperations
//        dependecies.forEach { $0.addDependency(codingFactoryOperation) }

        let mergeOperation = ClosureOperation<EraCountdownSteps> {
            guard
                let eraLength = try? eraLengthWrapper.targetOperation.extractNoCancellableResultData(),
                let sessionLength = try? sessionLengthWrapper.targetOperation.extractNoCancellableResultData(),
                let babeBlockTime = try? blockTimeWrapper.targetOperation.extractNoCancellableResultData()
//                let currentSessionIndex = try? currentSessionIndexWrapper.targetOperation.extractNoCancellableResultData()
//                .first?.value?.value,
//                let currentSlot = try? currentSlotWrapper.targetOperation.extractNoCancellableResultData()
//                .first?.value?.value,
//                let genesisSlot = try? genesisSlotWrapper.targetOperation.extractNoCancellableResultData()
//                .first?.value?.value
            else {
                throw PayoutRewardsServiceError.unknown
            }

            return EraCountdownSteps(
                numberOfSessionsPerEra: eraLength,
                numberOfSlotsPerSession: sessionLength,
                eraStartSessionIndex: 0,
                currentSessionIndex: 0, // currentSessionIndex,
                currentSlot: 0, // currentSlot,
                genesisSlot: 0, // genesisSlot,
                blockCreationTime: babeBlockTime
            )
        }

        dependecies.forEach { mergeOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependecies)
    }

    private func createFetchConstantOperation<T: LosslessStringConvertible & Equatable>(
        for path: ConstantCodingPath
    ) -> CompoundOperationWrapper<T> {
        let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()
        let constOperation = PrimitiveConstantOperation<T>(path: path)
        constOperation.configurationBlock = {
            do {
                constOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                constOperation.result = .failure(error)
            }
        }

        constOperation.addDependency(codingFactoryOperation)

        return CompoundOperationWrapper(targetOperation: constOperation, dependencies: [codingFactoryOperation])
    }
}
