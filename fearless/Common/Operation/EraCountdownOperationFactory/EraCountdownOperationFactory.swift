import RobinHood
import FearlessUtils
import SoraKeystore

protocol EraCountdownOperationFactoryProtocol {
    func fetchCountdownOperationWrapper(targetEra: EraIndex) -> CompoundOperationWrapper<EraCountdown>
}

enum EraCountdownOperationFactoryError: Error {
    case noData
}

final class EraCountdownOperationFactory: EraCountdownOperationFactoryProtocol {
    let runtimeCodingService: RuntimeCodingServiceProtocol
    let storageRequestFactory: StorageRequestFactoryProtocol
    let engine: JSONRPCEngine

    init(
        runtimeCodingService: RuntimeCodingServiceProtocol,
        storageRequestFactory: StorageRequestFactoryProtocol,
        engine: JSONRPCEngine
    ) {
        self.runtimeCodingService = runtimeCodingService
        self.storageRequestFactory = storageRequestFactory
        self.engine = engine
    }

    // swiftlint:disable function_body_length
    func fetchCountdownOperationWrapper(targetEra: EraIndex) -> CompoundOperationWrapper<EraCountdown> {
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

        let startSessionWrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<SessionIndex>>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keyParams: { [StringScaleMapper(value: targetEra)] },
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: .eraStartSessionIndex
            )

        let dependencies = eraLengthWrapper.allOperations
            + sessionLengthWrapper.allOperations
            + blockTimeWrapper.allOperations
            + sessionIndexWrapper.allOperations
            + currentSlotWrapper.allOperations
            + genesisSlotWrapper.allOperations
            + startSessionWrapper.allOperations
        dependencies.forEach { $0.addDependency(codingFactoryOperation) }

        let mergeOperation = ClosureOperation<EraCountdown> {
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
                throw EraCountdownOperationFactoryError.noData
            }

            return EraCountdown(
                eraLength: eraLength,
                sessionLength: sessionLength,
                eraStartSessionIndex: eraStartSessionIndex,
                currentSessionIndex: currentSessionIndex,
                currentSlot: currentSlot,
                genesisSlot: genesisSlot,
                blockCreationTime: babeBlockTime,
                createdAtDate: Date()
            )
        }

        dependencies.forEach { mergeOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: dependencies + [codingFactoryOperation]
        )
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
