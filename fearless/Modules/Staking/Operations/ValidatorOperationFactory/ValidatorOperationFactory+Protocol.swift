import Foundation
import RobinHood
import IrohaCrypto

extension ValidatorOperationFactory: ValidatorOperationFactoryProtocol {
    // swiftlint:disable function_body_length
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

        let slashingsWrapper = createUnappliedSlashesWrapper(
            dependingOn: { try eraValidatorsOperation.extractNoCancellableResultData().activeEra },
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

    // swiftlint:disable function_body_length
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
                    hasSlashes: slashes[index]
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
                guard let nominatorIndex = validatorStakeInfo.nominators
                    .firstIndex(where: { $0.address == nominatorAddress }) else {
                    return nil
                }

                let validatorAddress = try addressFactory.addressFromAccountId(
                    data: validatorAccountId,
                    type: addressType
                )

                let nominatorInfo = validatorStakeInfo.nominators[nominatorIndex]
                let isRewarded = nominatorIndex < validatorStakeInfo.maxNominatorsRewarded
                let allocation = ValidatorTokenAllocation(amount: nominatorInfo.stake, isRewarded: isRewarded)

                return SelectedValidatorInfo(
                    address: validatorAddress,
                    identity: identities[validatorAddress],
                    stakeInfo: validatorStakeInfo,
                    myNomination: .active(allocation: allocation)
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

    // swiftlint:disable function_body_length
    func wannabeValidatorsOperation(
        for accountIdList: [AccountId]
    ) -> CompoundOperationWrapper<[SelectedValidatorInfo]> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()

        let slashDeferOperation: BaseOperation<UInt32> =
            createConstOperation(
                dependingOn: runtimeOperation,
                path: .slashDeferDuration
            )

        slashDeferOperation.addDependency(runtimeOperation)

        let eraValidatorsOperation = eraValidatorService.fetchInfoOperation()

        let slashingsWrapper = createUnappliedSlashesWrapper(
            dependingOn: { try eraValidatorsOperation.extractNoCancellableResultData().activeEra },
            runtime: runtimeOperation,
            slashDefer: slashDeferOperation
        )

        slashingsWrapper.allOperations.forEach {
            $0.addDependency(eraValidatorsOperation)
            $0.addDependency(runtimeOperation)
            $0.addDependency(slashDeferOperation)
        }

        let identitiesWrapper = identityOperationFactory.createIdentityWrapper(
            for: { accountIdList },
            engine: engine,
            runtimeService: runtimeService,
            chain: chain
        )

        let validatorPrefsWrapper = createValidatorPrefsWrapper(for: accountIdList)

        let stakeInfoWrapper = createValidatorsStakeInfoWrapper(
            for: accountIdList,
            electedValidatorsOperation: eraValidatorsOperation
        )

        stakeInfoWrapper.addDependency(operations: [eraValidatorsOperation])

        let addressType = chain.addressType

        let mergeOperation = ClosureOperation<[SelectedValidatorInfo]> {
            let identityList = try identitiesWrapper.targetOperation.extractNoCancellableResultData()
            let validatorPrefsList = try validatorPrefsWrapper.targetOperation.extractNoCancellableResultData()
            let slashings = try slashingsWrapper.targetOperation.extractNoCancellableResultData()
            let addressFactory = SS58AddressFactory()
            let stakeInfoList = try stakeInfoWrapper.targetOperation.extractNoCancellableResultData()

            let slashed: Set<Data> = slashings.reduce(into: Set<Data>()) { result, slashInEra in
                slashInEra.value?.forEach { slash in
                    result.insert(slash.validator)
                }
            }

            return try accountIdList.enumerated().compactMap { index, accountId in
                let validatorAddress = try addressFactory.addressFromAccountId(
                    data: accountId,
                    type: addressType
                )

                guard let prefs = validatorPrefsList[validatorAddress] else { return nil }

                let stakeInfo = stakeInfoList[index]

                let commission = Decimal.fromSubstrateAmount(
                    prefs.commission,
                    precision: addressType.precision
                ) ?? 0.0

                return SelectedValidatorInfo(
                    address: validatorAddress,
                    identity: identityList[validatorAddress],
                    stakeInfo: stakeInfo,
                    myNomination: stakeInfo != nil ? .elected : .unelected,
                    commission: commission,
                    hasSlashes: slashed.contains(accountId),
                    blocked: prefs.blocked
                )
            }
        }

        mergeOperation.addDependency(identitiesWrapper.targetOperation)
        mergeOperation.addDependency(validatorPrefsWrapper.targetOperation)
        mergeOperation.addDependency(slashingsWrapper.targetOperation)
        mergeOperation.addDependency(stakeInfoWrapper.targetOperation)

        let dependencies = [runtimeOperation, slashDeferOperation, eraValidatorsOperation] +
            identitiesWrapper.allOperations + validatorPrefsWrapper.allOperations +
            slashingsWrapper.allOperations + stakeInfoWrapper.allOperations
        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)
    }
}
