import Foundation
import RobinHood
import BigInt

final class RelaychainStakingInfoOperationFactory: NetworkStakingInfoOperationFactory {
    private func deriveTotalStake(from eraStakersInfo: EraStakersInfo) -> BigUInt {
        eraStakersInfo.validators
            .map(\.exposure.total)
            .reduce(0, +)
    }

    private func extractActiveNominators(
        from eraStakersInfo: EraStakersInfo,
        limitedBy maxNominators: Int
    ) -> Set<AccountId> {
        eraStakersInfo.validators.map(\.exposure.others)
            .flatMap { Array($0.prefix(maxNominators)) }
            .reduce(into: Set<Data>()) { $0.insert($1.who) }
    }

    private func deriveMinimalStake(
        from eraStakersInfo: EraStakersInfo,
        limitedBy maxNominators: Int,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> BigUInt {
        let isNominatorsCountUnlimited = runtimeService.snapshot?.metadata.getStorageMetadata(for: .erasStakersOverview) != nil

        if isNominatorsCountUnlimited {
            return .zero
        }

        let stakeDistribution = eraStakersInfo.validators
            .flatMap(\.exposure.others)
            .reduce(into: [Data: BigUInt]()) { result, item in
                if let stake = result[item.who] {
                    result[item.who] = stake + item.value
                } else {
                    result[item.who] = item.value
                }
            }

        let activeNominators = extractActiveNominators(
            from: eraStakersInfo,
            limitedBy: maxNominators
        )

        return stakeDistribution
            .filter { activeNominators.contains($0.key) }
            .map(\.value)
            .min() ?? BigUInt.zero
    }

    private func deriveActiveNominatorsCount(
        from eraStakersInfo: EraStakersInfo,
        limitedBy maxNominators: Int
    ) -> Int {
        extractActiveNominators(from: eraStakersInfo, limitedBy: maxNominators).count
    }

    private func createMapOperation(
        dependingOn eraValidatorsOperation: BaseOperation<EraStakersInfo>,
        maxNominatorsOperation: BaseOperation<UInt32>,
        lockUpPeriodOperation: BaseOperation<UInt32>,
        minBalanceOperation: BaseOperation<BigUInt>,
        durationOperation: BaseOperation<StakingDuration>,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> BaseOperation<NetworkStakingInfo> {
        ClosureOperation<NetworkStakingInfo> {
            let eraStakersInfo = try eraValidatorsOperation.extractNoCancellableResultData()
            let maxNominators = try Int(maxNominatorsOperation.extractNoCancellableResultData())
            let lockUpPeriod = try lockUpPeriodOperation.extractNoCancellableResultData()
            let minBalance = try minBalanceOperation.extractNoCancellableResultData()

            let totalStake = self.deriveTotalStake(from: eraStakersInfo)

            let minimalStake = self.deriveMinimalStake(
                from: eraStakersInfo,
                limitedBy: maxNominators,
                runtimeService: runtimeService
            )
            let activeNominatorsCount = self.deriveActiveNominatorsCount(
                from: eraStakersInfo,
                limitedBy: maxNominators
            )

            let stakingDuration = try durationOperation.extractNoCancellableResultData()

            let baseStakingInfo = BaseStakingInfo(
                lockUpPeriod: lockUpPeriod,
                minimalBalance: minBalance,
                minStakeAmongActiveNominators: minimalStake
            )

            let relaychainStakingInfo = RelaychainStakingInfo(
                stakingDuration: stakingDuration,
                totalStake: totalStake,
                activeNominatorsCount: activeNominatorsCount
            )

            return .relaychain(
                baseInfo: baseStakingInfo,
                relaychainInfo: relaychainStakingInfo
            )
        }
    }

    private func createMaxNominatorsOperation(
        runtimeService: RuntimeCodingServiceProtocol,
        dependingOn runtimeOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> BaseOperation<UInt32> {
        let oldArgumentExists = runtimeService.snapshot?.metadata.getConstant(
            in: ConstantCodingPath.maxNominatorRewardedPerValidator.moduleName,
            constantName: ConstantCodingPath.maxNominatorRewardedPerValidator.constantName
        ) != nil

        if oldArgumentExists {
            return createConstOperation(
                dependingOn: runtimeOperation,
                path: .maxNominatorRewardedPerValidator
            )
        } else {
            return ClosureOperation<UInt32>(closure: {
                UInt32.max
            })
        }
    }
}

// MARK: - NetworkStakingInfoOperationFactoryProtocol

extension RelaychainStakingInfoOperationFactory: NetworkStakingInfoOperationFactoryProtocol {
    func networkStakingOperation(
        for eraValidatorService: EraValidatorServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<NetworkStakingInfo> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()

        let maxNominatorsOperation: BaseOperation<UInt32> =
            createMaxNominatorsOperation(runtimeService: runtimeService, dependingOn: runtimeOperation)

        let lockUpPeriodOperation: BaseOperation<UInt32> =
            createConstOperation(
                dependingOn: runtimeOperation,
                path: .lockUpPeriod
            )

        let existentialDepositOperation: BaseOperation<BigUInt> = createConstOperation(
            dependingOn: runtimeOperation,
            path: .existentialDeposit
        )

        maxNominatorsOperation.addDependency(runtimeOperation)
        lockUpPeriodOperation.addDependency(runtimeOperation)
        existentialDepositOperation.addDependency(runtimeOperation)

        let eraValidatorsOperation = eraValidatorService.fetchInfoOperation()

        let stakingDurationWrapper = durationOperationFactory.createDurationOperation(from: runtimeService)

        let mapOperation = createMapOperation(
            dependingOn: eraValidatorsOperation,
            maxNominatorsOperation: maxNominatorsOperation,
            lockUpPeriodOperation: lockUpPeriodOperation,
            minBalanceOperation: existentialDepositOperation,
            durationOperation: stakingDurationWrapper.targetOperation,
            runtimeService: runtimeService
        )

        mapOperation.addDependency(eraValidatorsOperation)
        mapOperation.addDependency(maxNominatorsOperation)
        mapOperation.addDependency(lockUpPeriodOperation)
        mapOperation.addDependency(existentialDepositOperation)
        mapOperation.addDependency(stakingDurationWrapper.targetOperation)

        let dependencies = [
            runtimeOperation,
            eraValidatorsOperation,
            maxNominatorsOperation,
            lockUpPeriodOperation,
            existentialDepositOperation
        ] + stakingDurationWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }
}
