import Foundation
import RobinHood
import BigInt

final class ParachainStakingInfoOperationFactory: NetworkStakingInfoOperationFactory {
    private func createMapOperation(
        dependingOn eraValidatorsOperation: BaseOperation<EraStakersInfo>,
        revokeDelegationDelayOperation: BaseOperation<UInt32>,
        minDelegationOperation: BaseOperation<BigUInt>
    ) -> BaseOperation<NetworkStakingInfo> {
        ClosureOperation<NetworkStakingInfo> {
            let eraStakersInfo = try eraValidatorsOperation.extractNoCancellableResultData()
            let revokeDelegationDelay = try Int(revokeDelegationDelayOperation.extractNoCancellableResultData())
            let minDelegation = try minDelegationOperation.extractNoCancellableResultData()

            let stakingDuration = StakingDuration(
                session: 0,
                era: 0,
                unlocking: TimeInterval(revokeDelegationDelay)
            )

            let baseStakingInfo = BaseStakingInfo(
                stakingDuration: stakingDuration,
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
        for eraValidatorService: EraValidatorServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<NetworkStakingInfo> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()
        let eraValidatorsOperation = eraValidatorService.fetchInfoOperation()

        let revokeDelegationDelayOperation: BaseOperation<UInt32> =
            createConstOperation(
                dependingOn: runtimeOperation,
                path: .maxNominatorRewardedPerValidator
            )

        let minDelegationOperation: BaseOperation<BigUInt> =
            createConstOperation(
                dependingOn: runtimeOperation,
                path: .maxNominatorRewardedPerValidator
            )

        minDelegationOperation.addDependency(runtimeOperation)
        revokeDelegationDelayOperation.addDependency(runtimeOperation)

        let mapOperation = createMapOperation(
            dependingOn: eraValidatorsOperation,
            revokeDelegationDelayOperation: revokeDelegationDelayOperation,
            minDelegationOperation: minDelegationOperation
        )

        let mapDependencies = [
            eraValidatorsOperation,
            revokeDelegationDelayOperation,
            minDelegationOperation
        ]

        mapDependencies.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: mapDependencies
        )
    }
}
