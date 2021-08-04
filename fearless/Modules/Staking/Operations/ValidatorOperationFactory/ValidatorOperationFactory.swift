import Foundation
import RobinHood
import IrohaCrypto

final class ValidatorOperationFactory {
    let chain: Chain
    let eraValidatorService: EraValidatorServiceProtocol
    let rewardService: RewardCalculatorServiceProtocol
    let storageRequestFactory: StorageRequestFactoryProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let identityOperationFactory: IdentityOperationFactoryProtocol
    let engine: JSONRPCEngine

    init(
        chain: Chain,
        eraValidatorService: EraValidatorServiceProtocol,
        rewardService: RewardCalculatorServiceProtocol,
        storageRequestFactory: StorageRequestFactoryProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        engine: JSONRPCEngine,
        identityOperationFactory: IdentityOperationFactoryProtocol
    ) {
        self.chain = chain
        self.eraValidatorService = eraValidatorService
        self.rewardService = rewardService
        self.storageRequestFactory = storageRequestFactory
        self.runtimeService = runtimeService
        self.engine = engine
        self.identityOperationFactory = identityOperationFactory
    }

    func createUnappliedSlashesWrapper(
        dependingOn activeEraClosure: @escaping () throws -> EraIndex,
        runtime: BaseOperation<RuntimeCoderFactoryProtocol>,
        slashDefer: BaseOperation<UInt32>
    ) -> UnappliedSlashesWrapper {
        let path = StorageCodingPath.unappliedSlashes

        let keyParams: () throws -> [String] = {
            let activeEra = try activeEraClosure()
            let duration = try slashDefer.extractNoCancellableResultData()
            let startEra = max(activeEra - duration, 0)
            return (startEra ... activeEra).map { String($0) }
        }

        let factory: () throws -> RuntimeCoderFactoryProtocol = {
            try runtime.extractNoCancellableResultData()
        }

        return storageRequestFactory.queryItems(
            engine: engine,
            keyParams: keyParams,
            factory: factory,
            storagePath: path
        )
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

    func createSlashesOperation(
        for validatorIds: [AccountId],
        nomination: Nomination
    ) -> CompoundOperationWrapper<[Bool]> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()

        let slashingSpansWrapper: CompoundOperationWrapper<[StorageResponse<SlashingSpans>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keyParams: { validatorIds },
                factory: { try runtimeOperation.extractNoCancellableResultData() },
                storagePath: .slashingSpans
            )

        slashingSpansWrapper.allOperations.forEach { $0.addDependency(runtimeOperation) }

        let operation = ClosureOperation<[Bool]> {
            let slashingSpans = try slashingSpansWrapper.targetOperation.extractNoCancellableResultData()

            return validatorIds.enumerated().map { index, _ in
                let slashingSpan = slashingSpans[index]

                if let lastSlashEra = slashingSpan.value?.lastNonzeroSlash, lastSlashEra > nomination.submittedIn {
                    return true
                }

                return false
            }
        }

        operation.addDependency(slashingSpansWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: operation,
            dependencies: [runtimeOperation] + slashingSpansWrapper.allOperations
        )
    }

    func createStatusesOperation(
        for validatorIds: [AccountId],
        electedValidatorsOperation: BaseOperation<EraStakersInfo>,
        nominatorAddress: AccountAddress
    ) -> CompoundOperationWrapper<[ValidatorMyNominationStatus]> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()

        let maxNominatorsOperation: BaseOperation<UInt32> =
            createConstOperation(
                dependingOn: runtimeOperation,
                path: .maxNominatorRewardedPerValidator
            )

        maxNominatorsOperation.addDependency(runtimeOperation)

        let addressType = chain.addressType

        let statusesOperation = ClosureOperation<[ValidatorMyNominationStatus]> {
            let allElectedValidators = try electedValidatorsOperation.extractNoCancellableResultData()
            let nominatorId = try SS58AddressFactory().accountId(from: nominatorAddress)
            let maxNominators = try maxNominatorsOperation.extractNoCancellableResultData()

            return validatorIds.enumerated().map { _, accountId in
                if let electedValidator = allElectedValidators.validators
                    .first(where: { $0.accountId == accountId }) {
                    let nominators = electedValidator.exposure.others
                    if let index = nominators.firstIndex(where: { $0.who == nominatorId }),
                       let amountDecimal = Decimal.fromSubstrateAmount(
                           nominators[index].value,
                           precision: addressType.precision
                       ) {
                        let isRewarded = index < maxNominators
                        let allocation = ValidatorTokenAllocation(amount: amountDecimal, isRewarded: isRewarded)
                        return .active(allocation: allocation)
                    } else {
                        return .elected
                    }
                } else {
                    return .unelected
                }
            }
        }

        statusesOperation.addDependency(maxNominatorsOperation)

        return CompoundOperationWrapper(
            targetOperation: statusesOperation,
            dependencies: [runtimeOperation, maxNominatorsOperation]
        )
    }

    func createValidatorPrefsWrapper(for accountIdList: [AccountId])
        -> CompoundOperationWrapper<[AccountAddress: ValidatorPrefs]> {
        let addressType = chain.addressType

        let runtimeFetchOperation = runtimeService.fetchCoderFactoryOperation()

        let fetchOperation: CompoundOperationWrapper<[StorageResponse<ValidatorPrefs>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keyParams: { accountIdList },
                factory: { try runtimeFetchOperation.extractNoCancellableResultData() },
                storagePath: .validatorPrefs
            )

        fetchOperation.allOperations.forEach { $0.addDependency(runtimeFetchOperation) }

        let addressFactory = SS58AddressFactory()

        let mapOperation = ClosureOperation<[AccountAddress: ValidatorPrefs]> {
            try fetchOperation.targetOperation.extractNoCancellableResultData()
                .enumerated()
                .reduce(into: [AccountAddress: ValidatorPrefs]()) { result, indexedItem in
                    let address = try addressFactory.addressFromAccountId(
                        data: accountIdList[indexedItem.offset],
                        type: addressType
                    )

                    if indexedItem.element.data != nil {
                        result[address] = indexedItem.element.value
                    } else {
                        result[address] = nil
                    }
                }
        }

        mapOperation.addDependency(fetchOperation.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [runtimeFetchOperation] + fetchOperation.allOperations
        )
    }

    func createValidatorsStakeInfoWrapper(
        for validatorIds: [AccountId],
        electedValidatorsOperation: BaseOperation<EraStakersInfo>
    ) -> CompoundOperationWrapper<[ValidatorStakeInfo?]> {
        let addressType = chain.addressType

        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()

        let rewardCalculatorOperation = rewardService.fetchCalculatorOperation()

        let maxNominatorsOperation: BaseOperation<UInt32> = createConstOperation(
            dependingOn: runtimeOperation,
            path: .maxNominatorRewardedPerValidator
        )

        maxNominatorsOperation.addDependency(runtimeOperation)

        let validatorsStakeInfoOperation = ClosureOperation<[ValidatorStakeInfo?]> {
            let electedStakers = try electedValidatorsOperation.extractNoCancellableResultData()
            let returnCalculator = try rewardCalculatorOperation.extractNoCancellableResultData()
            let maxNominatorsRewarded =
                try maxNominatorsOperation.extractNoCancellableResultData()
            let addressFactory = SS58AddressFactory()

            return try validatorIds.map { validatorId in
                if let electedValidator = electedStakers.validators
                    .first(where: { $0.accountId == validatorId }) {
                    let nominators: [NominatorInfo] = try electedValidator.exposure.others.map { individual in
                        let nominatorAddress = try addressFactory.addressFromAccountId(
                            data: individual.who,
                            type: addressType
                        )

                        let stake = Decimal.fromSubstrateAmount(
                            individual.value,
                            precision: addressType.precision
                        ) ?? 0.0

                        return NominatorInfo(address: nominatorAddress, stake: stake)
                    }

                    let totalStake = Decimal.fromSubstrateAmount(
                        electedValidator.exposure.total,
                        precision: addressType.precision
                    ) ?? 0.0

                    let stakeReturn = try returnCalculator.calculateValidatorReturn(
                        validatorAccountId: validatorId,
                        isCompound: true,
                        period: .year
                    )

                    return ValidatorStakeInfo(
                        nominators: nominators,
                        totalStake: totalStake,
                        stakeReturn: stakeReturn,
                        maxNominatorsRewarded: maxNominatorsRewarded
                    )
                } else {
                    return nil
                }
            }
        }

        validatorsStakeInfoOperation.addDependency(rewardCalculatorOperation)
        validatorsStakeInfoOperation.addDependency(maxNominatorsOperation)

        return CompoundOperationWrapper(
            targetOperation: validatorsStakeInfoOperation,
            dependencies: [runtimeOperation, rewardCalculatorOperation, maxNominatorsOperation]
        )
    }

    func createActiveValidatorsStakeInfo(
        for nominatorAddress: AccountAddress,
        electedValidatorsOperation: BaseOperation<EraStakersInfo>
    ) -> CompoundOperationWrapper<[AccountId: ValidatorStakeInfo]> {
        let addressType = chain.addressType

        let rewardCalculatorOperation = rewardService.fetchCalculatorOperation()

        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()

        let maxNominatorsOperation: BaseOperation<UInt32> = createConstOperation(
            dependingOn: runtimeOperation,
            path: .maxNominatorRewardedPerValidator
        )

        maxNominatorsOperation.addDependency(runtimeOperation)

        let validatorsStakeInfoOperation = ClosureOperation<[AccountId: ValidatorStakeInfo]> {
            let electedStakers = try electedValidatorsOperation.extractNoCancellableResultData()
            let returnCalculator = try rewardCalculatorOperation.extractNoCancellableResultData()
            let addressFactory = SS58AddressFactory()
            let nominatorAccountId = try addressFactory.accountId(fromAddress: nominatorAddress, type: addressType)
            let maxNominatorsRewarded = try maxNominatorsOperation
                .extractNoCancellableResultData()

            return try electedStakers.validators
                .reduce(into: [AccountId: ValidatorStakeInfo]()) { result, validator in
                    let exposures = validator.exposure.others
                        .prefix(Int(maxNominatorsRewarded))

                    guard exposures.contains(where: { $0.who == nominatorAccountId }) else {
                        return
                    }

                    let nominators: [NominatorInfo] = try validator.exposure.others.map { individual in
                        let nominatorAddress = try addressFactory.addressFromAccountId(
                            data: individual.who,
                            type: addressType
                        )

                        let stake = Decimal.fromSubstrateAmount(
                            individual.value,
                            precision: addressType.precision
                        ) ?? 0.0

                        return NominatorInfo(address: nominatorAddress, stake: stake)
                    }

                    let totalStake = Decimal.fromSubstrateAmount(
                        validator.exposure.total,
                        precision: addressType.precision
                    ) ?? 0.0

                    let stakeReturn = try returnCalculator.calculateValidatorReturn(
                        validatorAccountId: validator.accountId,
                        isCompound: true,
                        period: .year
                    )

                    let info = ValidatorStakeInfo(
                        nominators: nominators,
                        totalStake: totalStake,
                        stakeReturn: stakeReturn,
                        maxNominatorsRewarded: maxNominatorsRewarded
                    )

                    result[validator.accountId] = info
                }
        }

        validatorsStakeInfoOperation.addDependency(rewardCalculatorOperation)
        validatorsStakeInfoOperation.addDependency(maxNominatorsOperation)

        return CompoundOperationWrapper(
            targetOperation: validatorsStakeInfoOperation,
            dependencies: [rewardCalculatorOperation, runtimeOperation, maxNominatorsOperation]
        )
    }

    func createElectedValidatorsMergeOperation(
        dependingOn eraValidatorsOperation: BaseOperation<EraStakersInfo>,
        rewardOperation: BaseOperation<RewardCalculatorEngineProtocol>,
        maxNominatorsOperation: BaseOperation<UInt32>,
        slashesOperation: UnappliedSlashesOperation,
        identitiesOperation: BaseOperation<[String: AccountIdentity]>
    ) -> BaseOperation<[ElectedValidatorInfo]> {
        let addressType = chain.addressType

        return ClosureOperation<[ElectedValidatorInfo]> {
            let electedInfo = try eraValidatorsOperation.extractNoCancellableResultData()
            let maxNominators = try maxNominatorsOperation.extractNoCancellableResultData()
            let slashings = try slashesOperation.extractNoCancellableResultData()
            let identities = try identitiesOperation.extractNoCancellableResultData()
            let calculator = try rewardOperation.extractNoCancellableResultData()

            let addressFactory = SS58AddressFactory()

            let slashed: Set<Data> = slashings.reduce(into: Set<Data>()) { result, slashInEra in
                slashInEra.value?.forEach { slash in
                    result.insert(slash.validator)
                }
            }

            return try electedInfo.validators.map { validator in
                let hasSlashes = slashed.contains(validator.accountId)

                let address = try addressFactory.addressFromAccountId(
                    data: validator.accountId,
                    type: addressType
                )

                let validatorReturn = try calculator
                    .calculateValidatorReturn(
                        validatorAccountId: validator.accountId,
                        isCompound: true,
                        period: .year
                    )

                return try ElectedValidatorInfo(
                    validator: validator,
                    identity: identities[address],
                    stakeReturn: validatorReturn,
                    hasSlashes: hasSlashes,
                    maxNominatorsRewarded: maxNominators,
                    addressType: addressType,
                    blocked: validator.prefs.blocked
                )
            }
        }
    }
}
