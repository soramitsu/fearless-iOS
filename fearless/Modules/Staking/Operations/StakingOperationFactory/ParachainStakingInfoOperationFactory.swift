import Foundation
import RobinHood
import BigInt
import SSFRuntimeCodingService

final class ParachainStakingInfoOperationFactory: NetworkStakingInfoOperationFactory {
    private func createMapOperation(
        revokeDelegationDelayOperation: BaseOperation<UInt32>,
        minDelegationOperation: BaseOperation<BigUInt>,
        rewardPaymentDelayOperation: BaseOperation<UInt32>
    ) -> BaseOperation<NetworkStakingInfo> {
        ClosureOperation<NetworkStakingInfo> {
            let revokeDelegationDelay = try revokeDelegationDelayOperation.extractNoCancellableResultData()
            let minDelegation = try minDelegationOperation.extractNoCancellableResultData()
            let rewardPaymentDelay = try rewardPaymentDelayOperation.extractNoCancellableResultData()

            let baseStakingInfo = BaseStakingInfo(
                lockUpPeriod: revokeDelegationDelay,
                minimalBalance: minDelegation,
                minStakeAmongActiveNominators: minDelegation
            )

            let parachainStakingInfo = ParachainStakingInfo(rewardPaymentDelay: rewardPaymentDelay)

            return .parachain(
                baseInfo: baseStakingInfo,
                parachainInfo: parachainStakingInfo
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

        let rewardPaymentDelayOperation: BaseOperation<UInt32> =
            createConstOperation(
                dependingOn: runtimeOperation,
                path: .rewardPaymentDelay
            )

        minDelegationOperation.addDependency(runtimeOperation)
        revokeDelegationDelayOperation.addDependency(runtimeOperation)
        rewardPaymentDelayOperation.addDependency(runtimeOperation)

        let mapOperation = createMapOperation(
            revokeDelegationDelayOperation: revokeDelegationDelayOperation,
            minDelegationOperation: minDelegationOperation,
            rewardPaymentDelayOperation: rewardPaymentDelayOperation
        )

        let mapDependencies = [
            revokeDelegationDelayOperation,
            minDelegationOperation,
            rewardPaymentDelayOperation,
            runtimeOperation
        ]

        mapOperation.addDependency(revokeDelegationDelayOperation)
        mapOperation.addDependency(minDelegationOperation)
        mapOperation.addDependency(rewardPaymentDelayOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: mapDependencies
        )
    }
}
