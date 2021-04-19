import Foundation
import FearlessUtils
import RobinHood
import BigInt
import IrohaCrypto

final class PayoutRewardsService: PayoutRewardsServiceProtocol {
    let selectedAccountAddress: String
    let chain: Chain
    let subscanBaseURL: URL
    let runtimeCodingService: RuntimeCodingServiceProtocol
    let storageRequestFactory: StorageRequestFactoryProtocol
    let engine: JSONRPCEngine
    let operationManager: OperationManagerProtocol
    let subscanOperationFactory: SubscanOperationFactoryProtocol
    let identityOperationFactory: IdentityOperationFactoryProtocol
    let logger: LoggerProtocol?

    init(
        selectedAccountAddress: String,
        chain: Chain,
        subscanBaseURL: URL,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        storageRequestFactory: StorageRequestFactoryProtocol,
        engine: JSONRPCEngine,
        operationManager: OperationManagerProtocol,
        subscanOperationFactory: SubscanOperationFactoryProtocol,
        identityOperationFactory: IdentityOperationFactoryProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.selectedAccountAddress = selectedAccountAddress
        self.chain = chain
        self.subscanBaseURL = subscanBaseURL
        self.runtimeCodingService = runtimeCodingService
        self.storageRequestFactory = storageRequestFactory
        self.engine = engine
        self.operationManager = operationManager
        self.subscanOperationFactory = subscanOperationFactory
        self.identityOperationFactory = identityOperationFactory
        self.logger = logger
    }

    // swiftlint:disable function_body_length
    func fetchPayoutRewards(completion: @escaping PayoutRewardsClosure) {
        let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()

        do {
            let steps1to3OperationWrapper = try createSteps1To3OperationWrapper(
                codingFactoryOperation: codingFactoryOperation
            )

            let steps4And5OperationWrapper = try createSteps4And5OperationWrapper(
                dependingOn: steps1to3OperationWrapper.targetOperation,
                engine: engine,
                codingFactoryOperation: codingFactoryOperation
            )
            steps4And5OperationWrapper.allOperations
                .forEach { $0.addDependency(steps1to3OperationWrapper.targetOperation) }

            let nominationHistoryStep6Controllers = createControllersStep6Operation(
                nominatorStashAddress: selectedAccountAddress
            )

            nominationHistoryStep6Controllers.allOperations
                .forEach { $0.addDependency(steps4And5OperationWrapper.targetOperation) }

            nominationHistoryStep6Controllers.targetOperation.completionBlock = { [weak self] in
                self?.continueValidatorsFetch(
                    dependingOn: codingFactoryOperation,
                    nominationHistoryWrapper: nominationHistoryStep6Controllers,
                    stakingOverviewWrapper: steps1to3OperationWrapper,
                    eraRewardOverviewWrapper: steps4And5OperationWrapper,
                    completion: completion
                )
            }

            let operations = [codingFactoryOperation]
                + steps1to3OperationWrapper.allOperations
                + steps4And5OperationWrapper.allOperations
                + nominationHistoryStep6Controllers.allOperations

            operationManager.enqueue(operations: operations, in: .transient)
        } catch {
            logger?.debug(error.localizedDescription)
            completion(.failure(PayoutRewardsServiceError.unknown))
        }
    }

    private func continueValidatorsFetch(
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        nominationHistoryWrapper: CompoundOperationWrapper<Set<AccountId>>,
        stakingOverviewWrapper: CompoundOperationWrapper<PayoutSteps1To3Result>,
        eraRewardOverviewWrapper: CompoundOperationWrapper<PayoutSteps4And5Result>,
        completion: @escaping PayoutRewardsClosure
    ) {
        do {
            let controllersSet = try nominationHistoryWrapper
                .targetOperation.extractNoCancellableResultData()

            let validatorsWrapper = try createFindValidatorsOperation(
                controllers: controllersSet
            )

            let controllersWrapper: CompoundOperationWrapper<[Data]> = try createFetchAndMapOperation(
                dependingOn: validatorsWrapper.targetOperation,
                codingFactoryOperation: codingFactoryOperation,
                path: .controller
            )
            controllersWrapper.allOperations
                .forEach { $0.addDependency(validatorsWrapper.targetOperation) }

            let ledgerInfos: CompoundOperationWrapper<[DyStakingLedger]> =
                try createFetchAndMapOperation(
                    dependingOn: controllersWrapper.targetOperation,
                    codingFactoryOperation: codingFactoryOperation,
                    path: .stakingLedger
                )

            ledgerInfos.allOperations
                .forEach { $0.addDependency(controllersWrapper.targetOperation) }

            let unclaimedErasByStashOperation = try createUnclaimedEraByStashOperation(
                ledgerInfoOperation: ledgerInfos.targetOperation,
                steps1to3Operation: stakingOverviewWrapper.targetOperation
            )

            unclaimedErasByStashOperation.addDependency(ledgerInfos.targetOperation)
            unclaimedErasByStashOperation.addDependency(stakingOverviewWrapper.targetOperation)

            let exposuresByEraWrapper: CompoundOperationWrapper<[EraIndex: [Data: ValidatorExposure]]> =
                try createCreateHistoryByEraAccountIdOperation(
                    dependingOn: unclaimedErasByStashOperation,
                    codingFactoryOperation: codingFactoryOperation,
                    path: .validatorExposureClipped
                )

            exposuresByEraWrapper.allOperations
                .forEach { $0.addDependency(unclaimedErasByStashOperation) }

            let prefsByEraWrapper: CompoundOperationWrapper<[EraIndex: [Data: ValidatorPrefs]]> =
                try createCreateHistoryByEraAccountIdOperation(
                    dependingOn: unclaimedErasByStashOperation,
                    codingFactoryOperation: codingFactoryOperation,
                    path: .erasPrefs
                )

            prefsByEraWrapper.allOperations
                .forEach { $0.addDependency(unclaimedErasByStashOperation) }

            let eraInfoOperation = createEraValidatorsInfoOperation(
                dependingOn: exposuresByEraWrapper.targetOperation,
                dependingOn: prefsByEraWrapper.targetOperation
            )

            exposuresByEraWrapper.allOperations.forEach { eraInfoOperation.addDependency($0) }
            prefsByEraWrapper.allOperations.forEach { eraInfoOperation.addDependency($0) }

            let identityWrapper = createIdentityFetchOperation(
                dependingOn: eraInfoOperation
            )

            identityWrapper.allOperations.forEach { $0.addDependency(eraInfoOperation) }

            let payoutOperation = try calculatePayouts(
                dependingOn: eraInfoOperation,
                eraRewardOverview: eraRewardOverviewWrapper.targetOperation,
                stakingOverviewOperation: stakingOverviewWrapper.targetOperation,
                identityOperation: identityWrapper.targetOperation
            )

            payoutOperation.addDependency(eraInfoOperation)
            payoutOperation.addDependency(identityWrapper.targetOperation)

            let firstOperations = validatorsWrapper.allOperations + controllersWrapper.allOperations
                + ledgerInfos.allOperations
            let secondOperations = [unclaimedErasByStashOperation] + exposuresByEraWrapper.allOperations
                + prefsByEraWrapper.allOperations + identityWrapper.allOperations
                + [eraInfoOperation, payoutOperation]

            payoutOperation.completionBlock = {
                do {
                    let payouts = try payoutOperation.extractNoCancellableResultData()
                    completion(.success(payouts))
                } catch {
                    completion(.failure(PayoutRewardsServiceError.unknown))
                }
            }

            operationManager.enqueue(
                operations: firstOperations + secondOperations,
                in: .transient
            )
        } catch {
            completion(.failure(PayoutRewardsServiceError.unknown))
        }
    }
}
