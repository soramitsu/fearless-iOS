import Foundation
import RobinHood

protocol NetworkStakingInfoOperationFactoryProtocol {
    func networkStakingOperation(
        for eraValidatorService: EraValidatorServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<NetworkStakingInfo>
}

class NetworkStakingInfoOperationFactory {
    let durationOperationFactory: StakingDurationOperationFactoryProtocol
    init(durationFactory: StakingDurationOperationFactoryProtocol = StakingDurationOperationFactory()) {
        durationOperationFactory = durationFactory
    }

    func createConstOperation<T>(
        dependingOn runtime: BaseOperation<RuntimeCoderFactoryProtocol>,
        path: ConstantCodingPath
    ) -> PrimitiveConstantOperation<T> where T: LosslessStringConvertible {
        let operation = PrimitiveConstantOperation<T>(path: path)

        operation.configurationBlock = {
            do {
                operation.codingFactory = try runtime.extractNoCancellableResultData()
            } catch {
                operation.result = .failure(error)
            }
        }

        return operation
    }
}
