import UIKit
import RobinHood
import FearlessUtils

final class RecommendedValidatorsInteractor {
    weak var presenter: RecommendedValidatorsInteractorOutputProtocol!

    let eraValidatorService: EraValidatorServiceProtocol
    let storageRequestFactory: StorageRequestFactoryProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let engine: JSONRPCEngine
    let operationManager: OperationManagerProtocol
    let logger: LoggerProtocol

    init(eraValidatorService: EraValidatorServiceProtocol,
         storageRequestFactory: StorageRequestFactoryProtocol,
         runtimeService: RuntimeCodingServiceProtocol,
         engine: JSONRPCEngine,
         operationManager: OperationManagerProtocol,
         logger: LoggerProtocol) {
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

    private func createIdentityWrapper(dependingOn superIndetity: SuperIdentityOperation,
                                       runtime: BaseOperation<RuntimeCoderFactoryProtocol>) -> IdentityWrapper {
        let path = StorageCodingPath.identity

        let keyParams: () throws -> [Data] = {
            let responses = try superIndetity.extractNoCancellableResultData()
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

        return identityWrapper
    }

    private func createSlaingsWrapper(dependingOn validators: BaseOperation<EraStakersInfo>,
                                      runtime: BaseOperation<RuntimeCoderFactoryProtocol>)
    -> SlashingSpansWrapper {
        let path = StorageCodingPath.slashingSpans

        let keyParams: () throws -> [Data] = {
            let info = try validators.extractNoCancellableResultData()
            return info.validators.map { $0.accountId }
        }

        let factory: () throws -> RuntimeCoderFactoryProtocol = {
            try runtime.extractNoCancellableResultData()
        }

        return storageRequestFactory.queryItems(engine: engine,
                                                keyParams: keyParams,
                                                factory: factory,
                                                storagePath: path)
    }

    private func prepareRecommendedValidatorList() {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()
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

        identityWrapper.targetOperation.completionBlock = {
            DispatchQueue.main.async {
                do {
                    let result = try identityWrapper.targetOperation.extractNoCancellableResultData()

                    let knowNames = result.compactMap { $0.value?.info.name }

                    self.logger.debug("Did receive identities: \(knowNames)")
                } catch {
                    self.logger.error("Did receive error: \(error)")
                }
            }
        }

        let slashingsWrapper = createSlaingsWrapper(dependingOn: eraValidatorsOperation,
                                                    runtime: runtimeOperation)

        slashingsWrapper.allOperations.forEach { $0.addDependency(identityWrapper.targetOperation) }

        slashingsWrapper.targetOperation.completionBlock = {
            DispatchQueue.main.async {
                do {
                    let result = try slashingsWrapper.targetOperation.extractNoCancellableResultData()

                    self.logger.debug("Did receive identities: \(result)")
                } catch {
                    self.logger.error("Did receive error: \(error)")
                }
            }
        }

        let operations = [runtimeOperation, eraValidatorsOperation] + superIdentityWrapper.allOperations +
            identityWrapper.allOperations + slashingsWrapper.allOperations

        operationManager.enqueue(operations: operations, in: .transient)
    }
}

extension RecommendedValidatorsInteractor: RecommendedValidatorsInteractorInputProtocol {
    func setup() {
        prepareRecommendedValidatorList()
    }
}
