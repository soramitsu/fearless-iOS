import RobinHood
import FearlessUtils
import BigInt
import IrohaCrypto

struct PayoutSteps1To3Result {
    let currentEra: EraIndex
    let activeEra: EraIndex
    let historyDepth: UInt32

    var erasRange: [EraIndex] {
        Array(currentEra - historyDepth ... activeEra - 1)
    }
}

struct PayoutSteps4And5Result {
    let totalValidatorRewardByEra: [EraIndex: BigUInt]
    let validatorPointsDistributionByEra: [EraIndex: EraRewardPoints]
}

extension PayoutRewardsService {
    func createSteps1To3OperationWrapper(
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) throws -> CompoundOperationWrapper<PayoutSteps1To3Result> {
        let keyFactory = StorageKeyFactory()

        let currentEra: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<UInt32>>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keys: { [try keyFactory.currentEra()] },
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: .currentEra
            )

        currentEra.allOperations.forEach { $0.addDependency(codingFactoryOperation) }

        let activeEra: CompoundOperationWrapper<[StorageResponse<ActiveEraInfo>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keys: { [try keyFactory.activeEra()] },
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: .activeEra
            )
        activeEra.allOperations.forEach { $0.addDependency(codingFactoryOperation) }

        let historyDepthWrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<UInt32>>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keys: { [try keyFactory.historyDepth()] },
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: .historyDepth
            )

        historyDepthWrapper.allOperations.forEach { $0.addDependency(codingFactoryOperation) }

        let mergeOperation = ClosureOperation<PayoutSteps1To3Result> {
            guard
                let currentEra = try currentEra.targetOperation.extractNoCancellableResultData()
                .first?.value?.value,
                let activeEra = try activeEra.targetOperation.extractNoCancellableResultData()
                .first?.value?.index
            else {
                throw PayoutError.unknown
            }

            let historyDepth = try historyDepthWrapper.targetOperation.extractNoCancellableResultData()
                .first?.value?.value ?? 84

            return PayoutSteps1To3Result(
                currentEra: currentEra,
                activeEra: activeEra,
                historyDepth: historyDepth
            )
        }

        currentEra.allOperations.forEach { mergeOperation.addDependency($0) }
        activeEra.allOperations.forEach { mergeOperation.addDependency($0) }
        historyDepthWrapper.allOperations.forEach { mergeOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: currentEra.allOperations + activeEra.allOperations + historyDepthWrapper.allOperations
        )
    }

    func createSteps4And5OperationWrapper(
        dependingOn baseOperation: BaseOperation<PayoutSteps1To3Result>,
        engine: JSONRPCEngine,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) throws -> CompoundOperationWrapper<PayoutSteps4And5Result> {
        let totalRewardOperation: CompoundOperationWrapper<[EraIndex: StringScaleMapper<BigUInt>]> =
            try createFetchHistoryByEraOperation(
                dependingOn: baseOperation,
                engine: engine,
                codingFactoryOperation: codingFactoryOperation,
                path: .totalValidatorReward
            )
        totalRewardOperation.allOperations.forEach { $0.addDependency(codingFactoryOperation) }

        let validatorRewardPoints: CompoundOperationWrapper<[EraIndex: EraRewardPoints]> =
            try createFetchHistoryByEraOperation(
                dependingOn: baseOperation,
                engine: engine,
                codingFactoryOperation: codingFactoryOperation,
                path: .rewardPointsPerValidator
            )
        validatorRewardPoints.allOperations.forEach { $0.addDependency(codingFactoryOperation) }

        let mergeOperation = ClosureOperation<PayoutSteps4And5Result> {
            let totalValidatorRewardByEra = try totalRewardOperation
                .targetOperation.extractNoCancellableResultData()
            let validatorRewardPoints = try validatorRewardPoints
                .targetOperation.extractNoCancellableResultData()

            return PayoutSteps4And5Result(
                totalValidatorRewardByEra: totalValidatorRewardByEra.mapValues { $0.value },
                validatorPointsDistributionByEra: validatorRewardPoints
            )
        }

        let mergeOperationDependencies = totalRewardOperation.allOperations + validatorRewardPoints.allOperations
        mergeOperationDependencies.forEach { mergeOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: mergeOperationDependencies
        )
    }

    func createFetchHistoryByEraOperation<T: Decodable>(
        dependingOn basedOperation: BaseOperation<PayoutSteps1To3Result>,
        engine: JSONRPCEngine,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        path: StorageCodingPath
    ) throws -> CompoundOperationWrapper<[EraIndex: T]> {
        let keyParams: () throws -> [StringScaleMapper<EraIndex>] = {
            let result = try basedOperation.extractNoCancellableResultData()
            let eras = result.currentEra - result.historyDepth ... result.activeEra - 1
            return eras.map { StringScaleMapper(value: $0) }
        }

        let wrapper: CompoundOperationWrapper<[StorageResponse<T>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keyParams: keyParams,
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: path
            )

        let mergeOperation = ClosureOperation<[EraIndex: T]> {
            let eras = try keyParams()

            let results = try wrapper.targetOperation.extractNoCancellableResultData()
                .enumerated()
                .reduce(into: [EraIndex: T]()) { dict, item in
                    guard let result = item.element.value else {
                        return
                    }

                    let era = eras[item.offset].value

                    dict[era] = result
                }
            return results
        }

        wrapper.allOperations.forEach { mergeOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: wrapper.allOperations
        )
    }

    func createFetchAndMapOperation<T: Encodable, R: Decodable>(
        dependingOn depedencyOperation: BaseOperation<[T]>,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        path: StorageCodingPath
    ) throws -> CompoundOperationWrapper<[R]> {
        let keyParams: () throws -> [T] = {
            try depedencyOperation.extractNoCancellableResultData()
        }

        let wrapper: CompoundOperationWrapper<[StorageResponse<R>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keyParams: keyParams,
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: path
            )

        let mapOperation = ClosureOperation<[R]> {
            try wrapper.targetOperation.extractNoCancellableResultData()
                .compactMap(\.value)
        }

        wrapper.allOperations.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: wrapper.allOperations
        )
    }

    func createUnclaimedEraByStashOperation(
        ledgerInfoOperation: BaseOperation<[DyStakingLedger]>,
        steps1to3Operation: BaseOperation<PayoutSteps1To3Result>
    ) throws -> BaseOperation<[Data: [EraIndex]]> {
        ClosureOperation<[Data: [EraIndex]]> {
            let ledgerInfo = try ledgerInfoOperation.extractNoCancellableResultData()
            let erasRange = try steps1to3Operation.extractNoCancellableResultData().erasRange

            return ledgerInfo
                .reduce(into: [Data: [EraIndex]]()) { dict, ledger in
                    let erasClaimedRewards = Set(ledger.claimedRewards.map(\.value))
                    let erasUnclaimedRewards = Set(erasRange).subtracting(erasClaimedRewards)
                    dict[ledger.stash] = Array(erasUnclaimedRewards)
                }
        }
    }

    func createCreateHistoryByEraAccountIdOperation<T: Decodable>(
        dependingOn erasMapping: BaseOperation<[Data: [EraIndex]]>,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        path: StorageCodingPath
    ) throws -> CompoundOperationWrapper<[EraIndex: [Data: T]]> {
        let keys: () throws -> [(EraIndex, Data)] = {
            try erasMapping.extractNoCancellableResultData().flatMap { keyValue in
                keyValue.value.map { ($0, keyValue.key) }
            }
        }

        let keyParams1: () throws -> [StringScaleMapper<EraIndex>] = {
            try keys().map { StringScaleMapper(value: $0.0) }
        }

        let keyParams2: () throws -> [Data] = {
            try keys().map(\.1)
        }

        let wrapper: CompoundOperationWrapper<[StorageResponse<T>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keyParams1: keyParams1,
                keyParams2: keyParams2,
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: path
            )

        let mergeOperation = ClosureOperation<[EraIndex: [Data: T]]> {
            let responses = try wrapper.targetOperation.extractNoCancellableResultData()
            let keys = try keys()

            return responses.enumerated().reduce(into: [EraIndex: [Data: T]]()) { result, item in
                guard let value = item.element.value else {
                    return
                }

                let key = keys[item.offset]

                var valueByAccountId = result[key.0] ?? [Data: T]()
                valueByAccountId[key.1] = value
                result[key.0] = valueByAccountId
            }
        }

        wrapper.allOperations.forEach { mergeOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: wrapper.allOperations
        )
    }

    func createEraValidatorsInfoOperation(
        dependingOn exposureOperation: BaseOperation<[EraIndex: [Data: ValidatorExposure]]>,
        dependingOn prefsOperation: BaseOperation<[EraIndex: [Data: ValidatorPrefs]]>
    ) -> BaseOperation<[EraIndex: [EraValidatorInfo]]> {
        ClosureOperation {
            let exposuresMapping = try exposureOperation.extractNoCancellableResultData()
            let prefsMapping = try prefsOperation.extractNoCancellableResultData()

            return exposuresMapping
                .reduce(into: [EraIndex: [EraValidatorInfo]]()) { result, exposureMapping in
                    let infoList = exposureMapping.value
                        .reduce([EraValidatorInfo]()) { validators, accountIdExposure in
                            guard
                                let eraPrefs = prefsMapping[exposureMapping.key],
                                let accountIdPrefs = eraPrefs[accountIdExposure.key] else {
                                return validators
                            }

                            let info = EraValidatorInfo(
                                accountId: accountIdExposure.key,
                                exposure: accountIdExposure.value,
                                prefs: accountIdPrefs
                            )
                            return validators + [info]
                        }

                    let eraIndex = exposureMapping.key
                    result[eraIndex] = infoList
                }
        }
    }

    func calculatePayouts(
        dependingOn eraValdatorsOperation: BaseOperation<[EraIndex: [EraValidatorInfo]]>,
        eraRewardOverview: BaseOperation<PayoutSteps4And5Result>,
        stakingOverviewOperation: BaseOperation<PayoutSteps1To3Result>
    ) throws -> BaseOperation<PayoutsInfo> {
        let nominatorAccountId = try SS58AddressFactory().accountId(from: selectedAccountAddress)
        let amountPrecision = chain.addressType.precision

        return ClosureOperation<PayoutsInfo> {
            let validatorsByEra = try eraValdatorsOperation.extractNoCancellableResultData()
            let eraRewardOverview = try eraRewardOverview.extractNoCancellableResultData()
            let totalRewardByEra = eraRewardOverview.totalValidatorRewardByEra
            let pointsByEra = eraRewardOverview.validatorPointsDistributionByEra

            let payouts = validatorsByEra.reduce([PayoutInfo]()) { result, eraMapping in
                let era = eraMapping.key
                guard
                    let totalRewardAmount = totalRewardByEra[era],
                    let totalReward = Decimal.fromSubstrateAmount(totalRewardAmount, precision: amountPrecision),
                    let points = pointsByEra[era] else {
                    return result
                }

                let eraPayouts: [PayoutInfo] = eraMapping.value.compactMap { validatorInfo in
                    guard
                        let nominatorStakeAmount = validatorInfo.exposure.others
                        .first(where: { $0.who == nominatorAccountId })?.value,
                        let nominatorStake = Decimal
                        .fromSubstrateAmount(nominatorStakeAmount, precision: amountPrecision),
                        let comission = Decimal.fromSubstratePerbill(value: validatorInfo.prefs.commission),
                        let validatorPoints = points.individual
                        .first(where: { $0.accountId == validatorInfo.accountId })?.rewardPoint,
                        let totalStake = Decimal
                        .fromSubstrateAmount(validatorInfo.exposure.total, precision: amountPrecision) else {
                        return nil
                    }

                    let rewardFraction = Decimal(validatorPoints) / Decimal(points.total)
                    let validatorTotalReward = totalReward * rewardFraction
                    let nominatorReward = validatorTotalReward * (1 - comission) * (nominatorStake / totalStake)

                    return PayoutInfo(era: era, validator: validatorInfo.accountId, reward: nominatorReward)
                }

                return result + eraPayouts
            }

            let activeEra = try stakingOverviewOperation.extractNoCancellableResultData().activeEra

            return PayoutsInfo(activeEra: activeEra, payouts: payouts)
        }
    }
}
