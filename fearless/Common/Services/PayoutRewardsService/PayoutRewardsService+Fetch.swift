import RobinHood
import FearlessUtils
import BigInt
import IrohaCrypto

extension PayoutRewardsService {
    func createChainHistoryRangeOperationWrapper(
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) throws -> CompoundOperationWrapper<ChainHistoryRange> {
        let keyFactory = StorageKeyFactory()

        let currentEraWrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<UInt32>>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keys: { [try keyFactory.currentEra()] },
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: .currentEra
            )

        let activeEraWrapper: CompoundOperationWrapper<[StorageResponse<ActiveEraInfo>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keys: { [try keyFactory.activeEra()] },
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: .activeEra
            )

        let historyDepthWrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<UInt32>>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keys: { [try keyFactory.historyDepth()] },
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: .historyDepth
            )

        let dependecies = currentEraWrapper.allOperations + activeEraWrapper.allOperations
            + historyDepthWrapper.allOperations
        dependecies.forEach { $0.addDependency(codingFactoryOperation) }

        let mergeOperation = ClosureOperation<ChainHistoryRange> {
            guard
                let currentEra = try currentEraWrapper.targetOperation.extractNoCancellableResultData()
                .first?.value?.value,
                let activeEra = try activeEraWrapper.targetOperation.extractNoCancellableResultData()
                .first?.value?.index,
                let historyDepth = try historyDepthWrapper.targetOperation.extractNoCancellableResultData()
                .first?.value?.value
            else {
                throw PayoutRewardsServiceError.unknown
            }

            return ChainHistoryRange(
                currentEra: currentEra,
                activeEra: activeEra,
                historyDepth: historyDepth
            )
        }

        dependecies.forEach { mergeOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependecies)
    }

    func createErasRewardDistributionOperationWrapper(
        dependingOn historyRangeOperation: BaseOperation<ChainHistoryRange>,
        engine: JSONRPCEngine,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) throws -> CompoundOperationWrapper<ErasRewardDistribution> {
        let totalRewardOperation: CompoundOperationWrapper<[EraIndex: StringScaleMapper<BigUInt>]> =
            try createFetchHistoryByEraOperation(
                dependingOn: historyRangeOperation,
                engine: engine,
                codingFactoryOperation: codingFactoryOperation,
                path: .totalValidatorReward
            )
        totalRewardOperation.allOperations.forEach { $0.addDependency(codingFactoryOperation) }

        let validatorRewardPoints: CompoundOperationWrapper<[EraIndex: EraRewardPoints]> =
            try createFetchHistoryByEraOperation(
                dependingOn: historyRangeOperation,
                engine: engine,
                codingFactoryOperation: codingFactoryOperation,
                path: .rewardPointsPerValidator
            )
        validatorRewardPoints.allOperations.forEach { $0.addDependency(codingFactoryOperation) }

        let mergeOperation = ClosureOperation<ErasRewardDistribution> {
            let totalValidatorRewardByEra = try totalRewardOperation
                .targetOperation.extractNoCancellableResultData()
            let validatorRewardPoints = try validatorRewardPoints
                .targetOperation.extractNoCancellableResultData()

            return ErasRewardDistribution(
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
        dependingOn historyRangeOperation: BaseOperation<ChainHistoryRange>,
        engine: JSONRPCEngine,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        path: StorageCodingPath
    ) throws -> CompoundOperationWrapper<[EraIndex: T]> {
        let keyParams: () throws -> [StringScaleMapper<EraIndex>] = {
            let result = try historyRangeOperation.extractNoCancellableResultData()
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
        historyRangeOperation: BaseOperation<ChainHistoryRange>
    ) throws -> BaseOperation<[Data: [EraIndex]]> {
        ClosureOperation<[Data: [EraIndex]]> {
            let ledgerInfo = try ledgerInfoOperation.extractNoCancellableResultData()
            let erasRange = try historyRangeOperation.extractNoCancellableResultData().erasRange

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

    func createIdentityFetchOperation(
        dependingOn eraValidatorsOperation: BaseOperation<[EraIndex: [EraValidatorInfo]]>
    ) -> CompoundOperationWrapper<[AccountAddress: AccountIdentity]> {
        let accountIdClosure: () throws -> [AccountId] = {
            let validatorsByEras = try eraValidatorsOperation.extractNoCancellableResultData()

            let accountIds = validatorsByEras.reduce(into: Set<AccountId>()) { result, mapping in
                mapping.value.forEach { validatorInfo in
                    result.insert(validatorInfo.accountId)
                }
            }

            return Array(accountIds)
        }

        return identityOperationFactory.createIdentityWrapper(
            for: accountIdClosure,
            engine: engine,
            runtimeService: runtimeCodingService,
            chain: chain
        )
    }

    func calculatePayouts(
        dependingOn eraValidatorsOperation: BaseOperation<[EraIndex: [EraValidatorInfo]]>,
        erasRewardOperation: BaseOperation<ErasRewardDistribution>,
        historyRangeOperation: BaseOperation<ChainHistoryRange>,
        identityOperation: BaseOperation<[AccountAddress: AccountIdentity]>
    ) throws -> BaseOperation<PayoutsInfo> {
        let addressFactory = SS58AddressFactory()
        let nominatorAccountId = try addressFactory.accountId(from: selectedAccountAddress)
        let addressType = chain.addressType

        return ClosureOperation<PayoutsInfo> {
            let validatorsByEra = try eraValidatorsOperation.extractNoCancellableResultData()
            let eraRewardOverview = try erasRewardOperation.extractNoCancellableResultData()
            let identities = try identityOperation.extractNoCancellableResultData()

            let calculationFactory = NominatorPayoutsInfoFactory(
                accountId: nominatorAccountId,
                addressType: addressType,
                erasRewardDistribution: eraRewardOverview,
                identities: identities,
                addressFactory: addressFactory
            )

            let payouts = try validatorsByEra.reduce([PayoutInfo]()) { result, eraMapping in
                let era = eraMapping.key

                let eraPayouts: [PayoutInfo] = try eraMapping.value.compactMap { validatorInfo in
                    try calculationFactory.calculate(for: era, validatorInfo: validatorInfo)
                }

                return result + eraPayouts
            }

            let overview = try historyRangeOperation.extractNoCancellableResultData()
            let sortedPayouts = payouts.sorted { $0.era < $1.era }

            return PayoutsInfo(
                activeEra: overview.activeEra,
                historyDepth: overview.historyDepth,
                payouts: sortedPayouts
            )
        }
    }
}
