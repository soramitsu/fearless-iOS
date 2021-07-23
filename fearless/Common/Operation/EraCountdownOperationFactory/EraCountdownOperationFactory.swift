import RobinHood
import FearlessUtils
import SoraKeystore

protocol EraCountdownOperationFactoryProtocol {
    func fetchCountdownOperationWrapper() -> CompoundOperationWrapper<EraCountdown>
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
    func fetchCountdownOperationWrapper() -> CompoundOperationWrapper<EraCountdown> {
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
                keys: { [try keyFactory.key(from: .currentSessionIndex)] },
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: .currentSessionIndex
            )

        let currentSlotWrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<Slot>>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keys: { [try keyFactory.key(from: .currentSlot)] },
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: .currentSlot
            )

        let genesisSlotWrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<Slot>>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keys: { [try keyFactory.key(from: .genesisSlot)] },
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: .genesisSlot
            )

        let activeEraWrapper: CompoundOperationWrapper<[StorageResponse<ActiveEraInfo>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keys: { [try keyFactory.key(from: .activeEra)] },
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: .activeEra
            )

        let startSessionWrapper = createEraStartSessionIndex(
            dependingOn: activeEraWrapper.targetOperation,
            codingFactoryOperation: codingFactoryOperation
        )

        let dependencies = eraLengthWrapper.allOperations
            + sessionLengthWrapper.allOperations
            + blockTimeWrapper.allOperations
            + sessionIndexWrapper.allOperations
            + currentSlotWrapper.allOperations
            + genesisSlotWrapper.allOperations
            + activeEraWrapper.allOperations
            + startSessionWrapper.allOperations
        dependencies.forEach { $0.addDependency(codingFactoryOperation) }

        let mergeOperation = ClosureOperation<EraCountdown> {
            guard
                let activeEra = try? activeEraWrapper.targetOperation.extractNoCancellableResultData()
                .first?.value?.index,
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
                activeEra: activeEra,
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
