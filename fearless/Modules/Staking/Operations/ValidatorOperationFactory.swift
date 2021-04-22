import Foundation
import RobinHood
import IrohaCrypto

protocol ValidatorOperationFactoryProtocol {
    func allElectedOperation() -> CompoundOperationWrapper<[ElectedValidatorInfo]>
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

    private func createMapOperation(
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
                    maxNominatorsAllowed: maxNominators,
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

        let mapOperation = createMapOperation(
            dependingOn: eraValidatorsOperation,
            rewardOperation: rewardOperation,
            maxNominatorsOperation: maxNominatorsOperation,
            slashesOperation: slashingsWrapper.targetOperation,
            identitiesOperation: identityWrapper.targetOperation
        )

        mapOperation.addDependency(slashingsWrapper.targetOperation)
        mapOperation.addDependency(identityWrapper.targetOperation)
        mapOperation.addDependency(maxNominatorsOperation)
        mapOperation.addDependency(rewardOperation)

        let baseOperations = [
            runtimeOperation,
            eraValidatorsOperation,
            slashDeferOperation,
            maxNominatorsOperation,
            rewardOperation
        ]

        let dependencies = baseOperations + identityWrapper.allOperations + slashingsWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }
}
