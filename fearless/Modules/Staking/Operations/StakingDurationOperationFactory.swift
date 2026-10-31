import Foundation
import RobinHood
import SSFRuntimeCodingService

struct StakingDuration {
    let session: TimeInterval
    let era: TimeInterval
    let unlocking: TimeInterval
}

protocol StakingDurationOperationFactoryProtocol {
    func createDurationOperation(
        from runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<StakingDuration>
}

final class StakingDurationOperationFactory: StakingDurationOperationFactoryProtocol {
    private let clock: StakingRuntimeClock

    init(clock: StakingRuntimeClock = StakingRuntimeClock()) {
        self.clock = clock
    }

    func createDurationOperation(
        from runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<StakingDuration> {
        let clockRuntime: RuntimeCodingServiceProtocol
        do {
            clockRuntime = try clock.runtime(for: runtimeService)
        } catch {
            return .createWithError(error)
        }
        let runtimeFactoryOperation = runtimeService.fetchCoderFactoryOperation()
        let clockFactoryOperation = clockRuntime.fetchCoderFactoryOperation()

        let unlockingOperation: BaseOperation<UInt32> = createConstOperation(
            dependingOn: runtimeFactoryOperation,
            path: .lockUpPeriod
        )

        let eraLengthOperation: BaseOperation<SessionIndex> = createConstOperation(
            dependingOn: runtimeFactoryOperation,
            path: .eraLength
        )

        let sessionLengthOperation: BaseOperation<SessionIndex> = createConstOperation(
            dependingOn: clockFactoryOperation,
            path: .sessionLength
        )

        let blockTimeOperation: BaseOperation<Moment> = createConstOperation(
            dependingOn: clockFactoryOperation,
            path: .babeBlockTime
        )

        let mergeOperation = ClosureOperation<StakingDuration> {
            let sessionLength = try sessionLengthOperation.extractNoCancellableResultData()
            let eraLength = try eraLengthOperation.extractNoCancellableResultData()
            let blockTime = try blockTimeOperation.extractNoCancellableResultData()
            let unlocking = try unlockingOperation.extractNoCancellableResultData()

            let sessionDuration = TimeInterval(sessionLength * blockTime).seconds
            let eraDuration = TimeInterval(eraLength) * sessionDuration
            let unlockingDuration = TimeInterval(unlocking) * eraDuration

            return StakingDuration(
                session: sessionDuration,
                era: eraDuration,
                unlocking: unlockingDuration
            )
        }

        let constOperations = [unlockingOperation, sessionLengthOperation,
                               eraLengthOperation, blockTimeOperation]

        constOperations.forEach { constOperation in
            constOperation.addDependency(runtimeFactoryOperation)
            constOperation.addDependency(clockFactoryOperation)
            mergeOperation.addDependency(constOperation)
        }

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: [runtimeFactoryOperation, clockFactoryOperation] + constOperations
        )
    }

    private func createConstOperation<T>(
        dependingOn runtimeFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        path: ConstantCodingPath
    ) -> PrimitiveConstantOperation<T> where T: LosslessStringConvertible {
        let operation = PrimitiveConstantOperation<T>(path: path)

        operation.configurationBlock = {
            do {
                operation.codingFactory = try runtimeFactoryOperation.extractNoCancellableResultData()
            } catch {
                operation.result = .failure(error)
            }
        }

        return operation
    }
}
