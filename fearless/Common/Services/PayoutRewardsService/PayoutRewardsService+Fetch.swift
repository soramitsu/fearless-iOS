import RobinHood
import SSFUtils
import BigInt
import IrohaCrypto
import SSFRuntimeCodingService

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

        let historyDepthOperation: PrimitiveConstantOperation<UInt32> = createConstOperation(
            dependingOn: codingFactoryOperation,
            path: .historyDepth
        )

        let dependecies = currentEraWrapper.allOperations + activeEraWrapper.allOperations
            + [historyDepthOperation]
        dependecies.forEach { $0.addDependency(codingFactoryOperation) }

        let mergeOperation = ClosureOperation<ChainHistoryRange> {
            guard
                let currentEra = try currentEraWrapper.targetOperation.extractNoCancellableResultData()
                .first?.value?.value,
                let activeEra = try activeEraWrapper.targetOperation.extractNoCancellableResultData()
                .first?.value?.index
            else {
                throw PayoutRewardsServiceError.unknown
            }

            let historyDepth = try historyDepthOperation.extractNoCancellableResultData()

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
        dependingOn unclaimedErasOperation: BaseOperation<[AccountId: [EraIndex]]>,
        engine: JSONRPCEngine,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) throws -> CompoundOperationWrapper<ErasRewardDistribution> {
        let erasOperation = ClosureOperation<[EraIndex]> {
            let unclaimedErasResult = try unclaimedErasOperation.extractNoCancellableResultData()
            let eras = unclaimedErasResult.reduce(into: Set<EraIndex>()) { result, accountIdMapping in
                accountIdMapping.value.forEach { result.insert($0) }
            }

            return Array(eras)
        }

        let totalRewardOperation: CompoundOperationWrapper<[EraIndex: StringScaleMapper<BigUInt>]> =
            try createFetchHistoryByEraOperation(
                dependingOn: erasOperation,
                engine: engine,
                codingFactoryOperation: codingFactoryOperation,
                path: .totalValidatorReward
            )

        totalRewardOperation.allOperations.forEach {
            $0.addDependency(codingFactoryOperation)
            $0.addDependency(erasOperation)
        }

        let validatorRewardPoints: CompoundOperationWrapper<[EraIndex: EraRewardPoints]> =
            try createFetchHistoryByEraOperation(
                dependingOn: erasOperation,
                engine: engine,
                codingFactoryOperation: codingFactoryOperation,
                path: .rewardPointsPerValidator
            )

        validatorRewardPoints.allOperations.forEach {
            $0.addDependency(codingFactoryOperation)
            $0.addDependency(erasOperation)
        }

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

        let mergeOperationDependencies = [erasOperation] + totalRewardOperation.allOperations +
            validatorRewardPoints.allOperations
        mergeOperationDependencies.forEach { mergeOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: mergeOperationDependencies
        )
    }

    func createFetchHistoryByEraOperation<T: Decodable>(
        dependingOn erasOperation: BaseOperation<[EraIndex]>,
        engine: JSONRPCEngine,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        path: StorageCodingPath
    ) throws -> CompoundOperationWrapper<[EraIndex: T]> {
        let keyParams: () throws -> [StringScaleMapper<EraIndex>] = {
            let eras = try erasOperation.extractNoCancellableResultData()
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
        ledgerInfoOperation: BaseOperation<[StakingLedger]>,
        historyRangeOperation: BaseOperation<ChainHistoryRange>
    ) throws -> BaseOperation<[Data: [EraIndex]]> {
        ClosureOperation<[Data: [EraIndex]]> {
            let ledgerInfo = try ledgerInfoOperation.extractNoCancellableResultData()
            let eraList = try historyRangeOperation.extractNoCancellableResultData().eraList

            return ledgerInfo
                .reduce(into: [Data: [EraIndex]]()) { dict, ledger in
                    let erasClaimedRewards = Set(ledger.claimedRewards.map(\.value))
                    let erasUnclaimedRewards = Set(eraList).subtracting(erasClaimedRewards)
                    dict[ledger.stash] = Array(erasUnclaimedRewards)
                }
        }
    }

    private struct TupleStruct<T1: Codable, T2: Codable>: Codable {
        let key1: T1
        let key2: T2
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

        let nMapKeys: () throws -> [[NMapKeyParamProtocol]] = {
            let keys = try keys()
            return [
                keys.map { NMapKeyParam(value: String($0.0)) }, // Integers are represented as strings
                keys.map { NMapKeyParam(value: $0.1) }
            ]
        }

//
//        let keyParams1: () throws -> [StringScaleMapper<EraIndex>] = {
//            try keys().map { StringScaleMapper(value: $0.0) }
//        }
//
//        let keyParams2: () throws -> [Data] = {
//            try keys().map(\.1)
//        }

        let wrapper: CompoundOperationWrapper<[StorageResponse<T>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keyParams: nMapKeys,
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
                    let address = validatorInfo.accountId
                    result.insert(address)
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
        for payoutInfoFactory: PayoutInfoFactoryProtocol,
        dependingOn eraValidatorsOperation: BaseOperation<[EraIndex: [EraValidatorInfo]]>,
        erasRewardOperation: BaseOperation<ErasRewardDistribution>,
        historyRangeOperation: BaseOperation<ChainHistoryRange>,
        identityOperation: BaseOperation<[AccountAddress: AccountIdentity]>
    ) throws -> BaseOperation<PayoutsInfo> {
        let targetAccountId = try AddressFactory.accountId(from: selectedAccountAddress, chain: chain)

        return ClosureOperation<PayoutsInfo> {
            let validatorsByEra = try eraValidatorsOperation.extractNoCancellableResultData()
            let erasRewardDistribution = try erasRewardOperation.extractNoCancellableResultData()
            let identities = try identityOperation.extractNoCancellableResultData()

            let payouts = try validatorsByEra.reduce([PayoutInfo]()) { result, eraMapping in
                let era = eraMapping.key

                let eraPayouts: [PayoutInfo] = try eraMapping.value.compactMap { validatorInfo in
                    try payoutInfoFactory.calculate(
                        for: targetAccountId,
                        era: era,
                        validatorInfo: validatorInfo,
                        erasRewardDistribution: erasRewardDistribution,
                        identities: identities
                    )
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
