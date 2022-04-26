import Foundation
import RobinHood
import BigInt

final class ParachainStakingInfoOperationFactory: NetworkStakingInfoOperationFactory {
    private func createMapOperation(
        revokeDelegationDelayOperation: BaseOperation<UInt32>,
        minDelegationOperation: BaseOperation<BigUInt>
    ) -> BaseOperation<NetworkStakingInfo> {
        ClosureOperation<NetworkStakingInfo> {
            let revokeDelegationDelay = try revokeDelegationDelayOperation.extractNoCancellableResultData()
            let minDelegation = try minDelegationOperation.extractNoCancellableResultData()

            let baseStakingInfo = BaseStakingInfo(
                lockUpPeriod: revokeDelegationDelay,
                minimalBalance: minDelegation,
                minStakeAmongActiveNominators: minDelegation
            )

            return .parachain(
                baseInfo: baseStakingInfo
            )
        }
    }
}

extension ParachainStakingInfoOperationFactory: NetworkStakingInfoOperationFactoryProtocol {
    func networkStakingOperation(
        for _: EraValidatorServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<NetworkStakingInfo> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()

        let revokeDelegationDelayOperation: BaseOperation<UInt32> =
            createConstOperation(
                dependingOn: runtimeOperation,
                path: .revokeDelegationDelay
            )

        let minDelegationOperation: BaseOperation<BigUInt> =
            createConstOperation(
                dependingOn: runtimeOperation,
                path: .minDelegation
            )

        minDelegationOperation.addDependency(runtimeOperation)
        revokeDelegationDelayOperation.addDependency(runtimeOperation)

        let mapOperation = createMapOperation(
            revokeDelegationDelayOperation: revokeDelegationDelayOperation,
            minDelegationOperation: minDelegationOperation
        )

        let mapDependencies = [
            revokeDelegationDelayOperation,
            minDelegationOperation,
            runtimeOperation
        ]

        mapOperation.addDependency(revokeDelegationDelayOperation)
        mapOperation.addDependency(minDelegationOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: mapDependencies
        )
    }
}
