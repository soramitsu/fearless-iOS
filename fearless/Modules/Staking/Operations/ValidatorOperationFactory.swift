import Foundation
import RobinHood
import IrohaCrypto

protocol ValidatorOperationFactorProtocol {
    func allElectedOperation() -> CompoundOperationWrapper<[ElectedValidatorInfo]>
}

final class ValidatorOperationFactory {
    let chain: Chain
    let eraValidatorService: EraValidatorServiceProtocol
    let storageRequestFactory: StorageRequestFactoryProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let engine: JSONRPCEngine

    init(chain: Chain,
         eraValidatorService: EraValidatorServiceProtocol,
         storageRequestFactory: StorageRequestFactoryProtocol,
         runtimeService: RuntimeCodingServiceProtocol,
         engine: JSONRPCEngine) {
        self.chain = chain
        self.eraValidatorService = eraValidatorService
        self.storageRequestFactory = storageRequestFactory
        self.runtimeService = runtimeService
        self.engine = engine
    }

    private func createSuperIdentityOperation(dependingOn runtime: BaseOperation<RuntimeCoderFactoryProtocol>,
                                              eraValidators: BaseOperation<EraStakersInfo>)
    -> SuperIdentityWrapper {
        let path = StorageCodingPath.superIdentity

        let keyParams: () throws -> [Data] = {
            let info = try eraValidators.extractNoCancellableResultData()
            return info.validators.map { $0.accountId }
        }

        let factory: () throws -> RuntimeCoderFactoryProtocol = {
            try runtime.extractNoCancellableResultData()
        }

        let superIdentityWrapper: SuperIdentityWrapper = storageRequestFactory.queryItems(engine: engine,
                                                                                          keyParams: keyParams,
                                                                                          factory: factory,
                                                                                          storagePath: path)

        return superIdentityWrapper
    }

    private func createIdentityMapOperation(dependingOn superOperation: SuperIdentityOperation,
                                            identityOperation: IdentityOperation)
    -> BaseOperation<[String: AccountIdentity]> {
        let addressType = chain.addressType

        return ClosureOperation<[String: AccountIdentity]> {
            let addressFactory = SS58AddressFactory()

            let superIdentities = try superOperation.extractNoCancellableResultData()
            let identities = try identityOperation.extractNoCancellableResultData()
                .reduce(into: [String: Identity]()) { (result, item) in
                    if let value = item.value {
                        let address = try addressFactory
                            .addressFromAccountId(data: item.key.getAccountIdFromKey(),
                                                  type: addressType)
                        result[address] = value
                    }
                }

            return try superIdentities.reduce(into: [String: AccountIdentity]()) { (result, item) in
                let address = try addressFactory
                    .addressFromAccountId(data: item.key.getAccountIdFromKey(),
                                          type: addressType)

                if let value = item.value {
                    let parentAddress = try addressFactory
                        .addressFromAccountId(data: value.parentAccountId,
                                              type: addressType)

                    if let parentIdentity = identities[parentAddress] {
                        result[address] = AccountIdentity(name: value.data.stringValue ?? "",
                                                          parentAddress: parentAddress,
                                                          parentName: parentIdentity.info.display.stringValue,
                                                          identity: parentIdentity.info)
                    } else {
                        result[address] = AccountIdentity(name: value.data.stringValue ?? "")
                    }

                } else if let identity = identities[address] {
                    result[address] = AccountIdentity(name: identity.info.display.stringValue ?? "",
                                                      parentAddress: nil,
                                                      parentName: nil,
                                                      identity: identity.info)
                }
            }
        }
    }

    private func createIdentityWrapper(dependingOn superIdentity: SuperIdentityOperation,
                                       runtime: BaseOperation<RuntimeCoderFactoryProtocol>)
    -> CompoundOperationWrapper<[String: AccountIdentity]> {
        let path = StorageCodingPath.identity

        let keyParams: () throws -> [Data] = {
            let responses = try superIdentity.extractNoCancellableResultData()
            return responses.map { response in
                if let value = response.value {
                    return value.parentAccountId
                } else {
                    return response.key.getAccountIdFromKey()
                }
            }
        }

        let factory: () throws -> RuntimeCoderFactoryProtocol = {
            try runtime.extractNoCancellableResultData()
        }

        let identityWrapper: IdentityWrapper = storageRequestFactory.queryItems(engine: engine,
                                                                                keyParams: keyParams,
                                                                                factory: factory,
                                                                                storagePath: path)

        let mapOperation = createIdentityMapOperation(dependingOn: superIdentity,
                                                      identityOperation: identityWrapper.targetOperation)

        mapOperation.addDependency(identityWrapper.targetOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation,
                                        dependencies: identityWrapper.allOperations)
    }

    private func createSlashesWrapper(dependingOn validators: BaseOperation<EraStakersInfo>,
                                      runtime: BaseOperation<RuntimeCoderFactoryProtocol>,
                                      slashDefer: BaseOperation<UInt32>)
    -> UnappliedSlashesWrapper {
        let path = StorageCodingPath.unappliedSlashes

        let keyParams: () throws -> [String] = {
            let info = try validators.extractNoCancellableResultData()
            let duration = try slashDefer.extractNoCancellableResultData()
            let startEra = max(info.era - duration, 0)
            return (startEra...info.era).map { String($0) }
        }

        let factory: () throws -> RuntimeCoderFactoryProtocol = {
            try runtime.extractNoCancellableResultData()
        }

        return storageRequestFactory.queryItems(engine: engine,
                                                keyParams: keyParams,
                                                factory: factory,
                                                storagePath: path)
    }

    private func createConstOperation<T>(dependingOn runtime: BaseOperation<RuntimeCoderFactoryProtocol>,
                                         path: ConstantCodingPath) -> PrimitiveConstantOperation<T>
    where T: LosslessStringConvertible {
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

    private func createMapOperation(dependingOn eraValidatorsOperation: BaseOperation<EraStakersInfo>,
                                    maxNominatorsOperation: BaseOperation<UInt32>,
                                    slashesOperation: UnappliedSlashesOperation,
                                    identitiesOperation: BaseOperation<[String: AccountIdentity]>)
    -> BaseOperation<[ElectedValidatorInfo]> {
        let addressType = chain.addressType

        return ClosureOperation<[ElectedValidatorInfo]> {
            let electedInfo = try eraValidatorsOperation.extractNoCancellableResultData()
            let maxNominators = try maxNominatorsOperation.extractNoCancellableResultData()
            let slashings = try slashesOperation.extractNoCancellableResultData()
            let identities = try identitiesOperation.extractNoCancellableResultData()

            let addressFactory = SS58AddressFactory()

            let slashed: Set<Data> = slashings.reduce(into: Set<Data>()) { (result, slashInEra) in
                slashInEra.value?.forEach { slash in
                    result.insert(slash.validator)
                }
            }

            return try electedInfo.validators.map { validator in
                let hasSlashes = slashed.contains(validator.accountId)

                let address = try addressFactory.addressFromAccountId(data: validator.accountId,
                                                                      type: addressType)

                // TODO: Calculate stake return FLW-578
                return try ElectedValidatorInfo(validator: validator,
                                                identity: identities[address],
                                                stakeReturnPer: 0.0,
                                                hasSlashes: hasSlashes,
                                                maxNominatorsAllowed: maxNominators,
                                                addressType: addressType)
            }
        }
    }
}

extension ValidatorOperationFactory: ValidatorOperationFactorProtocol {
    func allElectedOperation() -> CompoundOperationWrapper<[ElectedValidatorInfo]> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()

        let slashDeferOperation: BaseOperation<UInt32> =
            createConstOperation(dependingOn: runtimeOperation,
                                 path: .slashDeferDuration)

        let maxNominatorsOperation: BaseOperation<UInt32> =
            createConstOperation(dependingOn: runtimeOperation,
                                 path: .maxNominatorRewardedPerValidator)

        slashDeferOperation.addDependency(runtimeOperation)
        maxNominatorsOperation.addDependency(runtimeOperation)

        let eraValidatorsOperation = eraValidatorService.fetchInfoOperation()

        let superIdentityWrapper = createSuperIdentityOperation(dependingOn: runtimeOperation,
                                                                eraValidators: eraValidatorsOperation)

        superIdentityWrapper.allOperations.forEach {
            $0.addDependency(eraValidatorsOperation)
            $0.addDependency(runtimeOperation)
        }

        let identityWrapper = createIdentityWrapper(dependingOn: superIdentityWrapper.targetOperation,
                                                    runtime: runtimeOperation)

        identityWrapper.allOperations.forEach { $0.addDependency(superIdentityWrapper.targetOperation) }

        let slashingsWrapper = createSlashesWrapper(dependingOn: eraValidatorsOperation,
                                                    runtime: runtimeOperation,
                                                    slashDefer: slashDeferOperation)

        slashingsWrapper.allOperations.forEach {
            $0.addDependency(eraValidatorsOperation)
            $0.addDependency(runtimeOperation)
            $0.addDependency(slashDeferOperation)
        }

        let mapOperation = createMapOperation(dependingOn: eraValidatorsOperation,
                                              maxNominatorsOperation: maxNominatorsOperation,
                                              slashesOperation: slashingsWrapper.targetOperation,
                                              identitiesOperation: identityWrapper.targetOperation)

        mapOperation.addDependency(slashingsWrapper.targetOperation)
        mapOperation.addDependency(identityWrapper.targetOperation)
        mapOperation.addDependency(maxNominatorsOperation)

        let baseOperations = [
            runtimeOperation,
            eraValidatorsOperation,
            slashDeferOperation,
            maxNominatorsOperation
        ]

        let dependencies = baseOperations  + superIdentityWrapper.allOperations +
            identityWrapper.allOperations + slashingsWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }
}
