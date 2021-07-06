import Foundation
import RobinHood
import BigInt

protocol NetworkStakingInfoOperationFactoryProtocol {
    func networkStakingOperation() -> CompoundOperationWrapper<NetworkStakingInfo>
}

final class NetworkStakingInfoOperationFactory {
    let eraValidatorService: EraValidatorServiceProtocol
    let runtimeService: RuntimeCodingServiceProtocol

    init(
        eraValidatorService: EraValidatorServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol
    ) {
        self.eraValidatorService = eraValidatorService
        self.runtimeService = runtimeService
    }

    // MARK: - Private functions

    private func createConstOperation<T>(
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
        limitedBy maxNominators: Int
    ) -> BigUInt {
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
        minBalanceOperation: BaseOperation<BigUInt>
    ) -> BaseOperation<NetworkStakingInfo> {
        ClosureOperation<NetworkStakingInfo> {
            let eraStakersInfo = try eraValidatorsOperation.extractNoCancellableResultData()
            let maxNominators = try Int(maxNominatorsOperation.extractNoCancellableResultData())
            let lockUpPeriod = try lockUpPeriodOperation.extractNoCancellableResultData()
            let minBalance = try minBalanceOperation.extractNoCancellableResultData()

            let totalStake = self.deriveTotalStake(from: eraStakersInfo)

            let minimalStake = self.deriveMinimalStake(
                from: eraStakersInfo,
                limitedBy: maxNominators
            )

            let activeNominatorsCount = self.deriveActiveNominatorsCount(
                from: eraStakersInfo,
                limitedBy: maxNominators
            )

            return NetworkStakingInfo(
                totalStake: totalStake,
                minStakeAmongActiveNominators: minimalStake,
                minimalBalance: minBalance,
                activeNominatorsCount: activeNominatorsCount,
                lockUpPeriod: lockUpPeriod
            )
        }
    }
}

// MARK: - NetworkStakingInfoOperationFactoryProtocol

extension NetworkStakingInfoOperationFactory: NetworkStakingInfoOperationFactoryProtocol {
    func networkStakingOperation() -> CompoundOperationWrapper<NetworkStakingInfo> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()

        let maxNominatorsOperation: BaseOperation<UInt32> =
            createConstOperation(
                dependingOn: runtimeOperation,
                path: .maxNominatorRewardedPerValidator
            )

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

        let mapOperation = createMapOperation(
            dependingOn: eraValidatorsOperation,
            maxNominatorsOperation: maxNominatorsOperation,
            lockUpPeriodOperation: lockUpPeriodOperation,
            minBalanceOperation: existentialDepositOperation
        )

        mapOperation.addDependency(eraValidatorsOperation)
        mapOperation.addDependency(maxNominatorsOperation)
        mapOperation.addDependency(lockUpPeriodOperation)
        mapOperation.addDependency(existentialDepositOperation)

        let dependencies = [
            runtimeOperation,
            eraValidatorsOperation,
            maxNominatorsOperation,
            lockUpPeriodOperation,
            existentialDepositOperation
        ]

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }
}
