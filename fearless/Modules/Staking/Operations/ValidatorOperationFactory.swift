import Foundation
import RobinHood
import IrohaCrypto

protocol ValidatorOperationFactoryProtocol {
    func allElectedOperation() -> CompoundOperationWrapper<[ElectedValidatorInfo]>
    func allSelectedOperation(
        by nomination: Nomination,
        nominatorAddress: AccountAddress
    ) -> CompoundOperationWrapper<[SelectedValidatorInfo]>

    func activeValidatorsOperation(
        for nominatorAddress: AccountAddress
    ) -> CompoundOperationWrapper<[SelectedValidatorInfo]>

    func pendingValidatorsOperation(
        for accountIds: [AccountId]
    ) -> CompoundOperationWrapper<[SelectedValidatorInfo]>
}

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

    private func createSlashesWrapper(
        dependingOn validators: BaseOperation<EraStakersInfo>,
        runtime: BaseOperation<RuntimeCoderFactoryProtocol>,
        slashDefer: BaseOperation<UInt32>
    ) -> UnappliedSlashesWrapper {
        let path = StorageCodingPath.unappliedSlashes

        let keyParams: () throws -> [String] = {
            let info = try validators.extractNoCancellableResultData()
            let duration = try slashDefer.extractNoCancellableResultData()
            let startEra = max(info.era - duration, 0)
            return (startEra ... info.era).map { String($0) }
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

    private func createSlashesOperation(
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

    private func createStatusesOperation(
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
                    let exposuresClipped = electedValidator.exposure.others.prefix(Int(maxNominators))
                    if let amount = exposuresClipped.first(where: { $0.who == nominatorId })?.value,
                       let amountDecimal = Decimal.fromSubstrateAmount(amount, precision: addressType.precision) {
                        return .active(amount: amountDecimal)
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

    private func createValidatorsStakeInfoWrapper(
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

    private func createActiveValidatorsStakeInfo(
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

    private func createElectedValidatorsMergeOperation(
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
                        isCompound: false,
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

extension ValidatorOperationFactory: ValidatorOperationFactoryProtocol {
    func allElectedOperation() -> CompoundOperationWrapper<[ElectedValidatorInfo]> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()

        let slashDeferOperation: BaseOperation<UInt32> =
            createConstOperation(
                dependingOn: runtimeOperation,
                path: .slashDeferDuration
            )

        let maxNominatorsOperation: BaseOperation<UInt32> =
            createConstOperation(
                dependingOn: runtimeOperation,
                path: .maxNominatorRewardedPerValidator
            )

        slashDeferOperation.addDependency(runtimeOperation)
        maxNominatorsOperation.addDependency(runtimeOperation)

        let eraValidatorsOperation = eraValidatorService.fetchInfoOperation()

        let accountIdsClosure: () throws -> [AccountId] = {
            try eraValidatorsOperation.extractNoCancellableResultData().validators.map(\.accountId)
        }

        let identityWrapper = identityOperationFactory.createIdentityWrapper(
            for: accountIdsClosure,
            engine: engine,
            runtimeService: runtimeService,
            chain: chain
        )

        identityWrapper.allOperations.forEach { $0.addDependency(eraValidatorsOperation) }

        let slashingsWrapper = createSlashesWrapper(
            dependingOn: eraValidatorsOperation,
            runtime: runtimeOperation,
            slashDefer: slashDeferOperation
        )

        slashingsWrapper.allOperations.forEach {
            $0.addDependency(eraValidatorsOperation)
            $0.addDependency(runtimeOperation)
            $0.addDependency(slashDeferOperation)
        }

        let rewardOperation = rewardService.fetchCalculatorOperation()

        let mergeOperation = createElectedValidatorsMergeOperation(
            dependingOn: eraValidatorsOperation,
            rewardOperation: rewardOperation,
            maxNominatorsOperation: maxNominatorsOperation,
            slashesOperation: slashingsWrapper.targetOperation,
            identitiesOperation: identityWrapper.targetOperation
        )

        mergeOperation.addDependency(slashingsWrapper.targetOperation)
        mergeOperation.addDependency(identityWrapper.targetOperation)
        mergeOperation.addDependency(maxNominatorsOperation)
        mergeOperation.addDependency(rewardOperation)

        let baseOperations = [
            runtimeOperation,
            eraValidatorsOperation,
            slashDeferOperation,
            maxNominatorsOperation,
            rewardOperation
        ]

        let dependencies = baseOperations + identityWrapper.allOperations + slashingsWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)
    }

    func allSelectedOperation(
        by nomination: Nomination,
        nominatorAddress: AccountAddress
    ) -> CompoundOperationWrapper<[SelectedValidatorInfo]> {
        let identityWrapper = identityOperationFactory.createIdentityWrapper(
            for: { nomination.targets },
            engine: engine,
            runtimeService: runtimeService,
            chain: chain
        )

        let electedValidatorsOperation = eraValidatorService.fetchInfoOperation()

        let statusesWrapper = createStatusesOperation(
            for: nomination.targets,
            electedValidatorsOperation: electedValidatorsOperation,
            nominatorAddress: nominatorAddress
        )

        statusesWrapper.allOperations.forEach { $0.addDependency(electedValidatorsOperation) }

        let slashesWrapper = createSlashesOperation(for: nomination.targets, nomination: nomination)

        slashesWrapper.allOperations.forEach { $0.addDependency(electedValidatorsOperation) }

        let validatorsStakingInfoWrapper = createValidatorsStakeInfoWrapper(
            for: nomination.targets,
            electedValidatorsOperation: electedValidatorsOperation
        )

        validatorsStakingInfoWrapper.allOperations.forEach { $0.addDependency(electedValidatorsOperation) }

        let addressType = chain.addressType

        let mergeOperation = ClosureOperation<[SelectedValidatorInfo]> {
            let statuses = try statusesWrapper.targetOperation.extractNoCancellableResultData()
            let slashes = try slashesWrapper.targetOperation.extractNoCancellableResultData()
            let identities = try identityWrapper.targetOperation.extractNoCancellableResultData()
            let validatorsStakingInfo = try validatorsStakingInfoWrapper.targetOperation
                .extractNoCancellableResultData()

            let addressFactory = SS58AddressFactory()

            return try nomination.targets.enumerated().map { index, accountId in
                let address = try addressFactory.addressFromAccountId(data: accountId, type: addressType)

                return SelectedValidatorInfo(
                    address: address,
                    identity: identities[address],
                    stakeInfo: validatorsStakingInfo[index],
                    myNomination: statuses[index],
                    slashed: slashes[index]
                )
            }
        }

        mergeOperation.addDependency(identityWrapper.targetOperation)
        mergeOperation.addDependency(statusesWrapper.targetOperation)
        mergeOperation.addDependency(slashesWrapper.targetOperation)
        mergeOperation.addDependency(validatorsStakingInfoWrapper.targetOperation)

        let dependecies = [electedValidatorsOperation] + identityWrapper.allOperations +
            statusesWrapper.allOperations + slashesWrapper.allOperations +
            validatorsStakingInfoWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependecies)
    }

    func activeValidatorsOperation(
        for nominatorAddress: AccountAddress
    ) -> CompoundOperationWrapper<[SelectedValidatorInfo]> {
        let eraValidatorsOperation = eraValidatorService.fetchInfoOperation()
        let activeValidatorsStakeInfoWrapper = createActiveValidatorsStakeInfo(
            for: nominatorAddress,
            electedValidatorsOperation: eraValidatorsOperation
        )

        activeValidatorsStakeInfoWrapper.allOperations.forEach { $0.addDependency(eraValidatorsOperation) }

        let validatorIds: () throws -> [AccountId] = {
            try activeValidatorsStakeInfoWrapper.targetOperation.extractNoCancellableResultData().map(\.key)
        }

        let identitiesWrapper = identityOperationFactory.createIdentityWrapper(
            for: validatorIds,
            engine: engine,
            runtimeService: runtimeService,
            chain: chain
        )

        identitiesWrapper.allOperations.forEach {
            $0.addDependency(activeValidatorsStakeInfoWrapper.targetOperation)
        }

        let addressType = chain.addressType

        let mergeOperation = ClosureOperation<[SelectedValidatorInfo]> {
            let validatorStakeInfo = try activeValidatorsStakeInfoWrapper.targetOperation
                .extractNoCancellableResultData()
            let identities = try identitiesWrapper.targetOperation.extractNoCancellableResultData()
            let addressFactory = SS58AddressFactory()

            return try validatorStakeInfo.compactMap { validatorAccountId, validatorStakeInfo in
                guard let nominatorInfo = validatorStakeInfo.nominators
                    .first(where: { $0.address == nominatorAddress }) else {
                    return nil
                }

                let validatorAddress = try addressFactory.addressFromAccountId(
                    data: validatorAccountId,
                    type: addressType
                )

                return SelectedValidatorInfo(
                    address: validatorAddress,
                    identity: identities[validatorAddress],
                    stakeInfo: validatorStakeInfo,
                    myNomination: .active(amount: nominatorInfo.stake)
                )
            }
        }

        mergeOperation.addDependency(identitiesWrapper.targetOperation)
        let dependencies = [eraValidatorsOperation] + activeValidatorsStakeInfoWrapper.allOperations +
            identitiesWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)
    }

    func pendingValidatorsOperation(
        for accountIds: [AccountId]
    ) -> CompoundOperationWrapper<[SelectedValidatorInfo]> {
        let eraValidatorsOperation = eraValidatorService.fetchInfoOperation()
        let validatorsStakeInfoWrapper = createValidatorsStakeInfoWrapper(
            for: accountIds,
            electedValidatorsOperation: eraValidatorsOperation
        )

        validatorsStakeInfoWrapper.allOperations.forEach { $0.addDependency(eraValidatorsOperation) }

        let identitiesWrapper = identityOperationFactory.createIdentityWrapper(
            for: { accountIds },
            engine: engine,
            runtimeService: runtimeService,
            chain: chain
        )

        let addressType = chain.addressType

        let mergeOperation = ClosureOperation<[SelectedValidatorInfo]> {
            let validatorsStakeInfo = try validatorsStakeInfoWrapper.targetOperation
                .extractNoCancellableResultData()
            let identities = try identitiesWrapper.targetOperation.extractNoCancellableResultData()
            let addressFactory = SS58AddressFactory()

            return try validatorsStakeInfo.enumerated().map { index, validatorStakeInfo in
                let validatorAddress = try addressFactory.addressFromAccountId(
                    data: accountIds[index],
                    type: addressType
                )

                return SelectedValidatorInfo(
                    address: validatorAddress,
                    identity: identities[validatorAddress],
                    stakeInfo: validatorStakeInfo,
                    myNomination: nil
                )
            }
        }

        mergeOperation.addDependency(identitiesWrapper.targetOperation)
        mergeOperation.addDependency(validatorsStakeInfoWrapper.targetOperation)

        let dependencies = [eraValidatorsOperation] + validatorsStakeInfoWrapper.allOperations +
            identitiesWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)
    }
}
