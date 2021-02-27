import UIKit
import RobinHood
import FearlessUtils
import IrohaCrypto

final class RecommendedValidatorsInteractor {
    weak var presenter: RecommendedValidatorsInteractorOutputProtocol!

    let chain: Chain
    let eraValidatorService: EraValidatorServiceProtocol
    let storageRequestFactory: StorageRequestFactoryProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let engine: JSONRPCEngine
    let operationManager: OperationManagerProtocol
    let logger: LoggerProtocol

    init(chain: Chain,
         eraValidatorService: EraValidatorServiceProtocol,
         storageRequestFactory: StorageRequestFactoryProtocol,
         runtimeService: RuntimeCodingServiceProtocol,
         engine: JSONRPCEngine,
         operationManager: OperationManagerProtocol,
         logger: LoggerProtocol) {
        self.chain = chain
        self.eraValidatorService = eraValidatorService
        self.storageRequestFactory = storageRequestFactory
        self.runtimeService = runtimeService
        self.engine = engine
        self.operationManager = operationManager
        self.logger = logger
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

        let addressType = chain.addressType
        let mapOperation = ClosureOperation<[String: AccountIdentity]> {
            let addressFactory = SS58AddressFactory()

            let superIdentities = try superIdentity.extractNoCancellableResultData()
            let identities = try identityWrapper.targetOperation.extractNoCancellableResultData()
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

    private func prepareRecommendedValidatorList() {
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

        let addressType = chain.addressType
        let mapOperation = ClosureOperation<[ElectedValidatorInfo]> {
            let electedInfo = try eraValidatorsOperation.extractNoCancellableResultData()
            let maxNominators = try maxNominatorsOperation.extractNoCancellableResultData()
            let slashings = try slashingsWrapper.targetOperation.extractNoCancellableResultData()
            let identities = try identityWrapper.targetOperation.extractNoCancellableResultData()

            let addressFactory = SS58AddressFactory()

            let slashed: Set<Data> = slashings.reduce(into: Set<Data>()) { (result, slashInEra) in
                slashInEra.value?.forEach { slash in
                    result.insert(slash.validator)
                }
            }

            return try electedInfo.validators.map { validator in
                let hasSlashes = slashed.contains(validator.accountId)

                let address = try addressFactory.addressFromAccountId(data: validator.accountId, type: addressType)

                return try ElectedValidatorInfo(validator: validator,
                                                identity: identities[address],
                                                stakeReturnPer: 0.0,
                                                hasSlashes: hasSlashes,
                                                maxNominatorsAllowed: maxNominators,
                                                addressType: addressType)
            }
        }

        mapOperation.addDependency(slashingsWrapper.targetOperation)
        mapOperation.addDependency(identityWrapper.targetOperation)
        mapOperation.addDependency(maxNominatorsOperation)

        mapOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let validators = try mapOperation.extractNoCancellableResultData()
                    self?.presenter.didReceive(validators: validators)
                } catch {
                    self?.presenter.didReceive(error: error)
                }
            }
        }

        let baseOperations = [
            runtimeOperation,
            eraValidatorsOperation,
            slashDeferOperation,
            maxNominatorsOperation
        ]

        let operations = baseOperations  + superIdentityWrapper.allOperations +
            identityWrapper.allOperations + slashingsWrapper.allOperations + [mapOperation]

        operationManager.enqueue(operations: operations, in: .transient)
    }
}

extension RecommendedValidatorsInteractor: RecommendedValidatorsInteractorInputProtocol {
    func setup() {
        prepareRecommendedValidatorList()
    }
}
