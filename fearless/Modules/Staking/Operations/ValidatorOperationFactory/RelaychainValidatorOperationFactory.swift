import Foundation
import RobinHood
import IrohaCrypto
import SSFUtils
import SSFModels

// swiftlint:disable type_body_length
final class RelaychainValidatorOperationFactory {
    private let asset: AssetModel
    private let chain: ChainModel
    private let eraValidatorService: EraValidatorServiceProtocol
    private let rewardService: RewardCalculatorServiceProtocol
    private let storageRequestFactory: StorageRequestFactoryProtocol
    private let identityOperationFactory: IdentityOperationFactoryProtocol
    private let chainRegistry: ChainRegistryProtocol

    init(
        asset: AssetModel,
        chain: ChainModel,
        eraValidatorService: EraValidatorServiceProtocol,
        rewardService: RewardCalculatorServiceProtocol,
        storageRequestFactory: StorageRequestFactoryProtocol,
        identityOperationFactory: IdentityOperationFactoryProtocol,
        chainRegistry: ChainRegistryProtocol
    ) {
        self.asset = asset
        self.chain = chain
        self.eraValidatorService = eraValidatorService
        self.rewardService = rewardService
        self.storageRequestFactory = storageRequestFactory
        self.identityOperationFactory = identityOperationFactory
        self.chainRegistry = chainRegistry
    }

    func createUnappliedSlashesWrapper(
        dependingOn activeEraClosure: @escaping () throws -> EraIndex,
        runtime: BaseOperation<RuntimeCoderFactoryProtocol>,
        slashDefer: BaseOperation<UInt32>
    ) -> UnappliedSlashesWrapper {
        guard let connection = chainRegistry.getConnection(for: chain.chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.connectionUnavailable)
        }

        let path = StorageCodingPath.unappliedSlashes

        let keyParams: () throws -> [String] = {
            let activeEra = try activeEraClosure()
            let duration = try slashDefer.extractNoCancellableResultData()

            guard activeEra > duration else {
                return []
            }

            let startEra = max(activeEra - duration, 0)
            return (startEra ... activeEra).map { String($0) }
        }

        let factory: () throws -> RuntimeCoderFactoryProtocol = {
            try runtime.extractNoCancellableResultData()
        }

        return storageRequestFactory.queryItems(
            engine: connection,
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
    ) -> CompoundOperationWrapper<[AccountId: Bool]> {
        guard let connection = chainRegistry.getConnection(for: chain.chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.connectionUnavailable)
        }

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }

        guard let chainStakingSettings = chain.stakingSettings else {
            return CompoundOperationWrapper.createWithError(ConvenienceError(error: "No staking settings found for \(chain.name) chain"))
        }

        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()

        let slashingSpansWrapper: CompoundOperationWrapper<[StorageResponse<SlashingSpans>]> = chainStakingSettings.queryItems(
            engine: connection,
            keyParams: { validatorIds },
            factory: { try runtimeOperation.extractNoCancellableResultData() },
            storagePath: .slashingSpans,
            using: storageRequestFactory
        )

        slashingSpansWrapper.allOperations.forEach { $0.addDependency(runtimeOperation) }

        let operation = ClosureOperation<[AccountId: Bool]> {
            let slashingSpans = try slashingSpansWrapper.targetOperation.extractNoCancellableResultData()
            var slashes: [AccountId: Bool] = [:]

            slashingSpans.forEach { storageResponse in
                let accountId = storageResponse.key.getAccountIdFromKey(accountIdLenght: 32)

                var isSlashed = false
                if let lastSlashEra = storageResponse.value?.lastNonzeroSlash, lastSlashEra > nomination.submittedIn {
                    isSlashed = true
                }

                slashes[accountId] = isSlashed
            }

            return slashes
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
        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }

        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()

        let maxNominatorsOperation: BaseOperation<UInt32> =
            createConstOperation(
                dependingOn: runtimeOperation,
                path: .maxNominatorRewardedPerValidator
            )

        maxNominatorsOperation.addDependency(runtimeOperation)

        let statusesOperation = ClosureOperation<[ValidatorMyNominationStatus]> { [weak self] in
            guard let strongSelf = self else {
                return []
            }

            let allElectedValidators = try electedValidatorsOperation.extractNoCancellableResultData()
            let nominatorId = try AddressFactory.accountId(from: nominatorAddress, chain: strongSelf.chain)
            let maxNominators = try maxNominatorsOperation.extractNoCancellableResultData()

            return validatorIds.enumerated().map { _, accountId in
                if let electedValidator = allElectedValidators.validators
                    .first(where: { $0.accountId == accountId }) {
                    let nominators = electedValidator.exposure.others
                    if let index = nominators.firstIndex(where: { $0.who == nominatorId }),
                       let amountDecimal = Decimal.fromSubstrateAmount(
                           nominators[index].value,
                           precision: Int16(strongSelf.asset.precision)
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

    func createValidatorPrefsWrapper(
        for accountIdList: [AccountId]
    ) -> CompoundOperationWrapper<[AccountAddress: ValidatorPrefs]> {
        guard let connection = chainRegistry.getConnection(for: chain.chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.connectionUnavailable)
        }

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }

        let chainFormat = chain.chainFormat

        let runtimeFetchOperation = runtimeService.fetchCoderFactoryOperation()

        guard let chainStakingSettings = chain.stakingSettings else {
            return CompoundOperationWrapper.createWithError(ConvenienceError(error: "No staking settings found for \(chain.name) chain"))
        }

        let fetchOperation: CompoundOperationWrapper<[StorageResponse<ValidatorPrefs>]> = chainStakingSettings.queryItems(
            engine: connection,
            keyParams: { accountIdList },
            factory: { try runtimeFetchOperation.extractNoCancellableResultData() },
            storagePath: .validatorPrefs,
            using: storageRequestFactory
        )

        fetchOperation.allOperations.forEach { $0.addDependency(runtimeFetchOperation) }

        let mapOperation = ClosureOperation<[AccountAddress: ValidatorPrefs]> {
            try fetchOperation.targetOperation.extractNoCancellableResultData()
                .enumerated()
                .reduce(into: [AccountAddress: ValidatorPrefs]()) { result, indexedItem in
                    let address = try AddressFactory.address(
                        for: accountIdList[indexedItem.offset],
                        chainFormat: chainFormat
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
        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }

        let chainFormat = chain.chainFormat

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

            return try validatorIds.map { validatorId in
                if let electedValidator = electedStakers.validators
                    .first(where: { $0.accountId == validatorId }) {
                    let nominators: [NominatorInfo] = try electedValidator.exposure.others.map { individual in
                        let nominatorAddress = try AddressFactory.address(
                            for: individual.who,
                            chainFormat: chainFormat
                        )

                        let stake = Decimal.fromSubstrateAmount(
                            individual.value,
                            precision: Int16(self.asset.precision)
                        ) ?? 0.0

                        return NominatorInfo(address: nominatorAddress, stake: stake)
                    }

                    let totalStake = Decimal.fromSubstrateAmount(
                        electedValidator.exposure.total,
                        precision: Int16(self.asset.precision)
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
        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }

        let chain = chain
        let chainFormat = chain.chainFormat

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
            let nominatorAccountId = try AddressFactory.accountId(from: nominatorAddress, chain: chain)
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
                        let nominatorAddress = try AddressFactory.address(
                            for: individual.who,
                            chainFormat: chainFormat
                        )

                        let stake = Decimal.fromSubstrateAmount(
                            individual.value,
                            precision: Int16(self.asset.precision)
                        ) ?? 0.0

                        return NominatorInfo(address: nominatorAddress, stake: stake)
                    }

                    let totalStake = Decimal.fromSubstrateAmount(
                        validator.exposure.total,
                        precision: Int16(self.asset.precision)
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
        let chainFormat = chain.chainFormat
        let addressPrefix = chain.addressPrefix

        return ClosureOperation<[ElectedValidatorInfo]> {
            let electedInfo = try eraValidatorsOperation.extractNoCancellableResultData()
            let maxNominators = try maxNominatorsOperation.extractNoCancellableResultData()
            let slashings = try slashesOperation.extractNoCancellableResultData()
            let identities = try identitiesOperation.extractNoCancellableResultData()
            let calculator = try rewardOperation.extractNoCancellableResultData()

            let slashed: Set<Data> = slashings.reduce(into: Set<Data>()) { result, slashInEra in
                slashInEra.value?.forEach { slash in
                    result.insert(slash.validator)
                }
            }

            return try electedInfo.validators.map { validator in
                let hasSlashes = slashed.contains(validator.accountId)

                let address = try AddressFactory.address(
                    for: validator.accountId,
                    chainFormat: chainFormat
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
                    chainFormat: chainFormat,
                    blocked: validator.prefs.blocked,
                    precision: Int16(self.asset.precision)
                )
            }
        }
    }

    func createNominatorsOperation(
        for accountId: AccountId
    ) -> CompoundOperationWrapper<Nomination?> {
        guard let connection = chainRegistry.getConnection(for: chain.chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.connectionUnavailable)
        }

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }

        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()

        guard let chainStakingSettings = chain.stakingSettings else {
            return CompoundOperationWrapper.createWithError(ConvenienceError(error: "No staking settings found for \(chain.name) chain"))
        }

        let nominatorsWrapper: CompoundOperationWrapper<[StorageResponse<Nomination>]> = chainStakingSettings.queryItems(
            engine: connection,
            keyParams: { [accountId] },
            factory: { try runtimeOperation.extractNoCancellableResultData() },
            storagePath: .nominators,
            using: storageRequestFactory
        )

        nominatorsWrapper.allOperations.forEach { $0.addDependency(runtimeOperation) }

        let operation = ClosureOperation<Nomination?> {
            let nominators = try nominatorsWrapper.targetOperation.extractNoCancellableResultData()

            return nominators.compactMap { $0.value }.first
        }

        operation.addDependency(nominatorsWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: operation,
            dependencies: [runtimeOperation] + nominatorsWrapper.allOperations
        )
    }
}

extension RelaychainValidatorOperationFactory: ValidatorOperationFactoryProtocol {
    func nomination(accountId: AccountId) -> CompoundOperationWrapper<Nomination?> {
        createNominatorsOperation(for: accountId)
    }

    // swiftlint:disable function_body_length
    func allElectedOperation() -> CompoundOperationWrapper<[ElectedValidatorInfo]> {
        guard let connection = chainRegistry.getConnection(for: chain.chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.connectionUnavailable)
        }

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }

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
            try eraValidatorsOperation.extractNoCancellableResultData().validators.compactMap { $0.accountId }
        }

        let identityWrapper = identityOperationFactory.createIdentityWrapper(
            for: accountIdsClosure,
            engine: connection,
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
        guard let connection = chainRegistry.getConnection(for: chain.chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.connectionUnavailable)
        }

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }

        let identityWrapper = identityOperationFactory.createIdentityWrapper(
            for: { nomination.targets },
            engine: connection,
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

        let chainFormat = chain.chainFormat

        let mergeOperation = ClosureOperation<[SelectedValidatorInfo]> {
            let statuses = try statusesWrapper.targetOperation.extractNoCancellableResultData()
            let slashes = try slashesWrapper.targetOperation.extractNoCancellableResultData()
            let identities = try identityWrapper.targetOperation.extractNoCancellableResultData()
            let validatorsStakingInfo = try validatorsStakingInfoWrapper.targetOperation
                .extractNoCancellableResultData()

            return try nomination.targets.enumerated().map { index, accountId in
                let address = try AddressFactory.address(for: accountId, chainFormat: chainFormat)

                return SelectedValidatorInfo(
                    address: address,
                    identity: identities[address],
                    stakeInfo: validatorsStakingInfo[index],
                    myNomination: statuses[index],
                    hasSlashes: slashes[accountId] == true
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
        guard let connection = chainRegistry.getConnection(for: chain.chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.connectionUnavailable)
        }

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }

        let eraValidatorsOperation = eraValidatorService.fetchInfoOperation()
        let activeValidatorsStakeInfoWrapper = createActiveValidatorsStakeInfo(
            for: nominatorAddress,
            electedValidatorsOperation: eraValidatorsOperation
        )

        activeValidatorsStakeInfoWrapper.allOperations.forEach { $0.addDependency(eraValidatorsOperation) }

        let validatorIds: () throws -> [AccountId] = {
            try activeValidatorsStakeInfoWrapper.targetOperation.extractNoCancellableResultData().compactMap { $0.key }
        }

        let identitiesWrapper = identityOperationFactory.createIdentityWrapper(
            for: validatorIds,
            engine: connection,
            runtimeService: runtimeService,
            chain: chain
        )

        identitiesWrapper.allOperations.forEach {
            $0.addDependency(activeValidatorsStakeInfoWrapper.targetOperation)
        }

        let chainFormat = chain.chainFormat

        let mergeOperation = ClosureOperation<[SelectedValidatorInfo]> {
            let validatorStakeInfo = try activeValidatorsStakeInfoWrapper.targetOperation
                .extractNoCancellableResultData()
            let identities = try identitiesWrapper.targetOperation.extractNoCancellableResultData()

            return try validatorStakeInfo.compactMap { validatorAccountId, validatorStakeInfo in
                guard let nominatorIndex = validatorStakeInfo.nominators
                    .firstIndex(where: { $0.address == nominatorAddress }) else {
                    return nil
                }

                let validatorAddress = try AddressFactory.address(for: validatorAccountId, chainFormat: chainFormat)

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
        guard let connection = chainRegistry.getConnection(for: chain.chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.connectionUnavailable)
        }

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }

        let eraValidatorsOperation = eraValidatorService.fetchInfoOperation()
        let validatorsStakeInfoWrapper = createValidatorsStakeInfoWrapper(
            for: accountIds,
            electedValidatorsOperation: eraValidatorsOperation
        )

        validatorsStakeInfoWrapper.allOperations.forEach { $0.addDependency(eraValidatorsOperation) }

        let identitiesWrapper = identityOperationFactory.createIdentityWrapper(
            for: { accountIds },
            engine: connection,
            runtimeService: runtimeService,
            chain: chain
        )

        let chainFormat = chain.chainFormat

        let mergeOperation = ClosureOperation<[SelectedValidatorInfo]> {
            let validatorsStakeInfo = try validatorsStakeInfoWrapper.targetOperation
                .extractNoCancellableResultData()
            let identities = try identitiesWrapper.targetOperation.extractNoCancellableResultData()

            return try validatorsStakeInfo.enumerated().map { index, validatorStakeInfo in
                let validatorAddress = try AddressFactory.address(
                    for: accountIds[index],
                    chainFormat: chainFormat
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
        guard let connection = chainRegistry.getConnection(for: chain.chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.connectionUnavailable)
        }

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }

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
            engine: connection,
            runtimeService: runtimeService,
            chain: chain
        )

        let validatorPrefsWrapper = createValidatorPrefsWrapper(for: accountIdList)

        let stakeInfoWrapper = createValidatorsStakeInfoWrapper(
            for: accountIdList,
            electedValidatorsOperation: eraValidatorsOperation
        )

        stakeInfoWrapper.addDependency(operations: [eraValidatorsOperation])

        let precision = asset.precision
        let chainFormat = chain.chainFormat

        let mergeOperation = ClosureOperation<[SelectedValidatorInfo]> {
            let identityList = try identitiesWrapper.targetOperation.extractNoCancellableResultData()
            let validatorPrefsList = try validatorPrefsWrapper.targetOperation.extractNoCancellableResultData()
            let slashings = try slashingsWrapper.targetOperation.extractNoCancellableResultData()
            let stakeInfoList = try stakeInfoWrapper.targetOperation.extractNoCancellableResultData()

            let slashed: Set<Data> = slashings.reduce(into: Set<Data>()) { result, slashInEra in
                slashInEra.value?.forEach { slash in
                    result.insert(slash.validator)
                }
            }

            return try accountIdList.enumerated().compactMap { index, accountId in
                let validatorAddress = try AddressFactory.address(
                    for: accountId,
                    chainFormat: chainFormat
                )

                guard let prefs = validatorPrefsList[validatorAddress] else { return nil }

                let stakeInfo = stakeInfoList[index]

                let commission = Decimal.fromSubstrateAmount(
                    prefs.commission,
                    precision: Int16(precision)
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
